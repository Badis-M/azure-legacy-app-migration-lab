SHELL := /bin/bash

TF_DIR := infra/terraform
APP_DIR := containerized-app
K8S_LOCAL_OVERLAY := k8s/overlays/local
K8S_AZURE_OVERLAY := k8s/overlays/azure
LOCAL_IMAGE := customer-orders-api:local
CI_IMAGE := customer-orders-api:ci

ACR_NAME ?= acrazlegacydev001
ACR_LOGIN_SERVER ?= $(ACR_NAME).azurecr.io
IMAGE_NAME ?= customer-orders-api
IMAGE_TAG ?= dev

.PHONY: help
help:
	@echo "Available targets:"
	@echo ""
	@echo "Terraform:"
	@echo "  tf-fmt                 Format Terraform files"
	@echo "  tf-init                Initialize Terraform"
	@echo "  tf-validate            Validate Terraform"
	@echo "  tf-plan                Run Terraform plan"
	@echo "  tf-apply               Run Terraform apply"
	@echo "  tf-destroy             Destroy Terraform-managed app resources"
	@echo "  tf-check               Format, validate and plan Terraform"
	@echo "  tf-backend-bootstrap   Create Azure Blob backend for Terraform state"
	@echo ""
	@echo "Docker / ACR:"
	@echo "  docker-build           Build local Docker image for kind"
	@echo "  docker-build-ci        Build CI Docker image"
	@echo "  acr-login              Login to Azure Container Registry"
	@echo "  docker-tag-acr         Tag local Docker image for ACR manually"
	@echo "  docker-push-acr        Build linux/amd64 image and push it to ACR"
	@echo ""
	@echo "Local Kubernetes:"
	@echo "  k8s-render-local       Render local Kubernetes manifests"
	@echo "  k8s-apply-local        Apply local Kubernetes manifests"
	@echo "  k8s-delete-local       Delete local Kubernetes manifests"
	@echo ""
	@echo "Azure Kubernetes Service:"
	@echo "  aks-credentials        Fetch AKS credentials from Terraform outputs"
	@echo "  aks-nodes              List AKS nodes"
	@echo "  aks-check              Validate Terraform AKS outputs and current kube context"
	@echo "  k8s-render-azure       Render Azure Kubernetes manifests"
	@echo "  k8s-apply-azure        Apply Azure Kubernetes manifests"
	@echo "  k8s-delete-azure       Delete Azure Kubernetes manifests"
	@echo "  k8s-status             Show Azure Kubernetes workload status"
	@echo "  k8s-port-forward       Port-forward the customer orders API locally"
	@echo ""
	@echo "Composite workflows:"
	@echo "  infra-up               Apply Terraform, push image to ACR and deploy to AKS"
	@echo "  infra-down             Delete AKS manifests if reachable, then destroy Terraform resources"
	@echo "  cost-check             List remaining Azure resources after destroy"

.PHONY: tf-fmt
tf-fmt:
	cd $(TF_DIR) && terraform fmt -recursive

.PHONY: tf-init
tf-init:
	cd $(TF_DIR) && terraform init

.PHONY: tf-validate
tf-validate:
	cd $(TF_DIR) && terraform validate

.PHONY: tf-plan
tf-plan:
	cd $(TF_DIR) && terraform plan

.PHONY: tf-apply
tf-apply:
	cd $(TF_DIR) && terraform apply

.PHONY: tf-destroy
tf-destroy:
	cd $(TF_DIR) && terraform destroy

.PHONY: tf-check
tf-check: tf-fmt tf-validate tf-plan

.PHONY: tf-backend-bootstrap
tf-backend-bootstrap:
	./scripts/bootstrap-tfstate-backend.sh

.PHONY: docker-build
docker-build:
	docker build -t $(LOCAL_IMAGE) ./$(APP_DIR)

.PHONY: docker-build-ci
docker-build-ci:
	docker build -t $(CI_IMAGE) ./$(APP_DIR)

.PHONY: acr-login
acr-login:
	az acr login --name $(ACR_NAME)

.PHONY: docker-tag-acr
docker-tag-acr:
	docker tag $(LOCAL_IMAGE) $(ACR_LOGIN_SERVER)/$(IMAGE_NAME):$(IMAGE_TAG)

.PHONY: docker-push-acr
docker-push-acr: acr-login
	docker buildx build \
		--platform linux/amd64 \
		-t $(ACR_LOGIN_SERVER)/$(IMAGE_NAME):$(IMAGE_TAG) \
		./$(APP_DIR) \
		--push

.PHONY: k8s-render-local
k8s-render-local:
	kubectl kustomize $(K8S_LOCAL_OVERLAY)

.PHONY: k8s-apply-local
k8s-apply-local:
	kubectl apply -k $(K8S_LOCAL_OVERLAY)

.PHONY: k8s-delete-local
k8s-delete-local:
	kubectl delete -k $(K8S_LOCAL_OVERLAY)

