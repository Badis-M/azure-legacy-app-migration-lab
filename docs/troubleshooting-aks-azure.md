# AKS Azure Troubleshooting Notes

> Public documentation uses placeholders for concrete Azure resource names. The troubleshooting flow, commands and root causes are preserved, but temporary personal cloud resource identifiers are not exposed.

This document captures the main issues encountered while deploying the `customer-orders` application to Azure Kubernetes Service.

The goal is to show the operational troubleshooting path, not only the final working state.

---

## Final Validated State

The deployment was considered successful once these checks passed:

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
- cost-controlled single-node AKS.

Main placeholders:

```text
Resource Group: <app-resource-group>
ACR:            <acr-name>
ACR login:      <acr-login-server>
AKS:            <aks-cluster-name>
Namespace:      customer-orders
```

---

## Issue 1 — Azure Subscription, Region and VM SKU Constraints

### Symptoms

AKS creation failed before application deployment.

Observed error patterns:

```text
VMSizeNotSupported
ErrCode_InsufficientVCPUQuota
RequestDisallowedByAzure
```

### Investigation

The Terraform configuration was valid. The failures came from Azure-side constraints:

- restricted Azure for Students subscription behavior;
- region restrictions;
- unavailable VM SKUs;
- family-level vCPU quota;
- real-time capacity constraints.

Observed pattern:

| Region | Result |
|---|---|
| `francecentral` | Accepted for Resource Group and ACR, but low-cost AKS VM sizes were unavailable or rejected. |
| `westeurope` | Some VM sizes appeared visible but AKS creation was blocked by policy. |
| `northeurope` | Blocked by subscription or regional policy. |
| `austriaeast` | Accepted with a usable VM size. |

### Root Cause

AKS provisioning depends on more than Terraform syntax:

- AKS regional availability;
- subscription-level policies;
- VM SKU availability;
- vCPU quota;
- VM family quota;
- regional capacity.

### Resolution

Working configuration:

```hcl
location         = "francecentral"
aks_location     = "austriaeast"
aks_node_vm_size = "Standard_B2s_v2"
```

The Resource Group and ACR stayed in France Central. AKS was deployed in Austria East.

Validation:

```bash
az aks get-credentials   --resource-group <app-resource-group>   --name <aks-cluster-name>   --overwrite-existing

kubectl get nodes -o wide
```

Expected:

```text
aks-system-xxxxxxxx-vmss000000   Ready
```

### Lesson

For restricted or student subscriptions, region and SKU selection are part of the infrastructure design.

### Interview Takeaway

I had to troubleshoot Azure subscription-level constraints before reaching the Kubernetes layer. The issue involved regional policy, VM SKU restrictions and vCPU quotas, not Terraform syntax.

---

## Issue 2 — Wrong Kubernetes Context

### Symptoms

The Azure overlay appeared to fail with `ImagePullBackOff`, but the terminal was still pointing to the local kind context.

Example context:

```text
kind-azure-migration-lab
```

### Root Cause

The Azure overlay was applied while `kubectl` was targeting the local kind cluster.

The Azure overlay referenced a private ACR image:

```text
<acr-login-server>/customer-orders-api:dev
```

The local kind cluster had no ACR pull credentials, so the pod failed.

### Resolution

Fetch AKS credentials:

```bash
az aks get-credentials   --resource-group <app-resource-group>   --name <aks-cluster-name>   --overwrite-existing
```

Validate context:

```bash
kubectl config current-context
kubectl get nodes -o wide
```

Expected context:

```text
<aks-cluster-name>
```

### Lesson

Always verify Kubernetes context before applying cloud manifests.

### Interview Takeaway

I caught a deployment-context issue where cloud manifests were initially applied to the local cluster. I corrected it by validating kubeconfig context and node type before redeploying.

---

## Issue 3 — AKS Could Not Pull Private Image from ACR

### Symptoms

API pod scheduled on AKS but could not pull the image.

Pod status:

