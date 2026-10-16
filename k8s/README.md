# k8s/ — cluster bootstrap

Applied once per cluster, before the Helm release:

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/storageclass-gp3.yaml      # EKS only
helm upgrade --install lostfound helm/lostfound -n lostfound -f helm/lostfound/values-dev.yaml
```

Everything application-related (Deployments, Services, Ingress, HPA, StatefulSet, Secret,
ConfigMap, ServiceMonitor, PrometheusRule) is in the Helm chart under `helm/lostfound`.
