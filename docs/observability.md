# Observability

This document defines the planned observability direction for the project.

Observability is the next major platform layer after the manual AKS deployment workflow.

---

## Goals

The observability phase should provide:

- Kubernetes cluster visibility;
- application health visibility;
- basic service metrics;
- PostgreSQL visibility if practical;
- Grafana dashboards;
- alerting examples;
- operational runbook inputs.

---

## Planned Stack

Recommended first stack:

```text
kube-prometheus-stack
Prometheus
Grafana
Alertmanager
ServiceMonitor
```

This gives a realistic Kubernetes observability foundation without requiring a managed Azure observability service at first.

---

## Why Prometheus and Grafana First

Prometheus and Grafana are more valuable at this stage than Kafka because they improve the platform itself.

They help answer operational questions:

```text
Are pods healthy?
Is the API restarting?
Is CPU or memory under pressure?
Is the database pod stable?
Are PVCs bound?
Are deployments rolling out correctly?
```

Kafka is useful later, but it adds operational complexity. It should be introduced only after the platform has basic monitoring.

---

## Initial Metrics Targets

### Kubernetes

Useful metrics:

- pod status;
- container restarts;
- CPU usage;
- memory usage;
- node readiness;
- PVC status;
- deployment replicas;
- StatefulSet status.

### Application

Potential future metrics:

- request count;
- request latency;
- error count;
- `/health` status;
- failed order count as a business/operations signal.

### PostgreSQL

Potential metrics:

- database availability;
- connection count;
- disk usage;
- query latency if exporter is added later.

---

## Proposed Implementation Plan

```text
1. Add Helm provider or Helm-based Makefile target
2. Install kube-prometheus-stack into monitoring namespace
3. Port-forward Grafana locally
4. Add basic dashboard screenshots or notes
5. Add ServiceMonitor for FastAPI if metrics endpoint exists
6. Add alert examples
7. Document runbooks for common alerts
```

---

## Cost Guardrails

Initial observability should avoid:

- Azure Managed Grafana;
- Log Analytics ingestion;
- public LoadBalancer services;
- long-running clusters outside lab sessions.

Use:

```text
ClusterIP services
kubectl port-forward
ephemeral AKS sessions
```

---

## Future FastAPI Metrics

The application could expose metrics with `prometheus-client`.

Example future endpoint:

```text
GET /metrics
```

Potential metrics:

```text
http_requests_total
http_request_duration_seconds
orders_total
failed_orders_total
database_connection_status
```

---

## Kafka Consideration

Kafka can be added later as an event-driven extension.

Potential use case:

```text
failed orders
→ event producer
→ Kafka topic
→ consumer or alerting worker
```

This would demonstrate event-driven architecture, but it should come after observability because Kafka increases platform complexity and resource usage.
