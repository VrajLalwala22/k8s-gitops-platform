#!/usr/bin/env bash
# After `terraform apply` in infra/terraform/eks: install cluster add-ons and Argo CD,
# create the database secret, and hand the app over to GitOps.
# Requires: aws, kubectl, helm, terraform, openssl.
set -euo pipefail
cd "$(dirname "$0")/.."

TF="terraform -chdir=infra/terraform/eks"
CLUSTER=$($TF output -raw cluster_name)
REGION=$($TF output -raw region)
VPC_ID=$($TF output -raw vpc_id)
LB_ROLE=$($TF output -raw lb_controller_role_arn)

aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER"

helm repo add eks https://aws.github.io/eks-charts >/dev/null
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
helm repo update >/dev/null

echo ">> AWS Load Balancer Controller (IRSA)"
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="$CLUSTER" \
  --set region="$REGION" \
  --set vpcId="$VPC_ID" \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="$LB_ROLE" \
  --wait

echo ">> Monitoring"
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace -f monitoring/kube-prometheus-stack-values.yaml --wait

echo ">> Database secret (random password, never stored in Git)"
kubectl create namespace tasks --dry-run=client -o yaml | kubectl apply -f -
if ! kubectl -n tasks get secret postgres-credentials >/dev/null 2>&1; then
  kubectl -n tasks create secret generic postgres-credentials \
    --from-literal=POSTGRES_PASSWORD="$(openssl rand -base64 24)"
fi

echo ">> Argo CD + app"
helm upgrade --install argocd argo/argo-cd -n argocd --create-namespace --wait
kubectl apply -f gitops/argocd/tasks-eks.yaml
kubectl apply -f monitoring/tasks-api-monitoring.yaml

echo
echo "Argo CD admin password:"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo "App URL (ALB, ready in ~2 min):"
echo "  kubectl -n tasks get ingress tasks-api -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
