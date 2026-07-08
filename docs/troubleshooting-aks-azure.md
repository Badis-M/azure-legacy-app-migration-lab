# AKS Azure Troubleshooting Notes

> Public documentation uses placeholders for concrete Azure resource names. The troubleshooting flow, commands and root causes are preserved, but temporary personal cloud resource identifiers are not exposed.

This document captures the main issues encountered while deploying and operating the `customer-orders` application on Azure Kubernetes Service.

The goal is to show the operational troubleshooting path, not only the final working state.

---

## Final Validated State

Application validation:

```bash
kubectl get pods -n customer-orders
kubectl get nodes -o wide
kubectl get pvc -n customer-orders
kubectl get svc -n customer-orders
```

Expected state:

```text
customer-orders-api-xxxxxxxxxx-xxxxx   1/1   Running
postgres-0                             1/1   Running
aks-system-xxxxxxxx-vmss000000         Ready
postgres-data-postgres-0               Bound
```

Observability validation:

```bash
kubectl get pods -n monitoring
kubectl get svc -n monitoring
kubectl get servicemonitor -n customer-orders
curl http://localhost:8000/metrics | grep customer_orders
```

Expected state:

```text
Prometheus                  Running
Grafana                     Running
Alertmanager                Running
ServiceMonitor              Present
/metrics                    200 OK
customer_orders_* metrics   Present
```

---

## Architecture Context

The lab deploys:

- FastAPI application containerized with Docker;
- Azure Container Registry for private image storage;
- Azure Kubernetes Service for cloud Kubernetes;
- PostgreSQL as a Kubernetes StatefulSet;
- Kubernetes manifests managed with Kustomize overlays;
- Azure infrastructure managed with Terraform;
- remote Terraform state in Azure Blob Storage;
- GitHub Actions OIDC authentication;
- kube-prometheus-stack for monitoring;
- FastAPI custom metrics scraped through a ServiceMonitor;
- cost-controlled single-node AKS.

---

## Issue 1 — Azure Subscription, Region and VM SKU Constraints

### Symptoms

AKS creation failed with errors such as:

```text
VMSizeNotSupported
ErrCode_InsufficientVCPUQuota
RequestDisallowedByAzure
```

### Root Cause

The Azure for Students subscription had restricted access to some regions, VM SKUs and quotas.

### Resolution

Working configuration:

```hcl
location         = "francecentral"
aks_location     = "austriaeast"
aks_node_vm_size = "Standard_B2s_v2"
```

Validation:

```bash
az aks get-credentials \
  --resource-group <app-resource-group> \
  --name <aks-cluster-name> \
  --overwrite-existing

kubectl get nodes -o wide
```

### Interview Takeaway

I had to troubleshoot Azure subscription-level constraints before reaching the Kubernetes layer. The issue involved regional policy, VM SKU restrictions and vCPU quotas, not Terraform syntax.

---

## Issue 2 — Wrong Kubernetes Context

### Symptoms

Azure manifests were applied while `kubectl` was still targeting the local kind cluster.

### Root Cause

The active kubeconfig context was wrong.

### Resolution

```bash
az aks get-credentials \
  --resource-group <app-resource-group> \
  --name <aks-cluster-name> \
  --overwrite-existing

kubectl config current-context
kubectl get nodes -o wide
```

### Interview Takeaway

I caught a deployment-context issue where cloud manifests were initially applied to the local cluster. I corrected it by validating kubeconfig context and node type before redeploying.

---

## Issue 3 — AKS Could Not Pull Private Image from ACR

### Symptoms

```text
ErrImagePull
ImagePullBackOff
401 Unauthorized
no match for platform in manifest
```

### Root Cause

Two issues contributed:

1. AKS kubelet identity needed explicit `AcrPull` on ACR.
2. The image had initially been built from macOS ARM without explicitly targeting AKS node architecture.

### Resolution

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

Rebuild for AKS node architecture:

```bash
docker buildx build \
  --platform linux/amd64 \
  -t <acr-login-server>/customer-orders-api:dev \
  ./containerized-app \
  --push
```

### Interview Takeaway

The ACR issue required troubleshooting both identity and image architecture. I verified the kubelet managed identity, assigned `AcrPull`, rebuilt the image for `linux/amd64`, and validated the rollout.

