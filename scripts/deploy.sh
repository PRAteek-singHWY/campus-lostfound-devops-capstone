#!/usr/bin/env bash
# Build both images straight into minikube's container runtime and roll them out with Helm.
# Usage: ./scripts/deploy.sh [tag] [values-file]
set -euo pipefail
TAG="${1:-$(git rev-parse --short=7 HEAD 2>/dev/null || echo local)}"
VALUES="${2:-helm/lostfound/values-dev.yaml}"
NS=lostfound
cd "$(dirname "$0")/.."

eval "$(minikube docker-env)"
docker build -t "ghcr.io/prateek-singhwy/lostfound-backend:$TAG" \
  --build-arg GIT_SHA="$TAG" --build-arg APP_VERSION="$TAG" app/backend
docker build -t "ghcr.io/prateek-singhwy/lostfound-frontend:$TAG" app/frontend

helm upgrade --install lostfound helm/lostfound -n "$NS" --create-namespace -f "$VALUES" \
  --set backend.image.tag="$TAG" --set frontend.image.tag="$TAG" \
  --wait --timeout 5m
kubectl -n "$NS" get pods,svc,ingress,hpa,pvc -o wide
helm -n "$NS" history lostfound
