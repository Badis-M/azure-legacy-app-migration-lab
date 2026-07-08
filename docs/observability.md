# Observability

This document describes the observability stack added to the Azure Legacy App Migration Lab.

The goal is to provide both Kubernetes-level visibility and application-level metrics.

---

## Current Status

Validated:

```text
kube-prometheus-stack installed on AKS
Prometheus accessible through port-forward
Grafana accessible through port-forward
Alertmanager deployed
kube-state-metrics deployed
node-exporter deployed
FastAPI /metrics endpoint working
Prometheus-format custom application metrics exposed
ServiceMonitor created for customer-orders-api
```

---

## Observability Architecture

```text
customer-orders-api
│
├── /health
├── /api/customers
├── /api/orders
├── /api/orders/failed
└── /metrics
      │
      ▼
ServiceMonitor
      │
      ▼
Prometheus
      │
      ▼
Grafana
```

Kubernetes observability is provided by:

```text
kube-prometheus-stack
Prometheus Operator
Prometheus
Grafana
Alertmanager
kube-state-metrics
node-exporter
```

---

## Helm Stack

The monitoring stack is deployed with `kube-prometheus-stack`.

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values monitoring/kube-prometheus-stack-values.yaml
```

The values file keeps the setup cost-aware:

```yaml
grafana:
  service:
    type: ClusterIP

prometheus:
  prometheusSpec:
    retention: 6h
    scrapeInterval: 30s
    evaluationInterval: 30s
    storageSpec: {}

alertmanager:
  enabled: true
  alertmanagerSpec:
    storage: {}
```

| Choice | Reason |
|---|---|
| `ClusterIP` | Avoid public LoadBalancer cost. |
| `retention: 6h` | Keep lab storage small. |
| `storageSpec: {}` | Avoid persistent Prometheus volume at first. |
| port-forward access | Keep the stack private and ephemeral. |

---

## Access

Grafana:

```bash
kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring
```

Prometheus:

```bash
kubectl port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090 -n monitoring
```

Application:

```bash
kubectl port-forward svc/customer-orders-api 8000:80 -n customer-orders
```

---

## Application Metrics

The FastAPI application exposes metrics through:

```text
GET /metrics
```

Implemented metrics:

```text
customer_orders_http_requests_total
customer_orders_http_request_duration_seconds
customer_orders_failed_orders_total
```

### Request Counter

```text
customer_orders_http_requests_total{method, endpoint, status_code}
```

Example:

```text
customer_orders_http_requests_total{endpoint="/health",method="GET",status_code="200"} 25
customer_orders_http_requests_total{endpoint="/api/orders",method="GET",status_code="200"} 4
```

### Request Duration Histogram

```text
customer_orders_http_request_duration_seconds
```

This exposes:

```text
customer_orders_http_request_duration_seconds_bucket
customer_orders_http_request_duration_seconds_count
customer_orders_http_request_duration_seconds_sum
```

### Failed Orders Counter

```text
customer_orders_failed_orders_total
```

This counter increases when `/api/orders/failed` returns failed orders.

This is a demo operational metric, not a production event counter.

---

## Local Validation

Generate traffic:

```bash
curl http://localhost:8000/health
curl http://localhost:8000/api/customers
curl http://localhost:8000/api/orders
curl http://localhost:8000/api/orders/failed
```

Validate metrics:

```bash
curl http://localhost:8000/metrics | grep customer_orders
```

Expected output includes:

```text
customer_orders_http_requests_total
customer_orders_http_request_duration_seconds
customer_orders_failed_orders_total
```

---

## ServiceMonitor

The API service exposes a named port:

```yaml
ports:
  - name: http
    port: 80
    targetPort: 8000
```

The `ServiceMonitor` targets that named port:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: customer-orders-api
  namespace: customer-orders
  labels:
    release: monitoring
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: customer-orders-api
  endpoints:
    - port: http
      path: /metrics
      interval: 30s
  namespaceSelector:
    matchNames:
      - customer-orders
```

Validate:

```bash
kubectl get servicemonitor -n customer-orders
kubectl describe servicemonitor customer-orders-api -n customer-orders
```

---

## PromQL Validation

```promql
up{namespace="customer-orders"}
```

```promql
customer_orders_http_requests_total
```

```promql
sum by (endpoint) (customer_orders_http_requests_total)
```

```promql
rate(customer_orders_http_requests_total[5m])
```

```promql
customer_orders_failed_orders_total
```

Average request duration by endpoint:

```promql
sum by (endpoint) (rate(customer_orders_http_request_duration_seconds_sum[5m]))
/
sum by (endpoint) (rate(customer_orders_http_request_duration_seconds_count[5m]))
```

Approximate p95 latency:

```promql
histogram_quantile(
  0.95,
  sum by (le, endpoint) (
    rate(customer_orders_http_request_duration_seconds_bucket[5m])
  )
)
```

---

## Current Limitations

- no authentication on `/metrics`;
- no committed Grafana dashboard JSON yet;
- no alerting rules yet;
- failed order metric is intentionally simple and lab-oriented;
- access is through `kubectl port-forward`, not public ingress.

---

## Cost Notes

The stack avoids unnecessary Azure cost:

- no LoadBalancer service;
- no Azure Managed Grafana;
- no persistent Prometheus volume initially;
- short Prometheus retention;
- access through `kubectl port-forward`;
- cluster should be destroyed after validation.

Cleanup:

```bash
helm uninstall monitoring -n monitoring
kubectl delete namespace monitoring
```

Full lab cleanup:

```bash
make infra-down
make cost-check
```

---

## Interview Summary

```text
I added observability to the AKS platform using kube-prometheus-stack. Prometheus and Grafana provide Kubernetes-level visibility, and I instrumented the FastAPI application with a /metrics endpoint using prometheus-client.

The application exposes request counters, latency histograms and a simple failed-orders metric. I configured a ServiceMonitor so Prometheus can discover and scrape the API automatically. This gives both infrastructure-level and application-level visibility without exposing public endpoints or adding managed service cost.
```