---

## Issue 4 — PostgreSQL CrashLoopBackOff on AKS PersistentVolume

### Symptoms

```text
postgres-0   0/1   CrashLoopBackOff
```

Logs:

```text
initdb: error: directory "/var/lib/postgresql/data" exists but is not empty
initdb: detail: It contains a lost+found directory
```

### Root Cause

PostgreSQL was initializing directly at the root of the mounted volume, which contained a filesystem-level `lost+found` directory.

### Resolution

```yaml
env:
  - name: PGDATA
    value: /var/lib/postgresql/data/pgdata
```

Then recreate the failed StatefulSet/PVC for the lab:

```bash
kubectl delete statefulset postgres -n customer-orders
kubectl delete pvc postgres-data-postgres-0 -n customer-orders
make k8s-apply-azure
```

### Interview Takeaway

The PostgreSQL issue was diagnosed from container logs. I identified the `lost+found` mount-point problem, updated the StatefulSet with `PGDATA`, recreated the failed PVC and validated the database pod.

---

## Issue 5 — Terraform OIDC Authentication in GitHub Actions

### Symptoms

```text
Error building ARM Config:
Authenticating using the Azure CLI is only supported as a User
not a Service Principal.
```

### Root Cause

`azure/login` authenticated Azure CLI through OIDC, but Terraform needed explicit OIDC environment variables.

### Resolution

```yaml
env:
  ARM_USE_OIDC: true
  ARM_USE_AZUREAD: true
  ARM_CLIENT_ID: ${{ vars.AZURE_CLIENT_ID }}
  ARM_TENANT_ID: ${{ vars.AZURE_TENANT_ID }}
  ARM_SUBSCRIPTION_ID: ${{ vars.AZURE_SUBSCRIPTION_ID }}
```

### Interview Takeaway

I validated GitHub Actions OIDC with Azure CLI, then adapted Terraform authentication to use explicit OIDC environment variables for non-interactive CI/CD deployment.

---

## Issue 6 — Terraform Backend 403 on Azure Blob Storage

### Symptoms

```text
StatusCode=403
AuthorizationPermissionMismatch
Failed to get existing workspaces: containers.Client#ListBlobs
```

### Root Cause

The service principal had management-plane access but lacked data-plane access to the Terraform state blob container.

### Resolution

Assign:

```text
Storage Blob Data Contributor
```

at the Terraform state container scope.

Example:

```bash
az role assignment create \
  --assignee "<azure-client-id>" \
  --role "Storage Blob Data Contributor" \
  --scope "<tfstate-storage-account-id>/blobServices/default/containers/tfstate"
```

### Interview Takeaway

I diagnosed a Terraform backend 403 by distinguishing Azure management-plane RBAC from Storage Blob data-plane RBAC, then assigned `Storage Blob Data Contributor` at the container scope.

---

## Issue 7 — GitHub Actions Service Principal Cannot Create AKS in Region

### Symptoms

GitHub Actions could authenticate, read the backend, create the Resource Group and create ACR, but failed when creating AKS:

```text
RequestDisallowedByAzure
The selected region is currently not accepting new customers
locationineligible
```

The same Terraform apply worked from the Mac with the interactive Azure user.

### Root Cause

The practical conclusion:

```text
Local Azure user can create AKS in the selected region.
GitHub Actions OIDC service principal is blocked by Azure region/subscription policy for AKS creation.
```

### Resolution / Workaround

```text
Infrastructure creation: local Terraform apply from the Mac.
Application deployment: GitHub Actions workflow with apply_infra=false.
```

### Interview Takeaway

I compared Terraform apply from GitHub Actions and from a local Azure user session. This isolated the issue to Azure policy evaluation for the service principal, not the Terraform code itself.

---

## Issue 8 — Grafana Port-Forward Connection Refused

### Symptoms

```text
failed to connect to localhost:3000 inside namespace
connect: connection refused
error: lost connection to pod
```

### Root Cause

Grafana was not ready yet, or the service endpoint selected a pod before the container was ready.

### Resolution

```bash
kubectl get pods -n monitoring -o wide
kubectl rollout status deployment/monitoring-grafana -n monitoring --timeout=180s
kubectl get svc -n monitoring
kubectl get endpoints -n monitoring monitoring-grafana
```