```text
ErrImagePull
ImagePullBackOff
```

Events included:

```text
failed to authorize
failed to fetch anonymous token
401 Unauthorized
```

Another message indicated a possible architecture issue:

```text
no match for platform in manifest
```

### Investigation

Verify image exists:

```bash
az acr repository show-tags   --name <acr-name>   --repository customer-orders-api   --output table
```

Check kubelet identity:

```bash
az aks show   --resource-group <app-resource-group>   --name <aks-cluster-name>   --query "identityProfile.kubeletidentity"
```

Important distinction:

```text
kubeletidentity.clientId != kubeletidentity.objectId
```

For role assignment, use the object ID.

### Root Cause

Two issues contributed:

1. AKS kubelet identity needed explicit `AcrPull` on ACR.
2. The image had initially been built from macOS ARM without explicitly targeting AKS node architecture.

### Resolution

Assign `AcrPull` to kubelet identity object ID:

```bash
ACR_ID=$(az acr show --name <acr-name> --query id -o tsv)

KUBELET_OBJECT_ID=$(az aks show   --resource-group <app-resource-group>   --name <aks-cluster-name>   --query "identityProfile.kubeletidentity.objectId"   -o tsv)

az role assignment create   --assignee-object-id "$KUBELET_OBJECT_ID"   --assignee-principal-type ServicePrincipal   --role AcrPull   --scope "$ACR_ID"
```

Rebuild and push for AKS node platform:

```bash
docker buildx build   --platform linux/amd64   -t <acr-login-server>/customer-orders-api:dev   ./containerized-app   --push
```

Restart deployment:

```bash
kubectl rollout restart deployment/customer-orders-api -n customer-orders
kubectl get pods -n customer-orders
```

### Lesson

For ACR pull failures, check both cloud identity and container image architecture.

### Interview Takeaway

The ACR issue required troubleshooting both identity and image architecture. I verified the kubelet managed identity, assigned `AcrPull`, rebuilt the image for `linux/amd64`, and validated the rollout.

---

## Issue 4 — PostgreSQL CrashLoopBackOff on AKS PersistentVolume

### Symptoms

PostgreSQL pod started but crashed repeatedly.

Pod status:

```text
postgres-0   0/1   CrashLoopBackOff
```

The useful logs came from:

```bash
kubectl logs postgres-0 -n customer-orders --previous
```

Logs:

```text
initdb: error: directory "/var/lib/postgresql/data" exists but is not empty
initdb: detail: It contains a lost+found directory
initdb: hint: Using a mount point directly as the data directory is not recommended.
Create a subdirectory under the mount point.
```

### Root Cause

The PostgreSQL container mounted the PersistentVolume directly at:

```text
/var/lib/postgresql/data
```

On AKS, the provisioned disk contained a filesystem-level `lost+found` directory. PostgreSQL refused to initialize directly in a non-empty directory.

### Resolution

Set `PGDATA` to a subdirectory inside the mounted volume:

```yaml
env:
  - name: PGDATA
    value: /var/lib/postgresql/data/pgdata
```

Because the first initialization had already failed on the PVC, recreate the StatefulSet and PVC for this lab environment:

```bash
kubectl delete statefulset postgres -n customer-orders
kubectl delete pvc postgres-data-postgres-0 -n customer-orders
make k8s-apply-azure
```

Expected result:

```text
postgres-0   1/1   Running
```

### Lesson

For database StatefulSets, avoid using the mount point itself as the database data directory.

### Interview Takeaway

The PostgreSQL issue was diagnosed from container logs. I identified the `lost+found` mount-point problem, updated the StatefulSet with `PGDATA`, recreated the failed PVC and validated the database pod.

---

## Issue 5 — Terraform OIDC Authentication in GitHub Actions

### Symptoms

The Azure OIDC check workflow succeeded, but the manual deployment workflow failed at `terraform init`.

Error:

```text
Error building ARM Config:
Authenticating using the Azure CLI is only supported as a User
not a Service Principal.
```

