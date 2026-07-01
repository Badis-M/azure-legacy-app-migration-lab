# Kubernetes Local Deployment

This folder contains the first Kubernetes version of the Customer Orders API.

## Purpose

This phase validates that the containerized application can run as a Kubernetes workload before moving to Azure AKS.

The goal is to test the core Kubernetes objects locally:

- Namespace
- ConfigMap
- Deployment
- Service
- Readiness probe
- Liveness probe
- Resource requests and limits

## Why Local Kubernetes First

Running locally avoids Azure costs and reduces troubleshooting complexity.

Before deploying to AKS, we validate that:

- the image starts correctly
- the application receives its configuration
- Kubernetes probes can call the `/health` endpoint
- the service can route traffic to the pod
- basic resource limits are defined

## Prerequisites

- Docker Desktop running
- kubectl installed
- kind installed

## Create a Local Cluster

```bash
kind create cluster --name azure-migration-lab
```

## Build the Local Image

From the repository root:

```bash
docker build -t customer-orders-api:local ./containerized-app
```

## Load the Image into kind

```bash
kind load docker-image customer-orders-api:local --name azure-migration-lab
```

## Deploy to Kubernetes

```bash
kubectl apply -f k8s/base/
```

## Validate the Deployment

```bash
kubectl get all -n customer-orders
kubectl get pods -n customer-orders
kubectl describe pod -n customer-orders
```

## Access the Application

```bash
kubectl port-forward -n customer-orders service/customer-orders-api 8000:80
```

Then test:

```bash
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8000/api/customers
curl http://127.0.0.1:8000/api/orders/failed
```

## Cleanup

```bash
kubectl delete -f k8s/base/
kind delete cluster --name azure-migration-lab
```

## Design Notes

This deployment intentionally keeps the setup simple.

The application image is loaded directly into the local kind cluster instead of being pushed to a remote registry. This keeps the phase cost-free and avoids introducing Azure Container Registry too early.

The Kubernetes manifests are written manually to make the underlying objects explicit before introducing Helm or GitOps in later phases.

## Known Limitations

- No Helm chart yet.
- No GitOps workflow yet.
- No Azure Container Registry yet.
- No AKS deployment yet.
- No external database yet.
- No autoscaling yet.
- No ingress controller yet.

These topics will be introduced progressively.
