# Migration Plan

This document describes the migration path followed by the lab.

The objective is to modernize a legacy-style FastAPI application into a reproducible, cost-aware and operationally documented Azure Kubernetes deployment.

---

## Objective

Migrate a small legacy-style application to a modern Azure Kubernetes platform while keeping the process reproducible, containerized, infrastructure-as-code driven, secure enough for CI/CD, observable in future phases, cost-aware and documented.

---

## Migration Phases

| Phase | Status | Description |
|---|---:|---|
| 1. Legacy application baseline | Done | Start from a simple FastAPI application. |
| 2. Containerization | Done | Package the application with Docker. |
| 3. Local multi-container runtime | Done | Run FastAPI and PostgreSQL with Docker Compose. |
| 4. Local Kubernetes | Done | Deploy the stack to kind. |
| 5. Kustomize overlays | Done | Separate base manifests from local/Azure overlays. |
| 6. Terraform foundation | Done | Provision Azure Resource Group, ACR and AKS. |
| 7. Remote Terraform state | Done | Store state in Azure Blob Storage. |
| 8. AKS deployment | Done | Deploy the Azure overlay to AKS. |
| 9. Operational troubleshooting | Done | Document AKS, ACR, image and PVC issues. |
| 10. CI validation | Done | Validate Terraform, Docker, Kustomize and YAML. |
| 11. GitHub Actions OIDC | Done | Authenticate to Azure without client secrets. |
| 12. Manual AKS deployment workflow | In progress | Automate apply, image push, deploy and validation. |
| 13. Observability | Planned | Add Prometheus and Grafana. |
| 14. Secret management | Planned | Move credentials toward Azure Key Vault integration. |
| 15. GitOps | Optional | Add Argo CD if the core platform remains manageable. |
| 16. Event-driven extension | Optional | Add Kafka only after observability is in place. |

---

## Success Criteria

A migration phase is successful when the application runs in the target environment, deployment commands are reproducible, validation commands are documented, cleanup is documented, known risks are captured, and costs can be controlled.

For AKS, success is defined by:

```text
customer-orders-api   1/1   Running
postgres-0            1/1   Running
AKS node              Ready
PostgreSQL PVC        Bound
```

---

## Future Direction

Recommended order:

```text
1. Stabilize manual AKS deployment workflow
2. Add Prometheus/Grafana
3. Add application metrics endpoint if needed
4. Add dashboards
5. Add alerting examples
6. Add runbooks
7. Consider Kafka/event-driven extension
```

Kafka is intentionally deferred because it increases operational complexity. Observability should come first so that additional platform components can be monitored properly.
