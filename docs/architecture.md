# Architecture

This document describes the architecture of the Azure Legacy App Migration Lab.

The lab is intentionally progressive. It starts from a simple legacy-style application and gradually introduces containers, Kubernetes, Terraform-managed Azure infrastructure, GitHub Actions and operational practices.

---

## Architecture Progression

```text
Legacy FastAPI app
→ Docker image
→ Docker Compose + PostgreSQL
→ Kubernetes local with kind
→ Kustomize base and overlays
→ PostgreSQL StatefulSet + PVC
→ GitHub Actions CI validation
→ Terraform Azure Resource Group + ACR
→ Remote Terraform state in Azure Blob Storage
→ Docker image pushed to Azure Container Registry
→ Terraform-managed AKS cluster
→ AKS kubelet identity authorized with AcrPull
→ Azure Kubernetes overlay deployed to AKS
→ PostgreSQL PVC issue fixed with PGDATA
→ AKS deployment validated
→ Terraform destroy and post-destroy cost check
→ GitHub Actions OIDC authentication check for Azure
→ Manual AKS deployment workflow
```

---

## Runtime Architecture

```text
Developer workstation
│
├── Docker
│   └── customer-orders-api image
│
├── Docker Compose
│   ├── FastAPI API
│   └── PostgreSQL
│
├── kind
│   ├── namespace: customer-orders
│   ├── customer-orders-api Deployment
│   ├── customer-orders-api Service
│   ├── PostgreSQL StatefulSet
│   ├── PostgreSQL Service
│   ├── ConfigMap
│   ├── Secret
│   └── PersistentVolumeClaim
│
└── Azure
    ├── Azure Resource Group
    ├── Azure Container Registry
    ├── Azure Blob Storage Terraform backend
    └── Azure Kubernetes Service
        ├── node pool
        ├── managed identity
        ├── kubelet identity
        ├── AcrPull role assignment
        └── customer-orders namespace
```

---

## Components

### FastAPI application

The application exposes a simple customer/orders API.

Main endpoints:

```text
GET /
GET /health
GET /api/customers
GET /api/orders
GET /api/orders/failed
```

The application reads PostgreSQL connection settings from environment variables supplied by Kubernetes ConfigMaps and Secrets.

### PostgreSQL

PostgreSQL is deployed locally through Docker Compose, locally on Kubernetes with a StatefulSet, and on AKS with the same Kubernetes base manifests.

On Kubernetes, the PostgreSQL container uses:

```text
PGDATA=/var/lib/postgresql/data/pgdata
```

This avoids initializing the database directly at the root of the mounted volume.

### Kubernetes

Kubernetes manifests are split into:

```text
k8s/base/
k8s/overlays/local/
k8s/overlays/azure/
```

The base contains common resources. The overlays define environment-specific image names and pull policies.

### Terraform

Terraform provisions the application Resource Group, Azure Container Registry, AKS cluster, AKS node pool, identities, role assignments and resource tags.

The Terraform state is stored in a separate Azure Blob Storage backend so that application infrastructure can be destroyed without deleting the state backend.

### GitHub Actions

GitHub Actions provides repository validation CI, Azure OIDC authentication validation, and a manual AKS deployment workflow.

OIDC is used to avoid storing long-lived Azure client secrets in GitHub.

---

## Local vs Azure Runtime

| Area | Local | Azure |
|---|---|---|
| Container runtime | Docker Desktop | containerd on AKS nodes |
| Kubernetes | kind | AKS |
| Image source | local Docker image | Azure Container Registry |
| Database | Docker Compose or kind StatefulSet | AKS StatefulSet with PVC |
| Service exposure | port-forward | port-forward initially |
| Infrastructure | local tools | Terraform-managed Azure resources |

---

## Design Principles

- **Reproducibility:** the same application image and Kubernetes base manifests are used across local and Azure environments.
- **Operational simplicity:** Makefile commands reduce manual steps while preserving tool visibility.
- **Cost control:** Azure infrastructure is intentionally small and destroyable.
- **Security:** GitHub Actions uses OIDC instead of long-lived Azure client secrets. AKS pulls from ACR using kubelet identity and `AcrPull`.
- **Troubleshooting value:** the project documents real issues and fixes rather than hiding them.
- **Observability readiness:** Prometheus and Grafana are planned as the next major platform layer.

---

## References

- Azure Well-Architected Framework: https://learn.microsoft.com/en-us/azure/well-architected/
- Azure Architecture Center: https://learn.microsoft.com/en-us/azure/architecture/
