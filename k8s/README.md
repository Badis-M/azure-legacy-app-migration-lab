# Kubernetes Deployment

This folder contains the Kubernetes manifests for the Customer Orders API and PostgreSQL.

The project uses Kustomize to separate shared Kubernetes resources from environment-specific configuration.

## Current Scope

The Kubernetes stack includes:

- Namespace
- ConfigMap
- Secret with demo-only local credentials
- FastAPI Deployment
- API Service
- PostgreSQL StatefulSet
- PostgreSQL Service
- PostgreSQL Headless Service
- PostgreSQL init SQL ConfigMap
- PersistentVolumeClaim through StatefulSet volumeClaimTemplates
- Local overlay
- Azure overlay

## Structure

```text
k8s/
├── base/
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── secret.yaml
│   ├── postgres-init-configmap.yaml
│   ├── postgres-headless-service.yaml
│   ├── postgres-statefulset.yaml
│   ├── postgres-service.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
└── overlays/
    ├── local/
    │   └── kustomization.yaml
    └── azure/
        └── kustomization.yaml
```

## Architecture

```text
Client
→ kubectl port-forward
→ Service customer-orders-api:80
→ Pod customer-orders-api:8000
→ Service postgres:5432
→ Pod postgres-0:5432
→ PersistentVolumeClaim postgres-data-postgres-0
```

## Why StatefulSet for PostgreSQL

The API is stateless:

```text
Pod deleted
→ new Pod can be created
→ no persistent application data is lost
```

PostgreSQL is stateful:

```text
Pod deleted
→ database files must survive
```

For this reason PostgreSQL uses:

- StatefulSet
- PersistentVolumeClaim
- Headless Service

## Local Overlay

Path:

```text
k8s/overlays/local/
```

Purpose:

```text
Run the stack on a local kind cluster.
```

The local overlay uses the local Docker image:

```text
customer-orders-api:local
```

and:

```text
imagePullPolicy: Never
```

This works because the image is loaded directly into kind:

```bash
kind load docker-image customer-orders-api:local --name azure-migration-lab
```

## Azure Overlay

Path:

```text
k8s/overlays/azure/
```

Purpose:

```text
Prepare the manifests for AKS.
```

The Azure overlay replaces the local API image with the ACR image:

```text
acrazlegacydev001.azurecr.io/customer-orders-api:dev
```

and sets:

```text
imagePullPolicy: IfNotPresent
```

This is required because AKS cannot use images from local Docker. It must pull images from a registry such as Azure Container Registry.

## Render Manifests

Render local manifests:

```bash
kubectl kustomize k8s/overlays/local/
```

Render Azure manifests:

```bash
kubectl kustomize k8s/overlays/azure/
```

Expected local image:

```text
customer-orders-api:local
```

Expected Azure image:

```text
acrazlegacydev001.azurecr.io/customer-orders-api:dev
```

## Local Deployment

Create a kind cluster:

```bash
kind create cluster --name azure-migration-lab
```

Build the local image:

```bash
make docker-build
```

Load the image into kind:

```bash
kind load docker-image customer-orders-api:local --name azure-migration-lab
```

Deploy:

```bash
make k8s-apply-local
```

Check resources:

```bash
kubectl get all -n customer-orders
kubectl get pvc -n customer-orders
kubectl get pods -n customer-orders
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
curl http://127.0.0.1:8000/api/orders/failed
```

Cleanup:

```bash
make k8s-delete-local
```

## Azure Deployment Status

The Azure overlay is ready, but AKS has not been created yet.

Next AKS steps:

```text
1. Create minimal AKS with Terraform
2. Grant AKS permission to pull from ACR
3. Get AKS credentials
4. Apply k8s/overlays/azure/
5. Validate API and PostgreSQL on AKS
6. Destroy resources after validation
```

## Storage Behavior

Local kind:

```text
PVC
→ local Kubernetes storage inside the kind/Docker environment
```

AKS later:

```text
PVC
→ AKS StorageClass
→ Azure Managed Disk
```

This difference will be validated during the AKS phase.

## Secret Notes

The current Kubernetes Secret contains demo-only credentials for the lab.

This is acceptable for the local learning phase, but it is not the final cloud security pattern.

Future Azure phase:

```text
Azure Key Vault
Workload Identity
Secrets Store CSI Driver or External Secrets pattern
```

## Troubleshooting

Check API logs:

```bash
kubectl logs -n customer-orders deployment/customer-orders-api
```

Check PostgreSQL logs:

```bash
kubectl logs -n customer-orders statefulset/postgres
```

Check PVC:

```bash
kubectl get pvc -n customer-orders
kubectl describe pvc postgres-data-postgres-0 -n customer-orders
```

Check image references:

```bash
kubectl kustomize k8s/overlays/local/ | grep -A2 "image:"
kubectl kustomize k8s/overlays/azure/ | grep -A2 "image:"
```

## Known Limitations

Current limitations:

- PostgreSQL still runs inside Kubernetes, not as Azure managed PostgreSQL
- No Azure Key Vault integration yet
- No network policies yet
- No ingress controller yet
- No public exposure yet
- No AKS deployment yet
- No backup strategy yet
- No production-grade secret management yet

These will be addressed progressively.

## Interview Summary

```text
I used Kustomize to separate local and Azure Kubernetes configurations. The local overlay uses a kind-loaded image, while the Azure overlay references the image pushed to Azure Container Registry. PostgreSQL runs as a StatefulSet with a PVC to reflect its stateful nature.
```