.PHONY: aks-credentials
aks-credentials:
	@RG=$$(cd $(TF_DIR) && terraform output -raw resource_group_name 2>/dev/null || true); \
	AKS=$$(cd $(TF_DIR) && terraform output -raw aks_name 2>/dev/null || true); \
	if [[ -z "$$RG" || -z "$$AKS" ]]; then \
		echo "AKS credentials unavailable: Terraform outputs are empty."; \
		echo "This is expected if the infrastructure has been destroyed."; \
		echo "Run 'make tf-apply' first, then retry 'make aks-credentials'."; \
		exit 1; \
	fi; \
	az aks get-credentials \
		--resource-group "$$RG" \
		--name "$$AKS" \
		--overwrite-existing

.PHONY: aks-nodes
aks-nodes:
	@kubectl get nodes -o wide || { \
		echo "Unable to list nodes. Make sure AKS exists and credentials are configured."; \
		echo "Run 'make tf-apply' and 'make aks-credentials' first."; \
		exit 1; \
	}

.PHONY: aks-check
aks-check:
	@RG=$$(cd $(TF_DIR) && terraform output -raw resource_group_name 2>/dev/null || true); \
	AKS=$$(cd $(TF_DIR) && terraform output -raw aks_name 2>/dev/null || true); \
	CTX=$$(kubectl config current-context 2>/dev/null || true); \
	if [[ -z "$$RG" || -z "$$AKS" ]]; then \
		echo "AKS check failed: Terraform outputs are empty."; \
		echo "This is expected if the infrastructure has been destroyed."; \
		exit 1; \
	fi; \
	echo "Terraform resource group: $$RG"; \
	echo "Terraform AKS name:       $$AKS"; \
	echo "Current kube context:     $$CTX"; \
	if [[ "$$CTX" != "$$AKS" ]]; then \
		echo "Warning: current kube context does not match the Terraform AKS output."; \
		echo "Run 'make aks-credentials' before applying Azure manifests."; \
		exit 1; \
	fi; \
	echo "AKS context check passed."

.PHONY: k8s-render-azure
k8s-render-azure:
	kubectl kustomize $(K8S_AZURE_OVERLAY)

.PHONY: k8s-apply-azure
k8s-apply-azure: aks-check
	kubectl apply -k $(K8S_AZURE_OVERLAY)

.PHONY: k8s-delete-azure
k8s-delete-azure:
	@RG=$$(cd $(TF_DIR) && terraform output -raw resource_group_name 2>/dev/null || true); \
	AKS=$$(cd $(TF_DIR) && terraform output -raw aks_name 2>/dev/null || true); \
	CTX=$$(kubectl config current-context 2>/dev/null || true); \
	if [[ -z "$$RG" || -z "$$AKS" ]]; then \
		echo "Terraform AKS outputs are empty. Skipping Kubernetes manifest deletion."; \
		echo "This is expected if the infrastructure has already been destroyed."; \
		exit 0; \
	fi; \
	if [[ "$$CTX" != "$$AKS" ]]; then \
		echo "Current kube context '$$CTX' does not match expected AKS context '$$AKS'."; \
		echo "Skipping Kubernetes manifest deletion to avoid deleting resources from the wrong cluster."; \
		exit 0; \
	fi; \
	kubectl delete -k $(K8S_AZURE_OVERLAY) --ignore-not-found=true

.PHONY: k8s-status
k8s-status: aks-check
	kubectl get pods -n customer-orders
	kubectl get nodes -o wide
	kubectl get pvc -n customer-orders
	kubectl get svc -n customer-orders

.PHONY: k8s-port-forward
k8s-port-forward: aks-check
	kubectl port-forward svc/customer-orders-api 8000:80 -n customer-orders

.PHONY: infra-up
infra-up: tf-apply aks-credentials docker-push-acr k8s-apply-azure k8s-status

.PHONY: infra-down
infra-down:
	$(MAKE) k8s-delete-azure
	$(MAKE) tf-destroy

.PHONY: cost-check
cost-check:
	@echo "Resource groups:"
	az group list --query "[].{name:name, location:location}" -o table
	@echo ""
	@echo "Potentially billable resources:"
	az resource list \
		--query "[?type=='Microsoft.ContainerService/managedClusters' || type=='Microsoft.Compute/virtualMachines' || type=='Microsoft.Compute/virtualMachineScaleSets' || type=='Microsoft.Network/loadBalancers' || type=='Microsoft.Network/publicIPAddresses' || type=='Microsoft.ContainerRegistry/registries' || type=='Microsoft.Compute/disks' || type=='Microsoft.OperationalInsights/workspaces'].{name:name, type:type, rg:resourceGroup, location:location}" \
		-o table
	@echo ""
	@echo "All remaining resources:"
	az resource list --query "[].{name:name, type:type, rg:resourceGroup, location:location}" -o table