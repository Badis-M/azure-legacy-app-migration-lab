# GitHub Actions OIDC for Azure

This document explains the GitHub Actions to Azure OIDC setup used by the project.

The goal is to allow GitHub Actions to authenticate to Azure without storing a long-lived Azure client secret in GitHub.

---

## Why OIDC

Traditional CI/CD authentication often uses a service principal client secret.

This project avoids that pattern.

Instead, GitHub Actions requests a short-lived OIDC token, and Azure validates that token through a federated credential on a Microsoft Entra application.

```text
GitHub Actions workflow
→ GitHub OIDC token
→ Microsoft Entra federated credential
→ Azure service principal
→ Azure RBAC
→ Azure CLI / Terraform
```

Benefits:

- no long-lived Azure client secret in GitHub;
- token is short-lived;
- trust can be limited to a specific repository and branch;
- works with Azure CLI and Terraform when configured correctly.

---

## Azure Objects

The setup uses:

```text
Microsoft Entra application
Service principal
Federated identity credential
Azure RBAC role assignments
GitHub repository variables
```

---

## Federated Credential

The federated credential restricts which GitHub workflow identity can authenticate.

Example subject:

```text
repo:<github-owner>/<github-repo>:ref:refs/heads/main
```

For this lab:

```text
repo:Badis-M/azure-legacy-app-migration-lab:ref:refs/heads/main
```

If the subject is wrong, Azure login fails.

A common mistake is creating the credential before setting `GITHUB_OWNER` and `GITHUB_REPO`, which can produce:

```text
repo:/:ref:refs/heads/main
```

That value will not match the repository and must be deleted and recreated.

---

## GitHub Repository Variables

The workflow uses repository variables, not secrets:

```text
AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID
ACR_NAME
```

These are identifiers, not passwords.

No `AZURE_CLIENT_SECRET` is used.

---

## Workflow Permissions

```yaml
permissions:
  id-token: write
  contents: read
```

`id-token: write` allows GitHub Actions to request the OIDC token.

---

## Azure Login Step

```yaml
- name: Azure login with OIDC
  uses: azure/login@v2
  with:
    client-id: ${{ vars.AZURE_CLIENT_ID }}
    tenant-id: ${{ vars.AZURE_TENANT_ID }}
    subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}
```

This authenticates Azure CLI commands such as:

```bash
az account show
az group list
az aks get-credentials
az acr login
```

---

## Terraform OIDC Authentication

Terraform needs explicit environment variables:

```yaml
env:
  ARM_USE_OIDC: true
  ARM_USE_AZUREAD: true
  ARM_CLIENT_ID: ${{ vars.AZURE_CLIENT_ID }}
  ARM_TENANT_ID: ${{ vars.AZURE_TENANT_ID }}
  ARM_SUBSCRIPTION_ID: ${{ vars.AZURE_SUBSCRIPTION_ID }}
```

Without this, Terraform can fail with:

```text
Error building ARM Config:
Authenticating using the Azure CLI is only supported as a User
not a Service Principal.
```

---

## Terraform Backend Permissions

The Terraform `azurerm` backend reads and writes state in Azure Blob Storage.

The service principal needs data-plane permissions.

Required role:

```text
Storage Blob Data Contributor
```

Recommended scope:

```text
<storage-account-id>/blobServices/default/containers/tfstate
```

If missing, `terraform init` can fail with:

```text
StatusCode=403
AuthorizationPermissionMismatch
Failed to get existing workspaces: containers.Client#ListBlobs
```

---

## RBAC Used During the Lab

Current pragmatic setup:

```text
Contributor on the lab subscription
Storage Blob Data Contributor on the Terraform state container
```

This is intentionally broad for the first working deployment workflow.

Future improvement:

```text
Reduce Contributor to narrower scopes and roles once the workflow is stable.
```

---

## Validation Workflow

File:

```text
.github/workflows/azure-oidc-check.yml
```

Purpose:

```text
Validate Azure login only. Do not create infrastructure.
```

Typical validation commands:

```bash
az account show
az group list
```

---

## Common Errors

| Error | Likely cause | Fix |
|---|---|---|
| Subject claim mismatch | Wrong federated credential subject | Recreate credential with `repo:<owner>/<repo>:ref:refs/heads/main` |
| OIDC token unavailable | Missing `id-token: write` | Add workflow permission |
| Terraform Azure CLI auth error | Terraform not configured for OIDC | Set `ARM_USE_OIDC` and related variables |
| Backend `AuthorizationPermissionMismatch` | Missing blob data-plane RBAC | Assign `Storage Blob Data Contributor` on state container |

---

## References

- GitHub OIDC with Azure: https://docs.github.com/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure
- Azure Login with OIDC: https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure-openid-connect
- Terraform azurerm backend: https://developer.hashicorp.com/terraform/language/backend/azurerm
