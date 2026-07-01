# Kubernetes Local Deployment

This folder contains the Kubernetes local deployment for the Customer Orders API.

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
- Kustomize base and local overlay

## Why Local Kubernetes First

Running locally avoids Azure costs and reduces troubleshooting complexity.

Before deploying to AKS, we validate that:

- the image starts correctly
- the application receives its configuration
- Kubernetes probes can call the `/health` endpoint
- the service can route traffic to the pod
- basic resource requests and limits are defined
- manifests can be applied consistently through Kustomize

## Why Kustomize

Kustomize lets us separate common Kubernetes manifests from environment-specific configuration.

Current structure:

```text
k8s/
├── base/
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
└── overlays/
    └── local/
        └── kustomization.yaml
```

The `base` folder contains shared Kubernetes resources.

The `overlays/local` folder points to the base and represents the local deployment environment.

Later, we can add:

```text
k8s/overlays/azure/
```

for AKS-specific configuration.

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

## Deploy with Kustomize

From the repository root:

```bash
kubectl apply -k k8s/overlays/local/
```

This replaces:

```bash
kubectl apply -f k8s/base/
```

Using Kustomize makes the deployment more explicit and prepares the project for GitOps tools such as Argo CD.

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
kubectl delete -k k8s/overlays/local/
kind delete cluster --name azure-migration-lab
```

## Troubleshooting

### Namespace Not Found

If resources fail because the namespace does not exist yet, avoid applying individual YAML files randomly.

Use:

```bash
kubectl apply -k k8s/overlays/local/
```

or create the namespace first:

```bash
kubectl apply -f k8s/base/namespace.yaml
kubectl apply -f k8s/base/
```

The preferred approach for this project is Kustomize.

## Design Notes

The application image is loaded directly into the local kind cluster instead of being pushed to a remote registry. This keeps the phase cost-free and avoids introducing Azure Container Registry too early.

The Kubernetes manifests are written manually to make the underlying objects explicit before introducing Helm or GitOps in later phases.

Kustomize is introduced early because Argo CD can deploy directly from Kustomize overlays.

## Known Limitations

- No Helm chart yet.
- No GitOps workflow yet.
- No Azure Container Registry yet.
- No AKS deployment yet.
- No external database yet.
- No autoscaling yet.
- No ingress controller yet.

These topics will be introduced progressively.
