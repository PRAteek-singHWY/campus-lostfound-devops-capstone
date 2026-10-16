#!/usr/bin/env bash
# Single-node minikube with the addons the chart relies on.
set -euo pipefail
minikube status >/dev/null 2>&1 || minikube start --driver=docker --cpus=4 --memory=6g
minikube addons enable ingress
minikube addons enable metrics-server
kubectl get nodes -o wide
echo "add to /etc/hosts:  $(minikube ip)  lostfound.local"
