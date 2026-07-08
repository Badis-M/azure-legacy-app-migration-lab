# FinOps Notes

This document captures cost-control principles for the lab.

The project is designed to be deployable, testable and destroyable.

---

## Cost Control Principles

- Start locally before using Azure.
- Use short-lived Azure environments.
- Prefer minimal SKUs.
- Use one AKS node only.
- Avoid public LoadBalancers by default.
- Use port-forward for validation.
- Avoid managed Grafana at first.
- Avoid Log Analytics at first.
- Apply tags to resources.
- Destroy resources after lab sessions.
- Verify remaining resources after destroy.

---

## Azure Resources Used

During a full AKS validation, the lab may use:

- one application Resource Group;
- one Basic Azure Container Registry;
- one AKS cluster;
- one AKS node;
- one dynamically provisioned PostgreSQL PersistentVolume;
- one separate Terraform state Resource Group;
- one Terraform state Storage Account;
- Azure Network Watcher created automatically by Azure.

---

## Resource Lifecycle

Every Azure deployment should include:

```text
1. Creation command
2. Validation command
3. Destruction command
4. Post-destroy resource check
5. Known cleanup risks
```

---

## Creation

```bash
make tf-apply
```

Or through the manual GitHub Actions workflow:

```text
Manual AKS Deployment
apply_infra = true
```

---

## Validation

```bash
make aks-credentials
make k8s-status
```

Additional Azure resource check:

```bash
az resource list   --resource-group <app-resource-group>   --output table
```

---

## Destruction

Preferred cleanup:

```bash
make infra-down
```

Terraform-only destroy:

```bash
make tf-destroy
```

---

## Post-Destroy Verification

```bash
make cost-check
```

Expected remaining resources after a clean destroy:

```text
Terraform remote state backend
Azure Network Watcher
```

The Terraform remote state backend is intentionally retained.

Network Watcher is automatically created by Azure for regional diagnostics and is normally harmless unless additional diagnostic features are enabled.

---

## Known Cleanup Risks

Potential resources to watch:

```text
AKS cluster
Virtual machine scale set
Managed disk
Public IP address
Load balancer
Log Analytics workspace
Azure Container Registry
```

The Makefile `cost-check` target lists potentially billable resources and all remaining resources.

---

## Budget Guardrail

A budget alert should be configured at the subscription level.

Suggested lab budget threshold:

```text
30 EUR
```

The budget alert is not a substitute for destroy commands. It is a safety net.

---

## Observability Cost Notes

For the first observability iteration:

- use in-cluster Prometheus/Grafana;
- avoid Azure Managed Grafana;
- avoid Azure Monitor ingestion unless specifically needed;
- expose Grafana through port-forward only.

---

## CI/CD Cost Notes

The CI validation workflow does not create Azure resources.

The manual deployment workflow can create resources when:

```text
apply_infra = true
```

To control cost, use:

```text
destroy_after = true
```

for end-to-end validation runs.
