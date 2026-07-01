# AKS Azure Troubleshooting Notes

This document captures the main issues encountered while deploying the `customer-orders` application to Azure Kubernetes Service (AKS), and how each issue was investigated and fixed.

The purpose of this document is to show the operational troubleshooting path, not only the final happy path.

---

## Final validated state

The deployment was considered successful once the following checks passed:

```bash
kubectl get pods -n customer-orders
kubectl get nodes -o wide
kubectl get pvc -n customer-orders
```

Final observed state:

```text
NAME                                   READY   STATUS    RESTARTS   AGE
customer-orders-api-58879fd869-zdgq7   1/1     Running   0          5m1s
postgres-0                             1/1     Running   0          2m8s

NAME                             STATUS   ROLES    AGE   VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION     CONTAINER-RUNTIME
aks-system-06526520-vmss000000   Ready    <none>   57m   v1.35.5   10.224.0.4    <none>        Ubuntu 24.04.4 LTS   6.8.0-1059-azure   containerd://2.2.4-2

NAME                       STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
postgres-data-postgres-0   Bound    pvc-8660dd9e-0f59-4ca3-bd2b-165e5a3b67d9   1Gi        RWO            default        2m9s
```

---

## Architecture context

The lab deploys a small cloud migration platform on Azure:

- FastAPI application containerized with Docker
- Azure Container Registry (ACR) for private image storage
- Azure Kubernetes Service (AKS) for cloud Kubernetes deployment
- PostgreSQL deployed as a Kubernetes StatefulSet
- Kubernetes manifests managed with Kustomize overlays
- Terraform-managed Azure infrastructure
- Cost-controlled single-node AKS deployment

Main Azure resources:

```text
Resource Group: rg-azure-legacy-migration-lab-dev
ACR:            acrazlegacydev001
AKS:            aks-azure-legacy-migration-dev
AKS location:   austriaeast
Namespace:      customer-orders
```

---

## Issue 1 — Azure subscription, region and VM SKU constraints

### Symptoms

Several AKS creation attempts failed before the application was deployed.

Examples of errors encountered:

```text
VMSizeNotSupported
The requested VM size is not supported for this subscription in this location.
```

```text
ErrCode_InsufficientVCPUQuota
Insufficient vcpu quota requested 2, remaining 0 for family ...
```

```text
RequestDisallowedByAzure
The selected region is currently not accepting new customers.
```

### Investigation

The issue was not Terraform syntax. The failures came from Azure-side subscription, region, SKU and quota constraints.

Observed results:

| Region | Result |
|---|---|
| `francecentral` | Region accepted, but low-cost VM sizes were unavailable or rejected. Some available VM families had 0 vCPU quota. |
| `westeurope` | Some VM sizes appeared available in the portal, but AKS creation was blocked by regional policy. |
| `northeurope` | Blocked by subscription or regional policy. |
| `austriaeast` | Region accepted, but only specific VM sizes were usable. |

### Root cause

The Azure for Students subscription had restricted access to regions, VM families and vCPU quotas.

A VM size being visible in Azure tooling does not guarantee that it can be used by AKS for a specific subscription, region and quota state.

AKS provisioning depends on:

- AKS regional availability
- Subscription-level region policies
- VM SKU availability
- Regional vCPU quota
- VM-family vCPU quota
- Real-time regional capacity

### Resolution

The working configuration was:

```hcl
location         = "francecentral"
aks_location     = "austriaeast"
aks_node_vm_size = "Standard_B2s_v2"
```

The Resource Group and ACR stayed in France Central, while the AKS cluster was created in Austria East.

The cluster was created with Terraform:

```bash
make tf-apply
```

Then credentials were retrieved:

```bash
az aks get-credentials \
  --resource-group rg-azure-legacy-migration-lab-dev \
  --name aks-azure-legacy-migration-dev \
  --overwrite-existing
```

Validation:

```bash
kubectl get nodes -o wide
```

Result:

```text
aks-system-06526520-vmss000000   Ready   v1.35.5
```

### Lessons learned

For restricted or student subscriptions, AKS region and VM size selection must be treated as part of infrastructure design.

Useful validation command:

```bash
az aks show \
  --resource-group rg-azure-legacy-migration-lab-dev \
  --name aks-azure-legacy-migration-dev \
  --query "{state:provisioningState, power:powerState.code, location:location, fqdn:fqdn}" \
  --output table
```

### Interview takeaway

I had to troubleshoot Azure subscription-level constraints before reaching the Kubernetes layer. The issue involved regional policy, VM SKU restrictions and vCPU quotas. I kept the Terraform configuration explicit and adjusted the AKS location and node size based on actual provisioning feedback.

