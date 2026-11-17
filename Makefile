.PHONY: test lint render k3s-up k3s-down eks-plan eks-apply eks-bootstrap eks-destroy

test:            ## Run API unit tests
	cd app && pytest -q

lint:            ## Lint Python and check Terraform formatting
	cd app && ruff check src tests
	terraform fmt -check -recursive infra/terraform

render:          ## Render both Kubernetes overlays
	kubectl kustomize k8s/overlays/k3s
	kubectl kustomize k8s/overlays/eks

k3s-up:          ## Local K3s cluster with app + monitoring (free)
	./scripts/k3s-local-up.sh

k3s-down:
	k3d cluster delete tasks

eks-plan:
	terraform -chdir=infra/terraform/eks plan

eks-apply:       ## Creates billable AWS resources
	terraform -chdir=infra/terraform/eks apply

eks-bootstrap:
	./scripts/eks-bootstrap.sh

eks-destroy:     ## Always run this when you're done
	./scripts/eks-destroy.sh
