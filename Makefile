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
	@echo "  tf-fmt                 Format Terraform files"
	@echo "  tf-init                Initialize Terraform"
	@echo "  tf-validate            Validate Terraform"
	@echo "  tf-plan                Run Terraform plan"
	@echo "  tf-apply               Run Terraform apply"
	@echo "  tf-destroy             Destroy Terraform-managed app resources"
	@echo "  tf-check               Format, validate and plan Terraform"
	@echo "  tf-backend-bootstrap   Create Azure Blob backend for Terraform state"
	@echo "  docker-build           Build local Docker image"
	@echo "  docker-build-ci        Build CI Docker image"
	@echo "  acr-login              Login to Azure Container Registry"
	@echo "  docker-tag-acr         Tag Docker image for ACR"
	@echo "  docker-push-acr        Push Docker image to ACR"
	@echo "  k8s-render-local       Render local Kubernetes manifests"
	@echo "  k8s-apply-local        Apply local Kubernetes manifests"
	@echo "  k8s-delete-local       Delete local Kubernetes manifests"

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
docker-push-acr: acr-login docker-tag-acr
	docker push $(ACR_LOGIN_SERVER)/$(IMAGE_NAME):$(IMAGE_TAG)

.PHONY: k8s-render-local
k8s-render-local:
	kubectl kustomize $(K8S_LOCAL_OVERLAY)

.PHONY: k8s-apply-local
k8s-apply-local:
	kubectl apply -k $(K8S_LOCAL_OVERLAY)

.PHONY: k8s-delete-local
k8s-delete-local:
	kubectl delete -k $(K8S_LOCAL_OVERLAY)
