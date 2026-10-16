# Architecture

## Application

**Campus Lost & Found** lets students report items they lost or found on campus and mark them as
returned. It is deliberately small so that every DevOps layer around it can be shown end to end.

| Tier | Technology | Container image | Port |
|---|---|---|---|
| Frontend | React 18 (Vite) built to static files, served by nginx which also reverse-proxies `/api` | `ghcr.io/prateek-singhwy/lostfound-frontend` | 80 |
| Backend | Python 3.12, FastAPI, psycopg 3, `prometheus-client` | `ghcr.io/prateek-singhwy/lostfound-backend` | 8000 |
| Database | PostgreSQL 16 | `postgres:16-alpine` | 5432 |

```text
                 ┌──────────────────────────── Kubernetes (namespace: lostfound) ────────────────────────────┐
  browser ──►  Ingress (nginx)                                                                              │
  lostfound.local   │  /      ──► Service lostfound-frontend ──► Deployment (nginx + React build) x2        │
                    │  /api   ──► Service lostfound-backend  ──► Deployment (FastAPI) x2..5 (HPA on CPU)    │
                    │                                                 │ DB_HOST=lostfound-db                │
                    │                                                 ▼                                     │
                    │                                   headless Service lostfound-db                       │
                    │                                   StatefulSet postgres (PVC 1Gi)                      │
                    │                                                                                       │
                    │   Secret lostfound-db (POSTGRES_*)   ConfigMap lostfound-backend (DB_HOST, ...)       │
                    │   ServiceMonitor ─► Prometheus (monitoring ns) ─► Alertmanager / Grafana              │
                    └───────────────────────────────────────────────────────────────────────────────────────┘
```

The nginx frontend proxies `/api` to `${BACKEND_HOST}:${BACKEND_PORT}`, substituted at container
start from environment variables. In Compose that is `backend:8000`; in Kubernetes it is
`lostfound-backend:8000`. The same image runs in both places.

### Health model

| Endpoint | Used by | Touches DB? | Meaning |
|---|---|---|---|
| `GET /api/live` | liveness probe, Docker HEALTHCHECK | no | process is up; restart the container only if this fails |
| `GET /api/health` | readiness probe, smoke tests | yes (`SELECT 1`) | returns 503 when Postgres is unreachable so the Service stops routing traffic to that pod |
| `GET /healthz` (frontend) | nginx probes | no | nginx itself is serving |
| `GET /metrics` | Prometheus ServiceMonitor | no | request counter, latency histogram, `lostfound_db_up`, `lostfound_items_open` |

Separating liveness from readiness matters: a database outage makes pods **unready** (traffic
stops) but does not make Kubernetes **restart** them in a loop, which would only hide the real
cause.

## Delivery pipeline

```text
 git push ──► CI (GitHub Actions)
              ├─ lint:  flake8 · hadolint x2 · helm lint (dev+prod) · terraform fmt/validate
              ├─ test:  pytest on Python 3.11 / 3.12 / 3.13, 80 % coverage gate, JUnit + coverage artifacts
              ├─ build: docker buildx (GHA cache) ─► Trivy (fail on CRITICAL) ─► push ghcr.io :sha-xxxxxxx and :latest
              └─ integration: docker compose up from the pushed images ─► scripts/smoke-test.sh
          ──► CD (runs when CI is green on main)
              └─ kind cluster ─► Prometheus Operator CRDs ─► helm upgrade --install (image.tag = sha) ─► smoke test ─► helm history
          ──► Terraform workflow (on terraform/** changes)
              └─ fmt · validate · tflint · plan + apply + destroy against LocalStack (no cloud credentials in CI)
```

Images are tagged with the short commit SHA, and the Helm release pins that tag, so every
deployment is traceable to a commit and `helm rollback` returns to a known image.

## Infrastructure (Terraform, `terraform/`)

```text
 VPC 10.50.0.0/16
 ├─ public subnet 10.50.0.0/24 (AZ a)   ─┐  route table ─► Internet Gateway
 ├─ public subnet 10.50.1.0/24 (AZ b)   ─┘
 ├─ Security group: 80/tcp from anywhere, 22/tcp from admin_cidr, all egress
 ├─ EC2 (Ubuntu 24.04, t3.small, gp3 encrypted root, IMDSv2 required)
 │    cloud-init: install Docker, write .env, docker compose up from ghcr.io images, nightly pg_dump cron
 │    instance profile: S3 RW on the backups bucket + SSM Session Manager
 └─ S3 bucket lostfound-dev-db-backups-*: versioned, SSE-AES256, public access blocked, 30-day expiry
```

`use_localstack=true` redirects every API call to LocalStack, which is how the Terraform workflow
proves the whole graph applies without AWS credentials or cost. `use_localstack=false` with an AWS
profile deploys the same code to a real account.

## Observability (`monitoring/`)

- **kube-prometheus-stack** (Prometheus, Alertmanager, Grafana, node-exporter, kube-state-metrics)
  installed with `monitoring/kube-prometheus-stack-values.yaml`.
- The app chart ships a **ServiceMonitor** (scrapes `/metrics` every 15 s) and a **PrometheusRule**
  with five alerts: high 5xx ratio, p95 latency > 500 ms, database down, pod restarting, pod not
  ready.
- A **Grafana dashboard** (`monitoring/grafana/lostfound-dashboard.json`) is loaded by the sidecar
  from a ConfigMap labelled `grafana_dashboard=1`: traffic by route/status, latency percentiles,
  CPU vs HPA replicas, restarts, memory, and the business metric "open items".
- Alertmanager routes `app=lostfound` alerts to a dedicated receiver (webhook placeholder; swap in
  Slack or email).

## Repository layout

```text
.
├── backend            FastAPI service, Dockerfile, pytest suite
├── frontend           React app, nginx template, multi-stage Dockerfile
├── docker-compose.yml     local three-tier stack (+ optional prometheus/grafana profile)
├── helm/lostfound         Helm chart; values.yaml / values-dev.yaml / values-prod.yaml
├── terraform              AWS infrastructure (LocalStack-compatible)
├── monitoring             kube-prometheus-stack values, Grafana dashboard
├── scripts                cluster-up, deploy, smoke-test, monitoring-up, load
├── .github/workflows      ci.yml, cd.yml, terraform.yml
└── docs                   architecture, troubleshooting runbook, evidence from real runs
```
