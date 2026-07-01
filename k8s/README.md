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
- Deployments
- Services
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
→ Pod postgres:5432
```

## Why PostgreSQL in Kubernetes

Docker Compose validated the multi-service application locally.

This phase translates the same architecture into Kubernetes primitives:

```text
Docker Compose service
→ Kubernetes Deployment + Service
```

The goal is to prepare the application for AKS without using Azure yet.

## Kustomize Structure

```text
k8s/
├── base/
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── secret.yaml
│   ├── postgres-deployment.yaml
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
kubectl get pods -n customer-orders
kubectl get svc -n customer-orders
```

Check logs:

```bash
kubectl logs -n customer-orders deployment/customer-orders-api
kubectl logs -n customer-orders deployment/postgres
```

Port-forward the API:

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

## Cleanup

```bash
kubectl delete -k k8s/overlays/local/
kind delete cluster --name azure-migration-lab
```

## Security Notes

The Kubernetes Secret in this phase contains demo credentials only.

Kubernetes Secrets are base64-encoded by default, not strongly encrypted by themselves.

In later Azure phases, secrets should move toward:

- Azure Key Vault
- Workload Identity
- Key Vault CSI Driver
- external secret management patterns

## Known Limitations

- PostgreSQL is not persistent yet.
- PostgreSQL runs as a Deployment for learning simplicity.
- No StatefulSet yet.
- No PersistentVolumeClaim yet.
- No production-grade secret management yet.
- No managed Azure PostgreSQL yet.
- No network policies yet.

These topics will be addressed progressively.
