# Containerized Application

This folder contains the containerized version of the legacy Customer Orders API.

## Purpose

This phase demonstrates the first modernization step: moving from a locally executed application to a reproducible container runtime.

The goal is not to change the business logic yet. The goal is to package the same application in a way that can later be deployed to Kubernetes and Azure AKS.

## What Changed Compared to `legacy-app`

- The application now has a Dockerfile.
- Runtime dependencies are installed inside the image.
- The service can be started with Docker Compose.
- Configuration is still provided through environment variables.
- A Docker healthcheck validates the `/health` endpoint.
- The application is closer to a Kubernetes-ready workload.

## Run with Docker Compose

From this folder:

```bash
docker compose up --build
```

Then test the API:

```bash
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8000/api/customers
curl http://127.0.0.1:8000/api/orders/failed
```

Stop the container:

```bash
docker compose down
```

## Build Manually

```bash
docker build -t legacy-customer-orders-api:local .
```

## Run Manually

```bash
docker run --rm -p 8000:8000 --env-file .env.example legacy-customer-orders-api:local
```

## Design Notes

This containerization phase keeps the application intentionally simple.

The image uses Python slim to reduce size while keeping the build process readable for learning purposes.

The container runs Uvicorn directly. A production-grade deployment could later introduce stricter runtime hardening, non-root execution, dependency pinning policies, vulnerability scanning, and Kubernetes-native probes.

## Known Limitations

- No external PostgreSQL database yet.
- No Redis integration yet.
- No RabbitMQ integration yet.
- No Kubernetes manifests yet.
- No image vulnerability scanning yet.
- No CI/CD pipeline yet.
- No Azure Container Registry yet.

These topics will be addressed in later migration phases.
