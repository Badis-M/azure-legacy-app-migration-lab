# Azure Legacy App Migration Lab

This project demonstrates the progressive migration of a legacy-style application toward a cloud-native Azure platform.

The goal is not only to deploy an application, but to show a realistic modernization path using containers, Kubernetes, Terraform, Azure, CI, and operational troubleshooting practices.

The lab intentionally follows a progressive path:

```text
legacy application
→ containerized application
→ local multi-container runtime
→ local Kubernetes
→ cloud container registry
→ Terraform-managed Azure infrastructure
→ AKS deployment
→ operational troubleshooting and documentation
```

---

## Project Goals

This repository is designed as a portfolio-grade cloud migration lab.

It demonstrates:

- how to containerize a legacy-style FastAPI application;
- how to introduce PostgreSQL as a backing service;
- how to run the same application locally with Docker Compose;
- how to deploy it locally on Kubernetes with kind;
- how to separate Kubernetes base manifests from environment-specific overlays with Kustomize;
- how to provision Azure resources with Terraform modules;
- how to store Terraform state remotely in Azure Blob Storage;
- how to push application images to Azure Container Registry;
- how to deploy the application to Azure Kubernetes Service;
- how to troubleshoot realistic AKS, ACR, image architecture and persistent volume issues;
- how to keep the lab cost-aware and ephemeral.

The project does not present a clean happy path only. It also documents the real operational issues encountered during the AKS deployment and the steps used to fix them.

---

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
- Terraform-managed AKS cluster
- AKS kubelet identity integration with ACR
- Azure Kubernetes overlay using the ACR image
- PostgreSQL StatefulSet validation on AKS
- Makefile automation
- Terraform backend bootstrap script
- AKS deployment troubleshooting documentation

Validated AKS state:

```text
customer-orders-api   1/1   Running
postgres-0            1/1   Running
AKS node              Ready
PostgreSQL PVC        Bound
```

---

## Architecture Progression

```text
Legacy FastAPI app
→ Docker image
→ Docker Compose + PostgreSQL
→ Kubernetes local with kind
→ Kustomize base and overlays
→ PostgreSQL StatefulSet + PVC
→ GitHub Actions CI
→ Terraform Azure Resource Group + ACR
→ Remote Terraform state in Azure Blob Storage
→ Docker image pushed to Azure Container Registry
→ Terraform-managed AKS cluster
→ AKS kubelet identity authorized with AcrPull
→ Azure Kubernetes overlay deployed to AKS
→ PostgreSQL PVC issue fixed with PGDATA
→ AKS deployment validated
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
└── Azure
    ├── Resource Group
    ├── Azure Container Registry
    │   └── <acr-login-server>/customer-orders-api:dev
    ├── Azure Blob Storage remote Terraform state
    └── Azure Kubernetes Service
        ├── System-assigned managed identity
        ├── Kubelet identity with AcrPull on ACR
        ├── Azure Kubernetes overlay
        ├── FastAPI Deployment
        └── PostgreSQL StatefulSet + PVC
```

---

## Repository Structure

```text
.
├── legacy-app/
│   └── Initial legacy-style FastAPI application
├── containerized-app/
│   └── Dockerized FastAPI application with PostgreSQL support
├── k8s/
│   ├── base/
│   │   ├── FastAPI Deployment and Service
│   │   ├── PostgreSQL StatefulSet and Services
│   │   ├── ConfigMap and Secret
│   │   └── PostgreSQL init SQL
│   └── overlays/
│       ├── local/
│       │   └── Local kind configuration
│       └── azure/
│           └── AKS / ACR configuration
├── infra/
│   └── terraform/
│       ├── modules/
│       │   ├── acr/
│       │   ├── aks/
│       │   └── resource-group/
│       ├── main.tf
│       ├── providers.tf
│       ├── variables.tf
│       └── outputs.tf
├── docs/
│   └── troubleshooting-aks-azure.md
├── scripts/
│   └── bootstrap-tfstate-backend.sh
├── .github/
│   └── workflows/
└── Makefile
```

---

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

The application connects to PostgreSQL through environment variables provided by Kubernetes ConfigMaps and Secrets.

