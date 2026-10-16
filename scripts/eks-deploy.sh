#!/usr/bin/env bash
# Deploy the published GHCR images to the Terraform-provisioned EKS cluster.
# Usage: ./scripts/eks-deploy.sh [image-tag]   (default: latest)
set -euo pipefail
TAG="${1:-latest}"
cd "$(dirname "$0")/.."
eval "$(cd terraform && terraform output -raw configure_kubectl)"
kubectl get nodes -o wide
kubectl apply -f k8s/namespace.yaml
helm upgrade --install lostfound helm/lostfound -n lostfound -f helm/lostfound/values-eks.yaml \
  --set backend.image.tag="$TAG" --set frontend.image.tag="$TAG" --wait --timeout 8m
kubectl -n lostfound get pods,svc,hpa,pvc -o wide
helm list -n lostfound
echo "Frontend URL: http://$(kubectl -n lostfound get svc lostfound-frontend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')/"
