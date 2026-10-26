# Demo

| File | What it is |
|---|---|
| [`presentation.mp4`](presentation.mp4) | Presentation video, 1080p, about 9.5 minutes |
| [`presentation.pptx`](presentation.pptx) | Slide deck (PowerPoint), 12 slides with speaker notes |
| [`presentation.pdf`](presentation.pdf) | The same deck as PDF |

## What the video shows

1. **Slides (0:00–6:52)**: the application, the architecture, tests and containers, the CI pipeline, the
   Trivy gate and the CVEs it blocked, delivery by commit SHA, Terraform on AWS, Kubernetes and Helm
   on EKS, observability, and the real incidents and their fixes.
2. **Live demo (6:52–9:06)**, recorded on 26 Oct 2026 against the running stacks:
   - `pytest` (9 passed, 87 % coverage), `docker compose up -d --build`, a non-root `id` check in the
     backend, and `scripts/smoke-test.sh` passing all 10 checks
   - the React app in a browser: report a lost item (POST), mark it returned (PATCH), then the
     FastAPI `/docs`, `/api/health` and `/metrics`
   - minikube: `scripts/deploy.sh <commit-sha>` rolls out images tagged with the commit (Helm
     revision 9), the smoke test passes through the frontend Service, then `helm rollback`
     restores the previous revision
   - Prometheus targets (both backend pods, discovered by the ServiceMonitor), the five chart
     alert rules, and the Grafana dashboard with live traffic
3. **Wrap-up (9:06–9:32)**: from one commit to production.

The terminal sections replay the exact output captured while each command ran. The raw logs are in
[`docs/evidence/17-live-demo-local.txt`](../docs/evidence/17-live-demo-local.txt) and
[`docs/evidence/18-live-demo-minikube.txt`](../docs/evidence/18-live-demo-minikube.txt). The browser
sections are screen recordings of a real browser session. The narration is text-to-speech, generated
from the deck's speaker notes. The EKS deployment itself is documented with captured evidence and
screenshots (slides 8–9 and `docs/evidence/15-eks-deploy.txt`), because the AWS resources were
destroyed on 17 Oct 2026 to stay within the Free Tier.

During the live run, `localhost:3000` was already taken by another process, so the compose frontend
was mapped to `3080` with a local override file. The repository's `docker-compose.yml` still uses `3000`.