---

## Issue 2 — Wrong Kubernetes context during deployment

### Symptoms

After applying the Azure Kubernetes overlay, the pod appeared to fail with `ImagePullBackOff`, but the terminal prompt showed the current context was still:

```text
kind-azure-migration-lab
```

This meant `kubectl` was still pointing to the local kind cluster instead of AKS.

### Root cause

Azure manifests were applied while the active kubeconfig context was still the local kind cluster.

The Azure overlay referenced the private ACR image:

```text
acrazlegacydev001.azurecr.io/customer-orders-api:dev
```

The local kind cluster had no credentials to pull from ACR, so the local pod failed.

### Resolution

The AKS credentials were retrieved and merged into kubeconfig:

```bash
az aks get-credentials \
  --resource-group rg-azure-legacy-migration-lab-dev \
  --name aks-azure-legacy-migration-dev \
  --overwrite-existing
```

Then the active context and node type were validated:

```bash
kubectl config current-context
kubectl get nodes -o wide
```

Expected context:

```text
aks-azure-legacy-migration-dev
```

Expected node name pattern:

```text
aks-system-...
```

### Lessons learned

Before applying cloud Kubernetes manifests, always verify the current context:

```bash
kubectl config current-context
kubectl get nodes -o wide
```

### Interview takeaway

I caught a deployment-context issue where the Azure overlay had initially been applied to the local kind cluster. I corrected it by validating kubeconfig context before applying cloud manifests.

---

## Issue 3 — AKS could not pull the private image from ACR

### Symptoms

The API pod was scheduled on the AKS node but could not pull the image from Azure Container Registry.

Pod status:

```text
ErrImagePull
ImagePullBackOff
```

The pod events showed:

```text
failed to authorize
failed to fetch anonymous token
401 Unauthorized
```

There was also a platform-related message:

```text
no match for platform in manifest
```

### Investigation

The image tag existed in ACR:

```bash
az acr repository show-tags \
  --name acrazlegacydev001 \
  --repository customer-orders-api \
  --output table
```

Result:

```text
dev
```

The ACR role assignment was checked:

```bash
ACR_ID=$(az acr show --name acrazlegacydev001 --query id -o tsv)

az role assignment list \
  --scope "$ACR_ID" \
  --role AcrPull \
  --output table
```

The AKS kubelet identity was checked:

```bash
KUBELET_OBJECT_ID=$(az aks show \
  --resource-group rg-azure-legacy-migration-lab-dev \
  --name aks-azure-legacy-migration-dev \
  --query "identityProfile.kubeletidentity.objectId" \
  -o tsv)

echo "$KUBELET_OBJECT_ID"
```

The important distinction was:

```text
kubeletidentity.clientId != kubeletidentity.objectId
```

Observed values:

```text
kubeletidentity.objectId: af8e9517-7e49-4854-b656-7479cbd62d09
kubeletidentity.clientId: b5510f14-bc4d-4539-b092-48f58ae8a735
```

### Root cause

There were two contributing factors:

1. The AKS kubelet identity needed an explicit `AcrPull` role assignment at the ACR scope.
2. The image had initially been built from macOS/ARM without ensuring compatibility with the AKS node architecture.

### Resolution

An explicit `AcrPull` role assignment was created for the kubelet identity object ID:

```bash
ACR_ID=$(az acr show --name acrazlegacydev001 --query id -o tsv)

KUBELET_OBJECT_ID=$(az aks show \
  --resource-group rg-azure-legacy-migration-lab-dev \
  --name aks-azure-legacy-migration-dev \
  --query "identityProfile.kubeletidentity.objectId" \
  -o tsv)

az role assignment create \
  --assignee-object-id "$KUBELET_OBJECT_ID" \
  --assignee-principal-type ServicePrincipal \
  --role AcrPull \
  --scope "$ACR_ID"
```

Then the image was rebuilt and pushed explicitly for the AKS node platform:

```bash
docker buildx build \
  --platform linux/amd64 \
  -t acrazlegacydev001.azurecr.io/customer-orders-api:dev \
  ./containerized-app \
  --push
```

The deployment was restarted:

```bash
kubectl rollout restart deployment/customer-orders-api -n customer-orders
kubectl get pods -n customer-orders
```

The API pod then became healthy:

```text
customer-orders-api-58879fd869-zdgq7   1/1   Running
```

### Lessons learned

When AKS fails to pull from ACR, check both identity and image architecture.

Useful commands:

```bash
kubectl describe pod <pod-name> -n customer-orders
```

```bash
az aks show \
  --resource-group rg-azure-legacy-migration-lab-dev \
  --name aks-azure-legacy-migration-dev \
  --query "identityProfile.kubeletidentity"
```