Then retry:

```bash
kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring
```

### Interview Takeaway

I diagnosed the Grafana access issue by validating pod readiness, service endpoints and rollout state before retrying port-forward.

---

## Issue 9 — FastAPI `/metrics` Returned 404 After Code Change

### Symptoms

The source code contained `/metrics`, but the deployed API returned:

```text
{"detail":"Not Found"}
```

### Root Cause

The running AKS pod was still using an older image without the `/metrics` endpoint.

### Resolution

Push a unique image tag and update the deployment:

```bash
docker buildx build \
  --platform linux/amd64 \
  -t <acr-login-server>/customer-orders-api:metrics-v1 \
  ./containerized-app \
  --push
```

```bash
kubectl set image deployment/customer-orders-api \
  customer-orders-api=<acr-login-server>/customer-orders-api:metrics-v1 \
  -n customer-orders

kubectl rollout status deployment/customer-orders-api -n customer-orders
```

Validate:

```bash
curl http://localhost:8000/metrics | grep customer_orders
```

Expected:

```text
customer_orders_http_requests_total
customer_orders_http_request_duration_seconds
customer_orders_failed_orders_total
```

### Interview Takeaway

I diagnosed a mismatch between source code and running container image, then used a unique image tag and rollout validation to confirm that the application metrics endpoint was deployed correctly.

---

## Final Validation Commands

Application:

```bash
kubectl get pods -n customer-orders
kubectl get pvc -n customer-orders
kubectl get svc -n customer-orders
kubectl port-forward svc/customer-orders-api 8000:80 -n customer-orders
```

API validation:

```bash
curl http://localhost:8000/health
curl http://localhost:8000/api/customers
curl http://localhost:8000/api/orders
curl http://localhost:8000/api/orders/failed
curl http://localhost:8000/metrics | grep customer_orders
```

Monitoring:

```bash
kubectl get pods -n monitoring
kubectl get svc -n monitoring
kubectl get servicemonitor -n customer-orders
```

Prometheus:

```promql
up{namespace="customer-orders"}
customer_orders_http_requests_total
customer_orders_http_request_duration_seconds_count
customer_orders_failed_orders_total
```

---

## Summary of Fixes

| Issue | Root cause | Fix |
|---|---|---|
| AKS region / SKU failures | Azure for Students region, SKU and quota restrictions | Use `austriaeast` and `Standard_B2s_v2` |
| Wrong Kubernetes context | Azure overlay applied while still targeting kind | Fetch AKS credentials and validate context |
| ACR image pull failure | Kubelet identity permission and image architecture | Assign `AcrPull` and rebuild `linux/amd64` |
| PostgreSQL CrashLoopBackOff | `lost+found` in mounted PersistentVolume | Set `PGDATA` to a subdirectory and recreate PVC |
| Terraform OIDC auth error | Terraform not configured for service principal OIDC | Set `ARM_USE_OIDC` and related `ARM_*` variables |
| Terraform backend 403 | Missing Storage Blob data-plane permission | Assign `Storage Blob Data Contributor` on state container |
| GitHub Actions AKS creation blocked | Service principal blocked by Azure policy for AKS region | Create infra locally, run workflow with `apply_infra=false` |
| Grafana port-forward refused | Pod/service not ready yet | Validate rollout/endpoints and retry |
| `/metrics` returned 404 | Running pod used older image | Push unique image tag and rollout deployment |

---

## References

- AKS quotas, SKUs and regions: https://learn.microsoft.com/en-us/azure/aks/quotas-skus-regions
- AKS and ACR integration: https://learn.microsoft.com/en-us/azure/aks/cluster-container-registry-integration
- ACR authentication options for Kubernetes: https://learn.microsoft.com/en-us/azure/container-registry/authenticate-kubernetes-options
- Kubernetes images and ImagePullBackOff: https://kubernetes.io/docs/concepts/containers/images/
- Terraform azurerm backend: https://developer.hashicorp.com/terraform/language/backend/azurerm
- kube-prometheus-stack Helm chart: https://artifacthub.io/packages/helm/prometheus-community/kube-prometheus-stack
- PostgreSQL Docker image issue about `lost+found`: https://github.com/docker-library/postgres/issues/1163