---

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
curl http://127.0.0.1:8000/api/orders
```

---

## Local Kubernetes Workflow

Build the local image:

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
curl http://127.0.0.1:8000/api/orders
```

Cleanup:

```bash
make k8s-delete-local
```

---

## Kubernetes Overlays

The project uses Kustomize to separate the common Kubernetes base from environment-specific settings.

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
<acr-login-server>/customer-orders-api:dev
imagePullPolicy: IfNotPresent
```

Render overlays:

```bash
kubectl kustomize k8s/overlays/local/
kubectl kustomize k8s/overlays/azure/
```

---

## Azure Foundation

Terraform provisions the Azure foundation required for the lab:

- Azure Resource Group
- Azure Container Registry Basic
- Azure Kubernetes Service
- AKS system node pool
- AKS managed identity
- AcrPull role assignment for the AKS kubelet identity
- Tags for FinOps tracking

The Terraform state is stored remotely in Azure Blob Storage.

The backend is bootstrapped separately from the application infrastructure to avoid destroying the state backend during normal `terraform destroy` operations.

---

## Terraform Remote State

The remote backend uses:

The concrete backend resource names are intentionally represented as placeholders in this public documentation. They are configured through Terraform backend configuration and local Azure CLI context.

```text
Resource Group:  <tfstate-resource-group>
Storage Account: <tfstate-storage-account>
Container:       tfstate
State key:       azure-legacy-migration-lab/dev.tfstate
```

Bootstrap the backend if needed:

```bash
make tf-backend-bootstrap
```

This backend bootstrap step is not part of the normal daily workflow.

---

## Terraform Workflow

Format, validate and plan:

```bash
make tf-fmt
make tf-validate
make tf-plan
```

Apply infrastructure:

```bash
make tf-apply
```

Destroy application infrastructure:

```bash
make tf-destroy
```

The remote Terraform state backend is not destroyed by `make tf-destroy`.

---

## AKS Configuration

The AKS cluster is provisioned by Terraform.

The working lab configuration uses:

```hcl
location         = "francecentral"
aks_location     = "austriaeast"
aks_node_vm_size = "Standard_B2s_v2"
```

The Resource Group and ACR are kept in France Central, while AKS is deployed in Austria East due to Azure subscription, region, VM SKU and vCPU quota constraints encountered during provisioning.

The cluster was validated with:

```bash
az aks get-credentials \
  --resource-group <app-resource-group> \
  --name <aks-cluster-name> \
  --overwrite-existing

kubectl get nodes -o wide
```

Expected result:

```text
NAME                             STATUS   VERSION
aks-system-xxxxxxxx-vmss000000   Ready    v1.35.5
```

Before applying Kubernetes manifests to AKS, always verify the current context:

```bash
kubectl config current-context
kubectl get nodes -o wide
```

Expected context:

```text
<aks-cluster-name>
```

---

## Azure Container Registry Workflow

Login to ACR:

```bash
make acr-login
```

Build the image locally:

```bash
make docker-build
```

Push the image to ACR:

```bash
make docker-push-acr
```

Verify:

```bash
az acr repository list --name <acr-name> --output table
az acr repository show-tags \
  --name <acr-name> \
  --repository customer-orders-api \
  --output table
```

Current pushed image:

```text
<acr-login-server>/customer-orders-api:dev
```

For AKS nodes running on `linux/amd64`, the image can be rebuilt and pushed explicitly for the target platform:

```bash
docker buildx build \
  --platform linux/amd64 \
  -t <acr-login-server>/customer-orders-api:dev \
  ./containerized-app \
  --push
