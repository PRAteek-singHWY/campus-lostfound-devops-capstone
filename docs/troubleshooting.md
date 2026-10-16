# Troubleshooting runbook

Every entry below happened on the minikube cluster while building this project. Raw command
output is in [`evidence/06-troubleshooting-drills.txt`](evidence/06-troubleshooting-drills.txt).

## Where to look first

```bash
kubectl -n lostfound get pods -o wide                       # status column: Pending / CrashLoopBackOff / ImagePullBackOff / Running 0/1
kubectl -n lostfound describe pod <pod> | sed -n '/Events:/,$p'
kubectl -n lostfound logs <pod> --previous                  # the crashed container, not the new one
kubectl -n lostfound get events --sort-by=.lastTimestamp | tail -20
kubectl -n lostfound get endpoints                          # empty = Service selector matches no Ready pod
helm -n lostfound history lostfound                         # which revision is live, which failed
```

| Symptom | Usually means | First command |
|---|---|---|
| `0/1 Running`, never Ready | readiness probe failing (DB unreachable, wrong port) | `kubectl logs`, `kubectl describe` → probe events |
| `CrashLoopBackOff` | process exits: bad config, missing env, migration error | `kubectl logs --previous` |
| `ImagePullBackOff` | wrong tag / private registry / image not loaded into minikube | `kubectl describe pod` → Failed to pull |
| `Pending` | no node fits requests, PVC unbound | `kubectl describe pod` → FailedScheduling |
| `503` from Ingress | Service has no endpoints | `kubectl get endpoints` |
| `OOMKilled` | memory limit too low | `kubectl describe pod` → Last State |

## 1. Backend restarted once right after the first install

**Seen:** `lostfound-backend-… 1/1 Running 1 (15s ago)`.
**Found with:** `kubectl logs <pod> --previous` → `database not ready (attempt 15) … RuntimeError: could not reach the database`.
**Cause:** on a brand-new PVC PostgreSQL takes 30–40 s to initialise. The backend's retry budget
(15 × 2 s) ran out, it exited on purpose, kubelet restarted it and the second start succeeded.
**Fix:** `backend.env.DB_RETRIES` raised to 30 in `values.yaml`; the startup probe already allows
60 s. Later the Alembic entrypoint added its own socket wait (`DB_WAIT_SECONDS`), so the app no
longer starts before the port is open.

## 2. Wrong database host (`DB_HOST=postgres`)

**Reproduced with:** `kubectl patch configmap lostfound-backend -p '{"data":{"DB_HOST":"postgres"}}' && kubectl rollout restart deploy/lostfound-backend`.
**Seen:** the new pod stays `0/1`, restarts, and ends in `CrashLoopBackOff`; the old pod keeps
serving because the Deployment uses `maxUnavailable: 0`.
**Found with:** `kubectl exec deploy/lostfound-backend -- getent hosts postgres` → `no such host`,
while `getent hosts lostfound-db` resolves. Cluster DNS knows **Service names**, and `postgres` is
the image name, not a Service.
**Fix:** set `DB_HOST` back to `lostfound-db` (the chart's ConfigMap value) and roll the Deployment.

## 3. `helm upgrade` failed with a server-side-apply conflict

**Seen:** revision 2 `failed: conflict occurred while applying object lostfound/lostfound-backend
ConfigMap … conflict with "kubectl-patch" using v1: .data.DB_HOST`.
**Cause:** Helm 4 applies manifests with server-side apply and refuses to overwrite a field that
another manager (`kubectl patch`) owns. The hand-edited drift from incident 2 blocked the upgrade.
**Fix:** undo the drift (`kubectl patch` back, or `kubectl apply --server-side --force-conflicts`)
and re-run `helm upgrade`. Lesson: change configuration **through Helm values**, never by patching
live objects, or the next release will either conflict or silently keep the drift.

## 4. Prometheus had no `lostfound` target

**Seen:** `/targets?search=lostfound` empty although the ServiceMonitor existed.
**Found with:** comparing `kubectl get servicemonitor lostfound-backend -o jsonpath='{.spec.selector.matchLabels}'`
with `kubectl get svc lostfound-backend --show-labels`. The selector required
`app.kubernetes.io/component=backend`, but that label was only on the **pods**, not on the
**Service** the ServiceMonitor selects.
**Fix:** add the component label to the Service metadata in `templates/backend.yaml`. Within one
scrape interval both backend pods showed `UP`.

Also: `scripts/deploy.sh` with `values-dev.yaml` had disabled the ServiceMonitor on redeploy. The
script now enables it automatically when the Prometheus Operator CRDs are present.

## 5. `minikube docker-env` build returned `404 page not found`

**Cause:** this minikube uses the **containerd** runtime, so there is no Docker daemon inside the
node to point `DOCKER_HOST` at.
**Fix:** build on the host and `minikube image load <image>` (what `scripts/deploy.sh` does now),
or `minikube image build`.

## 6. Compose: backend started before PostgreSQL was ready (from the earlier lab)

`depends_on: [db]` only waits for the **container** to start. The fix is a `pg_isready`
healthcheck on `db` and `condition: service_healthy` on the backend, plus retries in the app
itself because a database can also restart *after* the app is up.

## 7. Ingress on macOS/minikube returns nothing from the host

`minikube ip` is not routable from macOS with the Docker driver. Use `minikube tunnel`
(needs sudo) and an `/etc/hosts` entry, or verify the Ingress from inside the cluster:

```bash
kubectl -n lostfound run probe --rm -i --restart=Never --image=curlimages/curl:8.10.1 -- \
  -s -i -H "Host: lostfound.local" http://ingress-nginx-controller.ingress-nginx/api/health
```
