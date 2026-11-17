#!/usr/bin/env bash
# Spin up the full platform on a local K3s cluster (k3d runs K3s inside Docker).
# Requires: docker, k3d, kubectl, helm.  Cost: free.
set -euo pipefail
cd "$(dirname "$0")/.."

CLUSTER=tasks
command -v k3d >/dev/null || { echo "k3d not found: https://k3d.io/#installation"; exit 1; }

if ! k3d cluster list "$CLUSTER" >/dev/null 2>&1; then
  k3d cluster create --config infra/k3s/k3d-cluster.yaml
fi

echo ">> Building API image and importing it into the cluster"
docker build -t tasks-api:local app
k3d image import tasks-api:local -c "$CLUSTER"

echo ">> Installing monitoring stack"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
helm repo update >/dev/null
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  -f monitoring/kube-prometheus-stack-values.yaml --wait

echo ">> Deploying the app"
kubectl apply -k k8s/overlays/k3s
kubectl apply -f monitoring/tasks-api-monitoring.yaml
kubectl -n tasks rollout status deploy/tasks-api --timeout=180s

echo
echo "API:      http://tasks.localhost:8080/api/tasks"
echo "Grafana:  kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80"