```bash
az role assignment list \
  --scope "$(az acr show --name acrazlegacydev001 --query id -o tsv)" \
  --role AcrPull \
  --output table
```

### Interview takeaway

The ACR issue required troubleshooting both cloud identity and container image architecture. I verified the kubelet managed identity, assigned `AcrPull` explicitly, rebuilt the image for `linux/amd64`, and validated the pod rollout.

---

## Issue 4 — PostgreSQL CrashLoopBackOff on AKS PersistentVolume

### Symptoms

The PostgreSQL pod was scheduled and the public image was pulled successfully, but the container crashed repeatedly.

Pod status:

```text
postgres-0   0/1   CrashLoopBackOff
```

`kubectl describe pod` showed only:

```text
Exit Code: 1
Back-off restarting failed container postgres
```

The useful information came from:

```bash
kubectl logs postgres-0 -n customer-orders --previous
```

Logs:

```text
initdb: error: directory "/var/lib/postgresql/data" exists but is not empty
initdb: detail: It contains a lost+found directory, perhaps due to it being a mount point.
initdb: hint: Using a mount point directly as the data directory is not recommended.
Create a subdirectory under the mount point.
```

### Root cause

The PostgreSQL container mounted the PersistentVolume directly at:

```text
/var/lib/postgresql/data
```

On AKS, the dynamically provisioned disk contained a filesystem-level `lost+found` directory. PostgreSQL refused to initialize the database directly in a non-empty directory.

This is a common issue when a database initializes directly at the root of a mounted filesystem.

### Resolution

The StatefulSet was updated to use a PostgreSQL data subdirectory with `PGDATA`.

In the PostgreSQL container spec:

```yaml
env:
  - name: PGDATA
    value: /var/lib/postgresql/data/pgdata
```

Final relevant container block:

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

Because the first initialization had already failed on the existing PVC, the StatefulSet and PVC were recreated:

```bash
kubectl delete statefulset postgres -n customer-orders
kubectl delete pvc postgres-data-postgres-0 -n customer-orders
make k8s-apply-azure
```

The pod then became healthy:

```text
postgres-0   1/1   Running
```

### Lessons learned

For database StatefulSets on Kubernetes, avoid using the mount point itself as the database data directory. Use a subdirectory inside the mounted volume.

This avoids initialization issues caused by filesystem-created directories such as `lost+found`.

### Interview takeaway

The PostgreSQL issue was diagnosed from container logs rather than pod events. I identified that AKS dynamically provisioned storage contained `lost+found`, updated the StatefulSet with `PGDATA`, recreated the failed PVC, and validated the database pod.

---

## Final validation commands

After applying all fixes:

```bash
kubectl get pods -n customer-orders
kubectl get nodes -o wide
kubectl get pvc -n customer-orders
```

Final result:

```text
customer-orders-api-58879fd869-zdgq7   1/1   Running
postgres-0                             1/1   Running

aks-system-06526520-vmss000000         Ready

postgres-data-postgres-0               Bound
```

Optional application test:

```bash
kubectl port-forward svc/customer-orders-api-service 8000:80 -n customer-orders
```

Then, from another terminal:

```bash
curl http://localhost:8000/health
curl http://localhost:8000/api/customers
curl http://localhost:8000/api/orders
```

---

## Summary of fixes

| Issue | Root cause | Fix |
|---|---|---|
| AKS region / SKU failures | Azure for Students region, SKU and quota restrictions | Use `austriaeast` and `Standard_B2s_v2` |
| Wrong Kubernetes context | Azure overlay applied while still targeting kind | Run `az aks get-credentials` and validate context |
| ACR image pull failure | Kubelet identity permission and image architecture | Assign `AcrPull` to kubelet object ID and rebuild `linux/amd64` |
| PostgreSQL CrashLoopBackOff | `lost+found` in mounted PersistentVolume | Set `PGDATA=/var/lib/postgresql/data/pgdata` and recreate PVC |

---

## References

- AKS quotas, SKUs and regions: https://learn.microsoft.com/en-us/azure/aks/quotas-skus-regions
- AKS and ACR integration: https://learn.microsoft.com/en-us/azure/aks/cluster-container-registry-integration
- ACR authentication options for Kubernetes: https://learn.microsoft.com/en-us/azure/container-registry/authenticate-kubernetes-options
- Kubernetes images and ImagePullBackOff: https://kubernetes.io/docs/concepts/containers/images/
- Kubernetes events: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_events/
- PostgreSQL Docker image issue about `lost+found`: https://github.com/docker-library/postgres/issues/1163
