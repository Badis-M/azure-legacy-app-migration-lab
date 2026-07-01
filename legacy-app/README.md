# Legacy Customer Orders API

This folder contains the initial legacy-style version of the application.

## Purpose

The goal of this phase is to provide a simple baseline application before modernization.

This version is intentionally limited:

- no container image
- no external database
- no Redis or RabbitMQ
- no Kubernetes manifests
- no CI/CD pipeline
- no observability stack
- local configuration through environment variables

These limitations will be addressed progressively during the migration journey.

## Run Locally

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --reload
```

## Endpoints

```text
GET /
GET /health
GET /api/customers
GET /api/orders
GET /api/orders/failed
```

## Migration Notes

This application will later be:

1. containerized with Docker
2. deployed locally with Docker Compose
3. migrated to Kubernetes
4. deployed to Azure AKS
5. managed through GitOps
6. monitored through Prometheus and Grafana
7. documented with operational runbooks and RCA examples
