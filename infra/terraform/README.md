# Terraform Infrastructure

This folder contains the Terraform configuration for the Azure foundation of the migration lab.

## Current Scope

Terraform currently provisions the application foundation:

- Azure Resource Group
- Azure Container Registry Basic
- Common FinOps tags

It also uses a remote state backend stored in Azure Blob Storage.

## Current Structure

```text
infra/terraform/
├── main.tf
├── providers.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars.example
└── modules/
    ├── resource-group/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── acr/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

## Why Modules

The configuration is split into reusable modules:

```text
modules/resource-group
→ creates the Azure Resource Group

modules/acr
→ creates the Azure Container Registry
```

The root configuration composes those modules for the current environment.

This keeps the infrastructure code easier to read, extend, and reuse when AKS and other services are added later.

## Remote State Backend

Terraform state is stored in Azure Blob Storage.

Backend configuration:

```hcl
backend "azurerm" {
  resource_group_name  = "rg-tfstate-azure-migration-lab-dev"
  storage_account_name = "sttfstatebadisazmig001"
  container_name       = "tfstate"
  key                  = "azure-legacy-migration-lab/dev.tfstate"
  use_azuread_auth     = true
}
```

The backend contains the Terraform state file:

```text
azure-legacy-migration-lab/dev.tfstate
```

## Backend Separation

The remote state backend is intentionally created separately from the main application infrastructure.

Application infrastructure:

```text
rg-azure-legacy-migration-lab-dev
└── acrazlegacydev001
```

Terraform backend infrastructure:

```text
rg-tfstate-azure-migration-lab-dev
└── sttfstatebadisazmig001
    └── container: tfstate
        └── azure-legacy-migration-lab/dev.tfstate
```

This means:

```text
terraform destroy
→ destroys resources managed by the main Terraform state

terraform destroy
→ does not destroy the backend Storage Account
```

This avoids Terraform destroying the storage that contains its own state.

## Backend Bootstrap Script

The backend is created by:

```text
scripts/bootstrap-tfstate-backend.sh
```

This script creates or verifies:

- Terraform state Resource Group
- Storage Account
- Blob container
- RBAC role assignment for Blob access

It is mainly used for:

- First-time project setup
- Recreating the backend if deleted manually
- Documenting backend creation as executable infrastructure setup

Run it from the repository root:

```bash
make tf-backend-bootstrap
```

This command is not part of the normal daily workflow.

## Required Local File

Create a local `terraform.tfvars` file from the example:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit values as needed:

```hcl
location     = "francecentral"
project_name = "azure-legacy-migration-lab"
environment  = "dev"
owner        = "your-name"
acr_name     = "replacewithuniqueacrname001"
```

The real `terraform.tfvars` file must not be committed.

## Common Commands

From the repository root:

```bash
make tf-fmt
make tf-validate
make tf-plan
make tf-apply
make tf-destroy
```

Or from this folder:

```bash
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
terraform destroy
```

## Expected Current Outputs

```text
resource_group_name = "rg-azure-legacy-migration-lab-dev"
acr_name            = "acrazlegacydev001"
acr_login_server    = "acrazlegacydev001.azurecr.io"
```

## Verify Azure Resources

```bash
terraform output
```

```bash
az acr list \
  --resource-group "$(terraform output -raw resource_group_name)" \
  --output table
```

## Verify Remote State Blob

```bash
az storage blob list \
  --account-name sttfstatebadisazmig001 \
  --container-name tfstate \
  --auth-mode login \
  --output table
```

Expected blob:

```text
azure-legacy-migration-lab/dev.tfstate
```

## Provider Registration

The AzureRM provider is configured with:

```hcl
resource_provider_registrations = "none"
```

This avoids broad automatic registration of many Azure resource providers.

Only required providers are registered when needed. For the current scope, Azure Container Registry is the main required provider.

## Security Notes

The current Terraform configuration does not store Azure credentials in code.

Authentication is handled through Azure CLI:

```bash
az login
```

The backend uses Azure AD authentication:

```hcl
use_azuread_auth = true
```

The remote state may still contain sensitive data in future phases. Access to the backend Storage Account should remain restricted.

## Cost Notes

Current managed resources are lightweight:

- Azure Resource Group
- Azure Container Registry Basic
- Separate Storage Account for Terraform state

The state Storage Account cost is expected to be very low because the state file is small, but it still exists until manually removed.

AKS has not been created yet.

## Next Steps

Planned Terraform additions:

```text
modules/aks/
→ minimal AKS cluster

ACR pull integration
→ managed identity + AcrPull role assignment

networking
→ controlled AKS networking

cost guardrails
→ one node, controlled VM size, no unnecessary public services
```

## Interview Summary

```text
I structured Terraform with reusable modules, separated application infrastructure from backend state infrastructure, and migrated the state to Azure Blob Storage using Azure AD authentication and Blob locking.
```