```

---

## AKS Deployment Workflow

Deploy the Azure overlay:

```bash
make k8s-apply-azure
```

Watch pods:

```bash
kubectl get pods -n customer-orders -w
```

Validate Kubernetes resources:

```bash
kubectl get pods -n customer-orders
kubectl get nodes -o wide
kubectl get pvc -n customer-orders
kubectl get svc -n customer-orders
```

Validated result:

```text
NAME                                   READY   STATUS    RESTARTS   AGE
customer-orders-api-xxxxxxxxxx-xxxxx   1/1     Running   0          10m
postgres-0                             1/1     Running   0          7m47s
```

```text
NAME                             STATUS   ROLES    VERSION
aks-system-xxxxxxxx-vmss000000   Ready    <none>   v1.35.5
```

```text
NAME                       STATUS   CAPACITY   ACCESS MODES   STORAGECLASS
postgres-data-postgres-0   Bound    1Gi        RWO            default
```

---

## Application Validation on AKS

Port-forward the API service:

```bash
kubectl port-forward svc/customer-orders-api 8000:80 -n customer-orders
```

Test from another terminal:

```bash
curl http://localhost:8000/health
curl http://localhost:8000/api/customers
curl http://localhost:8000/api/orders
curl http://localhost:8000/api/orders/failed
```

Expected behavior:

- `/health` returns a healthy status.
- `/api/customers` returns customer data loaded from PostgreSQL.
- `/api/orders` returns order data loaded from PostgreSQL.
- `/api/orders/failed` returns failed orders for operational testing.

---

## Operational Troubleshooting

A dedicated troubleshooting document captures the main AKS deployment issues encountered during the lab:

```text
docs/troubleshooting-aks-azure.md
```

It documents:

- Azure subscription region, SKU and quota constraints;
- wrong Kubernetes context between kind and AKS;
- ACR image pull failures from AKS;
- AKS kubelet identity and `AcrPull` role assignment;
- image architecture mismatch from macOS/ARM to AKS `linux/amd64` nodes;
- PostgreSQL `CrashLoopBackOff` caused by `lost+found` on a mounted PersistentVolume;
- the `PGDATA` fix used to initialize PostgreSQL inside a subdirectory.

Troubleshooting notes:

[AKS Azure Troubleshooting Notes](docs/troubleshooting-aks-azure.md)

---

## Key Issues Fixed During AKS Deployment

### 1. Azure region, SKU and quota restrictions

Initial AKS attempts failed in several regions due to a combination of restricted Azure for Students subscription behavior, unavailable VM sizes, blocked regions and vCPU quota issues.

Observed examples:

```text
VMSizeNotSupported
ErrCode_InsufficientVCPUQuota
RequestDisallowedByAzure
```

Resolution:

```text
Use austriaeast for AKS and Standard_B2s_v2 for the node pool.
```

### 2. Wrong Kubernetes context

The Azure overlay was initially observed from the local kind context.

Resolution:

```bash
kubectl config current-context
az aks get-credentials \
  --resource-group <app-resource-group> \
  --name <aks-cluster-name> \
  --overwrite-existing
kubectl get nodes -o wide
```

### 3. ACR pull failure from AKS

Symptoms:

```text
ErrImagePull
ImagePullBackOff
401 Unauthorized
no match for platform in manifest
```

Resolution:

```bash
ACR_ID=$(az acr show --name <acr-name> --query id -o tsv)

KUBELET_OBJECT_ID=$(az aks show \
  --resource-group <app-resource-group> \
  --name <aks-cluster-name> \
  --query "identityProfile.kubeletidentity.objectId" \
  -o tsv)

az role assignment create \
  --assignee-object-id "$KUBELET_OBJECT_ID" \
  --assignee-principal-type ServicePrincipal \
  --role AcrPull \
  --scope "$ACR_ID"
```

Then rebuild and push the image for AKS node architecture:

```bash
docker buildx build \
  --platform linux/amd64 \
  -t <acr-login-server>/customer-orders-api:dev \
  ./containerized-app \
  --push
```

### 4. PostgreSQL PersistentVolume initialization failure

Symptoms:

```text
CrashLoopBackOff
initdb: error: directory "/var/lib/postgresql/data" exists but is not empty
initdb: detail: It contains a lost+found directory
```

Resolution:

```yaml
env:
  - name: PGDATA
    value: /var/lib/postgresql/data/pgdata
```

Then recreate the StatefulSet and PVC for this lab environment:

```bash
kubectl delete statefulset postgres -n customer-orders
kubectl delete pvc postgres-data-postgres-0 -n customer-orders
make k8s-apply-azure
```

---

## PostgreSQL StatefulSet Notes

The PostgreSQL container uses `PGDATA` to avoid initializing the database directly at the root of the mounted volume.

Relevant manifest section:

```yaml
containers:
  - name: postgres
    image: postgres:17-alpine
    ports:
      - containerPort: 5432
    env:
      - name: PGDATA
        value: /var/lib/postgresql/data/pgdata
    envFrom:
      - configMapRef:
          name: customer-orders-config
      - secretRef:
          name: postgres-secret
