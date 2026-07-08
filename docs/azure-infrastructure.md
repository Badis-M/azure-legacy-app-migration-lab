# Azure Infrastructure

This document describes the Azure infrastructure used by the lab.

Infrastructure is provisioned with Terraform and designed to be small, reproducible and destroyable.

---

## Provisioned Resources

Terraform provisions:

- Azure Resource Group;
- Azure Container Registry Basic;
- Azure Kubernetes Service;
- AKS system node pool;
- AKS managed identity;
- AKS kubelet identity integration with ACR;
- tags for ownership and cost tracking.

The remote Terraform state backend is created separately.

---

## Remote Terraform State

Terraform state is stored in Azure Blob Storage.

The backend is intentionally separate from the application infrastructure. This prevents normal `terraform destroy` operations from deleting the state backend.

Public documentation uses placeholders for exact resource names:

```text
Resource Group:  <tfstate-resource-group>
Storage Account: <tfstate-storage-account>
Container:       tfstate
State key:       azure-legacy-migration-lab/dev.tfstate
```

Bootstrap the backend if needed:

```bash
make tf-backend-bootstrap
```

This command is not part of the normal daily workflow.

---

## Terraform Workflow

```bash
make tf-fmt
make tf-validate
make tf-plan
make tf-apply
make tf-destroy
make infra-down
make cost-check
```

---

## AKS Configuration

The working lab configuration uses:

```hcl
location         = "francecentral"
aks_location     = "austriaeast"
aks_node_vm_size = "Standard_B2s_v2"
```

The Resource Group and ACR are kept in France Central. AKS is deployed in Austria East because of Azure for Students region, SKU and quota constraints encountered during provisioning.

---

## ACR Integration

AKS pulls the private application image from Azure Container Registry.

The important identity is the AKS kubelet identity.

Validation command:

```bash
az aks show   --resource-group <app-resource-group>   --name <aks-cluster-name>   --query "identityProfile.kubeletidentity"
```

The kubelet identity needs `AcrPull` on the ACR scope.

```bash
ACR_ID=$(az acr show --name <acr-name> --query id -o tsv)

KUBELET_OBJECT_ID=$(az aks show   --resource-group <app-resource-group>   --name <aks-cluster-name>   --query "identityProfile.kubeletidentity.objectId"   -o tsv)

az role assignment create   --assignee-object-id "$KUBELET_OBJECT_ID"   --assignee-principal-type ServicePrincipal   --role AcrPull   --scope "$ACR_ID"
```

---

## Terraform Authentication in GitHub Actions

The manual deployment workflow uses GitHub Actions OIDC.

Terraform requires explicit environment variables for OIDC authentication:

```text
ARM_USE_OIDC=true
ARM_USE_AZUREAD=true
ARM_CLIENT_ID=<azure-client-id>
ARM_TENANT_ID=<azure-tenant-id>
ARM_SUBSCRIPTION_ID=<azure-subscription-id>
```

The Terraform `azurerm` backend also needs data-plane access to the storage container used for state.

Required role:

```text
Storage Blob Data Contributor
```

Recommended scope:

```text
<tfstate-storage-account>/blobServices/default/containers/tfstate
```

---

## Region and Quota Notes

Initial AKS attempts can fail even when Terraform syntax is correct.

Possible Azure-side errors:

```text
VMSizeNotSupported
ErrCode_InsufficientVCPUQuota
RequestDisallowedByAzure
```

These errors are caused by subscription, region, SKU or quota constraints.

---

## References

- AKS quotas, SKUs and regions: https://learn.microsoft.com/en-us/azure/aks/quotas-skus-regions
- AKS and ACR integration: https://learn.microsoft.com/en-us/azure/aks/cluster-container-registry-integration
- Terraform azurerm backend: https://developer.hashicorp.com/terraform/language/backend/azurerm
