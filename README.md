# Azure Legacy App Migration Lab

This repository demonstrates the progressive migration of a legacy-style FastAPI application toward a cloud-native Azure platform.

The project shows a realistic modernization path using Docker, PostgreSQL, Kubernetes, Terraform, Azure Container Registry, AKS, GitHub Actions, OIDC authentication, Prometheus and Grafana.

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
→ Prometheus/Grafana observability
→ application metrics through /metrics
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
- troubleshooting AKS, ACR, image architecture, Terraform backend and PersistentVolume issues;
- validating the repository with GitHub Actions CI;
- authenticating GitHub Actions to Azure with OIDC instead of long-lived client secrets;
- deploying kube-prometheus-stack for Kubernetes observability;
- exposing FastAPI custom metrics through `/metrics`;
- scraping application metrics with a Prometheus `ServiceMonitor`;
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
- Manual AKS deployment workflow usable against existing infrastructure
- Makefile automation and safe cleanup targets
- kube-prometheus-stack deployed on AKS
- Prometheus and Grafana accessible through port-forward
- FastAPI `/metrics` endpoint
- custom application metrics
- Prometheus `ServiceMonitor` for `customer-orders-api`
- operational troubleshooting documentation

Validated AKS state:

```text
customer-orders-api   1/1   Running
postgres-0            1/1   Running
AKS node              Ready
PostgreSQL PVC        Bound
```

Validated observability state:

```text
monitoring namespace      OK
Prometheus                OK
Grafana                   OK
Alertmanager              OK
kube-state-metrics        OK
node-exporter             OK
/metrics endpoint         OK
ServiceMonitor            OK
custom app metrics        OK
```

Example application metrics:

```text
customer_orders_http_requests_total
customer_orders_http_request_duration_seconds
customer_orders_failed_orders_total
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
│       ├── PostgreSQL StatefulSet + PVC
│       └── monitoring namespace
│           ├── Prometheus
│           ├── Grafana
│           ├── Alertmanager
│           ├── kube-state-metrics
│           └── node-exporter
│
└── GitHub Actions
    ├── CI validation workflow
    ├── Azure OIDC authentication check
    └── Manual AKS deployment workflow
```

---

## Quick Start

### Local Docker

```bash
cd containerized-app
docker compose up --build
```

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

### Observability

```bash
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values monitoring/kube-prometheus-stack-values.yaml
```

Grafana:

```bash
kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring
```

Prometheus:

```bash
kubectl port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090 -n monitoring
```

Application metrics:

```bash
kubectl port-forward svc/customer-orders-api 8000:80 -n customer-orders
curl http://localhost:8000/metrics | grep customer_orders
```

### Cleanup

```bash
make infra-down
make cost-check
```

---

## Documentation

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

## Current Known Limitation

The manual GitHub Actions deployment workflow works when Azure infrastructure already exists.

Creating AKS directly from GitHub Actions with the OIDC service principal may fail on Azure for Students with a region policy error, even when the same Terraform apply works from the local Azure user session.

Current practical workflow:

```text
Create Azure infrastructure from local Terraform
→ Run GitHub Actions deployment with apply_infra=false
→ Validate build, push, kubectl apply and rollout
```

---

## Next Planned Steps

Recommended consolidation tasks:

```text
1. Commit application metrics and ServiceMonitor changes
2. Update docs and README
3. Capture Grafana and Prometheus validation screenshots
4. Destroy Azure resources after validation
5. Prepare interview explanation
```

Optional future phases:

```text
V11   Add Grafana dashboard JSON or screenshots
V12   Add alerting rules
V13   Add Azure Key Vault integration
V14   Optional GitOps with Argo CD
V15   Optional Kafka/event-driven extension
```

Kafka, Argo CD and Key Vault are intentionally deferred. The current project is already substantial and should be consolidated before adding more platform components.

---

## Interview Summary

```text
I built a progressive Azure migration lab starting from a legacy-style FastAPI application, then modernized it through Docker, Docker Compose, Kubernetes, Kustomize, PostgreSQL StatefulSets, Terraform modules, Azure Container Registry, remote Terraform state, and AKS.

The project includes real troubleshooting work: Azure region and VM SKU restrictions, AKS/ACR authentication through kubelet managed identity, image architecture mismatch from macOS ARM to AKS linux/amd64, PostgreSQL PersistentVolume initialization issues caused by lost+found on the mounted volume, GitHub Actions OIDC authentication, and Terraform backend permissions on Azure Blob Storage.

I also added observability with kube-prometheus-stack. Prometheus and Grafana monitor the Kubernetes platform, and the FastAPI application exposes custom Prometheus metrics through a /metrics endpoint. A ServiceMonitor allows Prometheus to scrape the application automatically, giving visibility into request volume, latency histograms and failed order counts.

The lab is cost-aware, reproducible, documented, and designed around operational practices: CI validation, manual deployment workflows, safe cleanup, troubleshooting notes and observability.
```
