SHELL := /bin/bash

TF_DIR := infra/terraform
APP_DIR := containerized-app
K8S_LOCAL_OVERLAY := k8s/overlays/local
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
	@echo "  k8s-render-azure       Render Azure Kubernetes manifests"
	@echo "  k8s-apply-azure        Apply Azure Kubernetes manifests"
	@echo "  k8s-delete-azure       Delete Azure Kubernetes manifests"
	@echo "  k8s-status             Show Azure Kubernetes workload status"
	@echo "  k8s-port-forward       Port-forward the customer orders API locally"
	@echo ""
	@echo "Composite workflows:"
	@echo "  infra-up               Apply Terraform, push image to ACR and deploy to AKS"
	@echo "  infra-down             Delete AKS manifests and destroy Terraform resources"

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
	az aks get-credentials \
		--resource-group $$(cd $(TF_DIR) && terraform output -raw resource_group_name) \
		--name $$(cd $(TF_DIR) && terraform output -raw aks_name) \
		--overwrite-existing

.PHONY: aks-nodes
aks-nodes:
	kubectl get nodes -o wide

.PHONY: k8s-render-azure
k8s-render-azure:
	kubectl kustomize k8s/overlays/azure

.PHONY: k8s-apply-azure
k8s-apply-azure:
	kubectl apply -k k8s/overlays/azure

.PHONY: k8s-delete-azure
k8s-delete-azure:
	kubectl delete -k k8s/overlays/azure

.PHONY: k8s-status
k8s-status:
	kubectl get pods -n customer-orders
	kubectl get nodes -o wide
	kubectl get pvc -n customer-orders
	kubectl get svc -n customer-orders

.PHONY: k8s-port-forward
k8s-port-forward:
	kubectl port-forward svc/customer-orders-api 8000:80 -n customer-orders

.PHONY: infra-up
infra-up: tf-apply aks-credentials docker-push-acr k8s-apply-azure k8s-status

.PHONY: infra-down
infra-down: k8s-delete-azure tf-destroy