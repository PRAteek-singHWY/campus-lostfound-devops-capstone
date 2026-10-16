#!/usr/bin/env bash
# Build both images on the host, load them into minikube's container runtime, roll out with Helm.
# Usage: ./scripts/deploy.sh [tag] [values-file]
set -euo pipefail
TAG="${1:-$(git rev-parse --short=7 HEAD 2>/dev/null || echo local)}"
VALUES="${2:-helm/lostfound/values-dev.yaml}"
NS=lostfound
BACKEND=ghcr.io/prateek-singhwy/lostfound-backend
FRONTEND=ghcr.io/prateek-singhwy/lostfound-frontend
cd "$(dirname "$0")/.."

docker build -t "$BACKEND:$TAG" --build-arg GIT_SHA="$TAG" --build-arg APP_VERSION="$TAG" backend
docker build -t "$FRONTEND:$TAG" frontend
# minikube runs containerd, so images are loaded rather than built inside the node
minikube image load "$BACKEND:$TAG"
minikube image load "$FRONTEND:$TAG"

# enable the ServiceMonitor/PrometheusRule only when the Prometheus Operator CRDs exist
MON=""
kubectl get crd servicemonitors.monitoring.coreos.com >/dev/null 2>&1 \
  && MON="--set monitoring.serviceMonitor.enabled=true --set monitoring.prometheusRule.enabled=true"

kubectl apply -f k8s/namespace.yaml
# shellcheck disable=SC2086
helm upgrade --install lostfound helm/lostfound -n "$NS" -f "$VALUES" \
  --set backend.image.tag="$TAG" --set frontend.image.tag="$TAG" $MON \
  --wait --timeout 5m
kubectl -n "$NS" get pods,svc,ingress,hpa,pvc -o wide
helm -n "$NS" history lostfound
