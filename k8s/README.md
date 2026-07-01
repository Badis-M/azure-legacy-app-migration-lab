# Kubernetes Local Deployment

This folder contains the Kubernetes local deployment for the Customer Orders API and PostgreSQL.

## Purpose

This phase validates that the application can run as a multi-service Kubernetes workload before moving to Azure AKS.

The local Kubernetes stack includes:

- Customer Orders API
- PostgreSQL
- Namespace
- ConfigMap
- Secret
- API Deployment
- PostgreSQL StatefulSet
- ClusterIP Services
- Headless Service
- PersistentVolumeClaim
- Readiness and liveness probes
- Resource requests and limits
- Kustomize base and local overlay

## Architecture

```text
localhost:8000
→ kubectl port-forward
→ Service customer-orders-api:80
→ Pod customer-orders-api:8000
→ Service postgres:5432
→ Pod postgres-0:5432
→ PersistentVolumeClaim postgres-data-postgres-0
```

## Why PostgreSQL Uses a StatefulSet

The API is stateless. If the API Pod is deleted, Kubernetes can recreate it without losing application data.

PostgreSQL is stateful. If the PostgreSQL Pod is deleted, the database files must survive.

For this reason, PostgreSQL uses:

- StatefulSet
- Headless Service
- PersistentVolumeClaim

## Deployment vs StatefulSet

```text
Deployment
→ good for stateless workloads
→ example: FastAPI application

StatefulSet
→ good for stateful workloads
→ example: PostgreSQL
```

## Kustomize Structure

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
    └── local/
        └── kustomization.yaml
```

## Deploy Locally

Create the kind cluster:

```bash
kind create cluster --name azure-migration-lab
```

Build the API image:

```bash
docker build -t customer-orders-api:local ./containerized-app
```

Load the image into kind:

```bash
kind load docker-image customer-orders-api:local --name azure-migration-lab
```

Apply the local overlay:

```bash
kubectl apply -k k8s/overlays/local/
```

## Validate

```bash
kubectl get all -n customer-orders
kubectl get pvc -n customer-orders
kubectl get pods -n customer-orders
kubectl get svc -n customer-orders
```

Expected PostgreSQL Pod name:

```text
postgres-0
```

Expected PVC name:

```text
postgres-data-postgres-0
```

## Check Logs

```bash
kubectl logs -n customer-orders statefulset/postgres
kubectl logs -n customer-orders deployment/customer-orders-api
```

## Access the Application

```bash
kubectl port-forward -n customer-orders service/customer-orders-api 8000:80
```

Then test:

```bash
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8000/api/customers
curl http://127.0.0.1:8000/api/orders
curl http://127.0.0.1:8000/api/orders/failed
```

## Cleanup

Delete Kubernetes resources:

```bash
kubectl delete -k k8s/overlays/local/
```

Delete the kind cluster:

```bash
kind delete cluster --name azure-migration-lab
```

## Security Notes

The Kubernetes Secret in this phase contains demo credentials only.

Kubernetes Secrets are base64-encoded by default, not a production-grade secret management solution by themselves.

In later Azure phases, secrets should move toward:

- Azure Key Vault
- Workload Identity
- Key Vault CSI Driver
- external secret management patterns

## Storage Notes

This local setup uses a PersistentVolumeClaim through the default storage behavior available in the local Kubernetes environment.

This is enough for learning StatefulSet and PVC concepts.

In Azure AKS, storage classes and persistent volumes will need to be reviewed carefully for cost, performance, backup, and lifecycle management.

## Known Limitations

- PostgreSQL still runs locally inside Kubernetes.
- No managed Azure PostgreSQL yet.
- No production backup strategy yet.
- No database migration tool yet.
- No network policies yet.
- No Key Vault integration yet.
- No AKS deployment yet.

These topics will be addressed progressively.
