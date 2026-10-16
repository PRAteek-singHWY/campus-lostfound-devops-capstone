#!/usr/bin/env bash
# Prometheus + Alertmanager + Grafana (kube-prometheus-stack), app dashboard, and re-enable the
# chart's ServiceMonitor/PrometheusRule now that the CRDs exist.
set -euo pipefail
cd "$(dirname "$0")/.."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
helm repo update >/dev/null
helm upgrade --install kps prometheus-community/kube-prometheus-stack -n monitoring --create-namespace \
  -f monitoring/kube-prometheus-stack-values.yaml --wait --timeout 10m
kubectl -n monitoring create configmap lostfound-dashboard --from-file=monitoring/grafana/lostfound-dashboard.json \
  --dry-run=client -o yaml | kubectl label --local -f - grafana_dashboard=1 -o yaml | kubectl apply -f -
helm upgrade lostfound helm/lostfound -n lostfound --reuse-values \
  --set monitoring.serviceMonitor.enabled=true --set monitoring.prometheusRule.enabled=true --wait
kubectl -n monitoring get pods
echo "Grafana:    kubectl -n monitoring port-forward svc/kps-grafana 3000:80   (admin / lostfound-grafana)"
echo "Prometheus: kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090"
