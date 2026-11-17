#!/usr/bin/env bash
# Tear everything down. Delete the Ingress first so the controller removes the ALB;
# otherwise the orphaned ALB and its security groups block `terraform destroy` on the VPC.
set -euo pipefail
cd "$(dirname "$0")/.."

kubectl delete -f gitops/argocd/tasks-eks.yaml --ignore-not-found
kubectl -n tasks delete ingress tasks-api --ignore-not-found --wait=true
echo "Waiting 60s for the ALB to be deleted..."
sleep 60
kubectl delete namespace tasks --ignore-not-found --wait=true

terraform -chdir=infra/terraform/eks destroy -auto-approve
