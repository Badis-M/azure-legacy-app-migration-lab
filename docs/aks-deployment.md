# AKS Deployment

This document describes how the application is deployed to Azure Kubernetes Service.

---

## Deployment Overview

```text
Terraform infrastructure
→ AKS credentials
→ Docker Buildx linux/amd64 image
→ Push to Azure Container Registry
→ Apply Azure Kustomize overlay
→ Validate PostgreSQL StatefulSet
→ Validate FastAPI Deployment
→ Port-forward and test API
```

---

## Get AKS Credentials

```bash
make aks-credentials
```

Equivalent command:

```bash
az aks get-credentials   --resource-group <app-resource-group>   --name <aks-cluster-name>   --overwrite-existing
```

Verify context:

```bash
kubectl config current-context
kubectl get nodes -o wide
```

Expected context:

```text
<aks-cluster-name>
```

---

## Build and Push Image

```bash
make acr-login
make docker-push-acr
```

The image is built for AKS node architecture:

```bash
docker buildx build   --platform linux/amd64   -t <acr-login-server>/customer-orders-api:dev   ./containerized-app   --push
```

---

## Deploy Azure Overlay

Render the overlay:

```bash
make k8s-render-azure
```

Apply:

```bash
make k8s-apply-azure
```

The Azure overlay uses:

```text
<acr-login-server>/customer-orders-api:dev
imagePullPolicy: IfNotPresent
```

---

## Validate Rollout

```bash
kubectl get pods -n customer-orders -o wide
kubectl get svc -n customer-orders
kubectl get pvc -n customer-orders
kubectl rollout status deployment/customer-orders-api -n customer-orders
kubectl rollout status statefulset/postgres -n customer-orders
```

Expected state:

```text
customer-orders-api   1/1   Running
postgres-0            1/1   Running
```

---

## Application Validation

Port-forward:

```bash
kubectl port-forward svc/customer-orders-api 8000:80 -n customer-orders
```

Test:

```bash
curl http://localhost:8000/health
curl http://localhost:8000/api/customers
curl http://localhost:8000/api/orders
curl http://localhost:8000/api/orders/failed
```

Expected behavior:

- `/health` returns a healthy status;
- `/api/customers` returns customer data loaded from PostgreSQL;
- `/api/orders` returns order data loaded from PostgreSQL;
- `/api/orders/failed` returns failed orders for operational testing.

---

## Safe Deployment Checks

```bash
make aks-check
```

This validates Terraform outputs, the current Kubernetes context, and that the current context matches the expected AKS cluster.

Deployment targets such as `k8s-apply-azure`, `k8s-status` and `k8s-port-forward` depend on this check.

---

## Cleanup

```bash
make infra-down
make cost-check
```
