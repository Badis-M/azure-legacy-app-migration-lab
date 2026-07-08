# CI/CD

This document describes the GitHub Actions workflows used by the project.

The project currently uses CI/CD conservatively. The goal is to validate quality and enable manual deployment without spending too much time building a complex pipeline before observability is in place.

---

## Workflows

```text
.github/workflows/ci.yml
.github/workflows/azure-oidc-check.yml
.github/workflows/deploy-aks.yml
```

---

## CI Validation Workflow

File:

```text
.github/workflows/ci.yml
```

Triggers:

```text
push to main
pull_request
workflow_dispatch
```

Purpose:

```text
Validate repository quality without creating Azure resources.
```

Checks:

- Terraform formatting;
- Terraform initialization without backend;
- Terraform validation;
- Docker image build;
- Docker Buildx `linux/amd64` image build;
- local Kustomize overlay render;
- Azure Kustomize overlay render;
- YAML linting.

Important choice:

```bash
terraform init -backend=false
```

This validates Terraform syntax and module structure without requiring access to the remote Azure Blob Storage backend.

---

## Azure OIDC Check Workflow

File:

```text
.github/workflows/azure-oidc-check.yml
```

Trigger:

```text
workflow_dispatch
```

Purpose:

```text
Validate that GitHub Actions can authenticate to Azure using OIDC.
```

Required permissions:

```yaml
permissions:
  id-token: write
  contents: read
```

---

## Manual AKS Deployment Workflow

File:

```text
.github/workflows/deploy-aks.yml
```

Trigger:

```text
workflow_dispatch
```

Purpose:

```text
Manually deploy the application to AKS.
```

Inputs:

```text
apply_infra
destroy_after
```

### `apply_infra`

When true, the workflow runs:

```bash
terraform apply -auto-approve
```

### `destroy_after`

When true, the workflow runs:

```bash
terraform destroy -auto-approve
```

after deployment validation.

---

## Manual Deployment Flow

```text
checkout repository
→ setup Terraform
→ setup kubectl
→ setup Docker Buildx
→ Azure login with OIDC
→ terraform init
→ terraform validate
→ optional terraform apply
→ read Terraform outputs
→ get AKS credentials
→ ACR login
→ build and push linux/amd64 image
→ render Azure Kustomize overlay
→ apply manifests
→ wait for PostgreSQL rollout
→ wait for API rollout
→ show Kubernetes status
→ optional terraform destroy
```

---

## Terraform OIDC Variables

Required environment variables:

```text
ARM_USE_OIDC=true
ARM_USE_AZUREAD=true
ARM_CLIENT_ID=${{ vars.AZURE_CLIENT_ID }}
ARM_TENANT_ID=${{ vars.AZURE_TENANT_ID }}
ARM_SUBSCRIPTION_ID=${{ vars.AZURE_SUBSCRIPTION_ID }}
```

Without these variables, Terraform may try to use the Azure CLI session as a user login and fail because the workflow is authenticated as a service principal through OIDC.

---

## Current Limitations

- no separate staging/prod environments;
- no deployment approval gate yet;
- no smoke-test job using an in-cluster test pod yet;
- cleanup is basic and may not run if the job fails before the destroy step;
- broad Contributor RBAC is used for now and should be reduced later.

---

## Next CI/CD Improvements

```text
1. Stabilize deploy-aks.yml
2. Add a smoke test after rollout
3. Add if: always() cleanup for destroy_after
4. Add GitHub Environment protection for manual approval
5. Reduce Azure RBAC scope
6. Add CI badge to README
```

Do not over-invest in CI/CD before adding observability. Prometheus and Grafana will provide more visible platform value for the next project phase.
