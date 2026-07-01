# Azure Legacy App Migration Lab

This project demonstrates the progressive migration of a legacy-style application toward a cloud-native Azure platform.

The goal is not only to deploy an application, but to show a realistic modernization path using containers, Kubernetes, Terraform, Azure, CI, and operational practices.

## Current Status

The project currently covers:

- Legacy FastAPI application baseline
- Docker containerization
- Docker Compose with PostgreSQL
- Local Kubernetes deployment with kind
- Kustomize base and overlays
- PostgreSQL StatefulSet with PersistentVolumeClaim
- GitHub Actions CI
- Terraform Azure foundation
- Terraform modules
- Remote Terraform state in Azure Blob Storage
- Azure Container Registry
- Docker image push to ACR
- Azure Kubernetes overlay using the ACR image
- Makefile automation
- Terraform backend bootstrap script

## Architecture Progression

```text
Legacy FastAPI app
→ Docker image
→ Docker Compose + PostgreSQL
→ Kubernetes local with kind
→ Kustomize overlays
→ PostgreSQL StatefulSet + PVC
→ GitHub Actions CI
→ Terraform Azure Resource Group + ACR
→ Remote Terraform state in Azure Blob Storage
→ Docker image pushed to Azure Container Registry
→ Azure Kubernetes overlay prepared for AKS
```

## Repository Structure

```text
.
├── legacy-app/
│   └── Initial legacy-style FastAPI application
├── containerized-app/
│   └── Dockerized FastAPI application with PostgreSQL support
├── k8s/
│   ├── base/
│   └── overlays/
│       ├── local/
│       └── azure/
├── infra/
│   └── terraform/
│       ├── modules/
│       ├── main.tf
│       ├── providers.tf
│       ├── variables.tf
│       └── outputs.tf
├── scripts/
│   └── bootstrap-tfstate-backend.sh
├── .github/
│   └── workflows/
└── Makefile
```

## Application

The application exposes a simple customer/orders API.

Main endpoints:

```text
GET /
GET /health
GET /api/customers
GET /api/orders
GET /api/orders/failed
```

## Local Docker Workflow

Build and run the application stack locally:

```bash
cd containerized-app
docker compose up --build
```

Test:

```bash
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8000/api/customers
```

## Local Kubernetes Workflow

Build the image:

```bash
make docker-build
```

Create and prepare the kind cluster:

```bash
kind create cluster --name azure-migration-lab
kind load docker-image customer-orders-api:local --name azure-migration-lab
```

Deploy locally:

```bash
make k8s-apply-local
```

Access the API:

```bash
kubectl port-forward -n customer-orders service/customer-orders-api 8000:80
```

Test:

```bash
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8000/api/customers
```

Cleanup:

```bash
make k8s-delete-local
```

## Azure Foundation

Terraform currently provisions:

- Azure Resource Group
- Azure Container Registry Basic
- Tags for FinOps tracking

The Terraform state is stored remotely in Azure Blob Storage.

The backend is bootstrapped separately from the application infrastructure to avoid destroying the state backend during normal `terraform destroy` operations.

## Terraform Workflow

```bash
make tf-fmt
make tf-validate
make tf-plan
make tf-apply
```

Destroy application resources:

```bash
make tf-destroy
```

The remote Terraform state backend is not destroyed by `make tf-destroy`.

## Azure Container Registry Workflow

Login to ACR:

```bash
make acr-login
```

Build the image:

```bash
make docker-build
```

Push the image to ACR:

```bash
make docker-push-acr
```

Verify:

```bash
az acr repository list --name acrazlegacydev001 --output table
az acr repository show-tags \
  --name acrazlegacydev001 \
  --repository customer-orders-api \
  --output table
```

Current pushed image:

```text
acrazlegacydev001.azurecr.io/customer-orders-api:dev
```

## Kubernetes Overlays

Local overlay:

```text
k8s/overlays/local/
```

Uses:

```text
customer-orders-api:local
imagePullPolicy: Never
```

Azure overlay:

```text
k8s/overlays/azure/
```

Uses:

```text
acrazlegacydev001.azurecr.io/customer-orders-api:dev
imagePullPolicy: IfNotPresent
```

Render overlays:

```bash
kubectl kustomize k8s/overlays/local/
kubectl kustomize k8s/overlays/azure/
```

## CI

GitHub Actions validates:

- Docker build
- Kubernetes manifest rendering with Kustomize
- YAML linting

## Makefile

Common commands:

```bash
make help
make tf-plan
make docker-build
make docker-push-acr
make k8s-render-local
make k8s-apply-local
make k8s-delete-local
```

The backend bootstrap command exists for initial setup or backend reconstruction:

```bash
make tf-backend-bootstrap
```

It is not part of the normal daily workflow.

## Cost and Cleanup Notes

Current Azure resources are lightweight:

- One Resource Group for the application infrastructure
- One Basic Azure Container Registry
- One separate Resource Group and Storage Account for Terraform remote state

AKS has not been created yet.

Before creating AKS, the project will add cost guardrails:

- Free tier AKS control plane
- One node only
- Controlled VM size
- No Log Analytics at first
- No public LoadBalancer unless needed
- Explicit destroy workflow
- Azure resource verification after destroy

## Next Planned Steps

Planned next phases:

```text
V8   AKS minimal with Terraform
V8.1 AKS AcrPull integration through managed identity
V8.2 Deploy application to AKS using the Azure overlay
V8.3 Validate PVC behavior on AKS
V8.4 Destroy and verify cleanup
V9   Improve CI/CD
V10  Azure Key Vault and cloud-native secret management
V11  Observability with Prometheus/Grafana
V12  Runbooks and RCA documentation
```

## Interview Summary

```text
I built a progressive Azure migration lab starting from a legacy-style FastAPI application, then modernized it through Docker, Docker Compose, Kubernetes, Kustomize, PostgreSQL StatefulSets, Terraform modules, Azure Container Registry, remote Terraform state, and CI validation. The project is intentionally cost-aware and prepares for a controlled AKS deployment.
```
