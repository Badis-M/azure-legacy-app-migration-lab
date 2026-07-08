# Azure Legacy App Migration Lab

This repository demonstrates the progressive migration of a legacy-style FastAPI application toward a cloud-native Azure platform.

The goal is not only to deploy an application. The project shows a realistic modernization path using Docker, PostgreSQL, Kubernetes, Terraform, Azure Container Registry, AKS, GitHub Actions, OIDC authentication, and operational troubleshooting.

```text
legacy FastAPI application
→ Docker container
→ Docker Compose with PostgreSQL
→ local Kubernetes with kind
→ Kustomize overlays
→ Terraform-managed Azure infrastructure
→ Azure Container Registry
→ Azure Kubernetes Service
→ CI validation
→ GitHub Actions OIDC authentication
→ manual AKS deployment workflow
```

---

## What This Project Demonstrates

This lab covers:

- containerizing a legacy-style FastAPI application;
- introducing PostgreSQL as a backing service;
- running the stack locally with Docker Compose;
- deploying the application locally on Kubernetes with kind;
- separating Kubernetes base manifests from environment-specific overlays with Kustomize;
- provisioning Azure resources with Terraform modules;
- storing Terraform state remotely in Azure Blob Storage;
- pushing application images to Azure Container Registry;
- deploying the application to Azure Kubernetes Service;
- troubleshooting AKS, ACR, image architecture and PersistentVolume issues;
- validating the repository with GitHub Actions CI;
- authenticating GitHub Actions to Azure with OIDC instead of long-lived client secrets;
- keeping the lab cost-aware and destroyable.

The project intentionally documents real operational issues, not only the final happy path.

---

## Current Status

Validated areas:

- FastAPI application baseline
- Docker containerization
- Docker Compose with PostgreSQL
- Local kind deployment
- Kustomize base and overlays
- PostgreSQL StatefulSet with PVC
- Terraform modules for Azure Resource Group, ACR and AKS
- Remote Terraform state in Azure Blob Storage
- Azure Container Registry image push
- AKS deployment validation
- AKS kubelet identity integration with ACR
- GitHub Actions CI validation workflow
- GitHub Actions Azure OIDC authentication check
- Manual AKS deployment workflow in progress
- Makefile automation and safe cleanup targets
- Operational troubleshooting documentation

Validated AKS state:

```text
customer-orders-api   1/1   Running
postgres-0            1/1   Running
AKS node              Ready
PostgreSQL PVC        Bound
```

---

## High-Level Architecture

```text
Developer workstation
│
├── Docker / Docker Compose
│   ├── FastAPI application
│   └── PostgreSQL database
│
├── Local Kubernetes with kind
│   ├── Kustomize local overlay
│   ├── Local image: customer-orders-api:local
│   └── PostgreSQL StatefulSet + PVC
│
├── Azure
│   ├── Resource Group
│   ├── Azure Container Registry
│   ├── Azure Blob Storage remote Terraform state
│   └── Azure Kubernetes Service
│       ├── System-assigned managed identity
│       ├── Kubelet identity with AcrPull on ACR
│       ├── FastAPI Deployment
│       └── PostgreSQL StatefulSet + PVC
│
└── GitHub Actions
    ├── CI validation workflow
    ├── Azure OIDC authentication check
    └── Manual AKS deployment workflow
```

---

## Repository Structure

```text
.
├── legacy-app/
├── containerized-app/
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
├── docs/
├── .github/
│   └── workflows/
└── Makefile
```

---

## Quick Start

### Local Docker

```bash
cd containerized-app
docker compose up --build
```

Test:

```bash
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8000/api/customers
curl http://127.0.0.1:8000/api/orders
```

### Local Kubernetes

```bash
make docker-build
kind create cluster --name azure-migration-lab
kind load docker-image customer-orders-api:local --name azure-migration-lab
make k8s-apply-local
kubectl port-forward svc/customer-orders-api 8000:80 -n customer-orders
```

### Azure Infrastructure

```bash
make tf-fmt
make tf-validate
make tf-plan
make tf-apply
```

### Azure Deployment

```bash
make aks-credentials
make docker-push-acr
make k8s-apply-azure
make k8s-status
```

### Cleanup

```bash
make infra-down
make cost-check
```

---

## Documentation

Detailed documentation:

- [Architecture](docs/architecture.md)
- [Migration Plan](docs/migration-plan.md)
- [Local Development](docs/local-development.md)
- [Azure Infrastructure](docs/azure-infrastructure.md)
- [AKS Deployment](docs/aks-deployment.md)
- [CI/CD](docs/cicd.md)
- [GitHub Actions OIDC](docs/github-actions-oidc.md)
- [Observability](docs/observability.md)
- [FinOps](docs/finops.md)
- [AKS Troubleshooting](docs/troubleshooting-aks-azure.md)

---

## Cost Guardrails

The lab is designed to be ephemeral:

- one AKS node only;
- controlled VM size;
- no public LoadBalancer by default;
- no managed Grafana at first;
- no Log Analytics at first;
- ClusterIP service with local port-forward for validation;
- explicit destroy workflow;
- post-destroy resource verification.

---

## Next Planned Steps

```text
V9.3  Stabilize manual AKS deployment workflow
V9.4  Add rollout validation and smoke tests
V10   Add Prometheus/Grafana observability
V11   Add runbooks and RCA notes
V12   Add Azure Key Vault integration
V13   Optional GitOps with Argo CD
V14   Optional Kafka/event-driven extension
```

Kafka is intentionally placed after observability because it adds more moving parts and cost. Prometheus and Grafana provide more immediate value for a DevOps/Platform portfolio project.

---

## Interview Summary

```text
I built a progressive Azure migration lab starting from a legacy-style FastAPI application, then modernized it through Docker, Docker Compose, Kubernetes, Kustomize, PostgreSQL StatefulSets, Terraform modules, Azure Container Registry, remote Terraform state, and AKS.

The project includes real troubleshooting work: Azure region and VM SKU restrictions, AKS/ACR authentication through kubelet managed identity, image architecture mismatch from macOS ARM to AKS linux/amd64, PostgreSQL PersistentVolume initialization issues caused by lost+found on the mounted volume, and Terraform backend authentication through GitHub Actions OIDC.

The lab is cost-aware, reproducible, documented, and designed around operational practices: CI validation, manual deployment workflows, safe cleanup, troubleshooting notes, and planned observability.
```
