# Local Development

This document describes how to run and validate the project locally.

The local workflow exists to validate the application before deploying to Azure.

---

## Prerequisites

Expected local tools:

```text
Docker
Docker Compose
kubectl
kind
make
curl
```

Optional but useful:

```text
k9s
jq
```

---

## Docker Compose Workflow

Start the application and PostgreSQL locally:

```bash
cd containerized-app
docker compose up --build
```

Validate the API:

```bash
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8000/api/customers
curl http://127.0.0.1:8000/api/orders
curl http://127.0.0.1:8000/api/orders/failed
```

Stop the stack:

```bash
docker compose down
```

Remove volumes if you want a clean database state:

```bash
docker compose down -v
```

---

## kind Workflow

Build the local image:

```bash
make docker-build
```

Create the kind cluster:

```bash
kind create cluster --name azure-migration-lab
```

Load the local Docker image into kind:

```bash
kind load docker-image customer-orders-api:local --name azure-migration-lab
```

Deploy the local Kubernetes overlay:

```bash
make k8s-apply-local
```

Check resources:

```bash
kubectl get pods -n customer-orders
kubectl get svc -n customer-orders
kubectl get pvc -n customer-orders
```

Access the API:

```bash
kubectl port-forward svc/customer-orders-api 8000:80 -n customer-orders
```

Cleanup:

```bash
make k8s-delete-local
kind delete cluster --name azure-migration-lab
```

---

## Kustomize Validation

Render overlays:

```bash
kubectl kustomize k8s/overlays/local/
kubectl kustomize k8s/overlays/azure/
```

The local overlay uses:

```text
customer-orders-api:local
imagePullPolicy: Never
```

The Azure overlay uses:

```text
<acr-login-server>/customer-orders-api:dev
imagePullPolicy: IfNotPresent
```

---

## Common Local Issues

### ImagePullBackOff in kind

Possible cause:

```text
The image was not loaded into kind.
```

Fix:

```bash
kind load docker-image customer-orders-api:local --name azure-migration-lab
kubectl rollout restart deployment/customer-orders-api -n customer-orders
```

### Port already in use

```bash
lsof -i :8000
kubectl port-forward svc/customer-orders-api 8080:80 -n customer-orders
```