### Root Cause

`azure/login` authenticated Azure CLI as a service principal through OIDC.

Terraform did not automatically use that authentication mode. It attempted to use Azure CLI authentication as if it were a user session.

### Resolution

Add Terraform OIDC environment variables to the workflow:

```yaml
env:
  ARM_USE_OIDC: true
  ARM_USE_AZUREAD: true
  ARM_CLIENT_ID: ${{ vars.AZURE_CLIENT_ID }}
  ARM_TENANT_ID: ${{ vars.AZURE_TENANT_ID }}
  ARM_SUBSCRIPTION_ID: ${{ vars.AZURE_SUBSCRIPTION_ID }}
```

### Lesson

Azure CLI OIDC login and Terraform OIDC provider/backend authentication are related but not identical. Terraform needs explicit `ARM_*` variables.

### Interview Takeaway

I validated GitHub Actions OIDC with Azure CLI, then adapted Terraform authentication to use explicit OIDC environment variables for non-interactive CI/CD deployment.

---

## Issue 6 — Terraform Backend 403 on Azure Blob Storage

### Symptoms

After configuring Terraform OIDC variables, `terraform init` reached the backend but failed with:

```text
StatusCode=403
AuthorizationPermissionMismatch
Failed to get existing workspaces: containers.Client#ListBlobs
```

### Root Cause

The service principal had management-plane access but lacked data-plane access to the Terraform state blob container.

`Contributor` can manage Azure resources, but reading and writing blobs requires a Storage Blob role.

### Resolution

Assign:

```text
Storage Blob Data Contributor
```

to the GitHub Actions service principal on the Terraform state container scope.

Example:

```bash
APP_ID="<azure-client-id>"
TFSTATE_STORAGE_ID="<tfstate-storage-account-resource-id>"
TFSTATE_CONTAINER_SCOPE="${TFSTATE_STORAGE_ID}/blobServices/default/containers/tfstate"

az role assignment create   --assignee "$APP_ID"   --role "Storage Blob Data Contributor"   --scope "$TFSTATE_CONTAINER_SCOPE"
```

Verify:

```bash
az role assignment list   --assignee "$APP_ID"   --scope "$TFSTATE_CONTAINER_SCOPE"   --query "[].{role:roleDefinitionName, principalType:principalType, scope:scope}"   -o table
```

Wait several minutes for RBAC propagation before retesting.

### Lesson

Terraform remote state on Azure Blob Storage needs data-plane permissions. Management-plane permissions alone are not enough.

### Interview Takeaway

I diagnosed a Terraform backend 403 by distinguishing Azure management-plane RBAC from Storage Blob data-plane RBAC, then assigned `Storage Blob Data Contributor` at the container scope.

---

## Final Validation Commands

```bash
kubectl get pods -n customer-orders
kubectl get nodes -o wide
kubectl get pvc -n customer-orders
kubectl get svc -n customer-orders
```

Optional API test:

```bash
kubectl port-forward svc/customer-orders-api 8000:80 -n customer-orders
```

Then:

```bash
curl http://localhost:8000/health
curl http://localhost:8000/api/customers
curl http://localhost:8000/api/orders
curl http://localhost:8000/api/orders/failed
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

---

## References

- AKS quotas, SKUs and regions: https://learn.microsoft.com/en-us/azure/aks/quotas-skus-regions
- AKS and ACR integration: https://learn.microsoft.com/en-us/azure/aks/cluster-container-registry-integration
- ACR authentication options for Kubernetes: https://learn.microsoft.com/en-us/azure/container-registry/authenticate-kubernetes-options
- Kubernetes images and ImagePullBackOff: https://kubernetes.io/docs/concepts/containers/images/
- Kubernetes events: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_events/
- Terraform azurerm backend: https://developer.hashicorp.com/terraform/language/backend/azurerm
- PostgreSQL Docker image issue about `lost+found`: https://github.com/docker-library/postgres/issues/1163