```

This avoids the AKS PersistentVolume `lost+found` initialization issue.

---

## CI

GitHub Actions validates:

- Docker build
- Kubernetes manifest rendering with Kustomize
- YAML linting

The CI pipeline intentionally validates manifests without requiring a live AKS cluster.

---

## Makefile

Common commands:

```bash
make help
make tf-fmt
make tf-validate
make tf-plan
make tf-apply
make tf-destroy
make docker-build
make docker-push-acr
make k8s-render-local
make k8s-render-azure
make k8s-apply-local
make k8s-apply-azure
make k8s-delete-local
make k8s-delete-azure
make aks-credentials
make aks-nodes
```

The backend bootstrap command exists for initial setup or backend reconstruction:

```bash
make tf-backend-bootstrap
```

It is not part of the normal daily workflow.

---

## Cost and Cleanup Notes

This lab is intentionally cost-aware.

Current Azure resources used during the full AKS validation:

- One Resource Group for application infrastructure
- One Basic Azure Container Registry
- One AKS cluster with a single node
- One dynamically provisioned PostgreSQL PersistentVolume
- One separate Resource Group and Storage Account for Terraform remote state

Cost guardrails:

- One AKS node only
- Controlled VM size
- No Log Analytics at first
- No managed Grafana at first
- No public LoadBalancer by default
- ClusterIP service with local port-forward for validation
- Explicit destroy workflow
- Azure resource verification after destroy

Destroy application infrastructure:

```bash
make tf-destroy
```

After destroy, verify Azure resources if needed:

```bash
az resource list \
  --resource-group <app-resource-group> \
  --output table
```

The Terraform backend resource group is intentionally separate and is not destroyed by the normal lab cleanup.

---

## Documentation

Main operational documentation:

Public documentation uses placeholders for Azure resource names where possible. This avoids exposing a precise inventory of personal or temporary cloud resources while keeping the deployment workflow reproducible.


```text
docs/troubleshooting-aks-azure.md
```

This file is part of the project because the operational path matters as much as the final deployment. It explains the symptoms, investigation, root causes, commands and fixes used to reach the final working AKS deployment.

---

## References

Useful official documentation:

- AKS quotas, SKUs and regions: <https://learn.microsoft.com/en-us/azure/aks/quotas-skus-regions>
- AKS and ACR integration: <https://learn.microsoft.com/en-us/azure/aks/cluster-container-registry-integration>
- Kubernetes private registry image pulls: <https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/>
- Kubernetes pod logs: <https://kubernetes.io/docs/reference/kubectl/generated/kubectl_logs/>
- PostgreSQL Docker image: <https://hub.docker.com/_/postgres>

---

## Next Planned Steps

Planned next phases:

```text
V8.4  Destroy and verify cleanup
V8.5  Commit AKS validation and troubleshooting documentation
V9    Improve CI/CD
V10   Azure Key Vault and cloud-native secret management
V11   Observability with Prometheus/Grafana
V12   Runbooks and RCA documentation
V13   Optional GitOps deployment with Argo CD
```

Potential improvements:

- Move database credentials from Kubernetes Secret to Azure Key Vault integration.
- Add GitHub Actions deployment workflow with manual approval.
- Add smoke tests after deployment.
- Add Prometheus metrics and Grafana dashboards.
- Add an RCA document based on the AKS deployment issues.
- Add cost verification commands after `terraform destroy`.

---

## Interview Summary

```text
I built a progressive Azure migration lab starting from a legacy-style FastAPI application, then modernized it through Docker, Docker Compose, Kubernetes, Kustomize, PostgreSQL StatefulSets, Terraform modules, Azure Container Registry, remote Terraform state, and AKS.

The project includes real troubleshooting work: Azure region and VM SKU restrictions, AKS/ACR authentication through kubelet managed identity, image architecture mismatch from macOS ARM to AKS linux/amd64, and PostgreSQL PersistentVolume initialization issues caused by lost+found on the mounted volume.

The lab is intentionally cost-aware, reproducible and documented with both deployment workflows and operational troubleshooting notes.
```
