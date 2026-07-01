# Azure Legacy App Migration Lab

Educational cloud migration lab showing how to modernize a legacy application into an Azure AKS platform using containers, Terraform/OpenTofu, GitOps, observability, security controls, and FinOps practices.

## Project Goal

This repository demonstrates a realistic application migration journey:

1. Start from a legacy-style application.
2. Containerize it with Docker.
3. Run it locally with Docker Compose.
4. Deploy it to a local Kubernetes cluster.
5. Migrate it to Azure AKS.
6. Add GitOps with Argo CD.
7. Add observability with Prometheus, Grafana, and logging.
8. Document runbooks, RCA examples, and FinOps controls.

## Why This Project Exists

The goal is to demonstrate practical DevOps, Cloud, Kubernetes, security, and operational maturity through a realistic migration scenario.

This project is intentionally cost-aware. Azure resources are created only when needed and must be destroyed after each lab session.

## Target Stack

- Azure
- AKS
- Azure Container Registry
- Terraform / OpenTofu
- Docker
- Kubernetes
- Argo CD
- Prometheus
- Grafana
- ELK or lightweight logging alternative
- PostgreSQL
- Redis
- RabbitMQ
- GitHub Actions or GitLab CI

## Repository Structure

```text
legacy-app/             Legacy-style application before modernization
containerized-app/      Dockerized version of the application
infra/terraform/        Azure infrastructure as code
platform/               GitOps, monitoring, logging platform components
k8s/                    Kubernetes manifests and overlays
docs/                   Architecture, migration plan, runbooks, RCA, FinOps
scripts/                Utility scripts
.github/workflows/      CI workflows
```

## FinOps Rules

- Use minimal Azure SKUs.
- Tag every Azure resource.
- Prefer local labs before cloud deployment.
- Destroy Azure infrastructure after each session.
- Never commit secrets, credentials, kubeconfigs, or tfstate files.

## Current Status

Initial repository scaffold.
