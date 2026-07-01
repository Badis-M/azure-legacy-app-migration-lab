# Containerized Application with PostgreSQL

This folder contains the containerized version of the Customer Orders API.

## Purpose

This phase adds a local PostgreSQL database to make the migration scenario more realistic.

The application is no longer limited to in-memory demo data. It now reads customers and orders from PostgreSQL when running through Docker Compose.

## What This Phase Demonstrates

- Multi-container local environment
- API and database separation
- PostgreSQL initialization through SQL scripts
- Environment-based database configuration
- Docker Compose service networking
- Local validation before Kubernetes migration

## Services

The Docker Compose stack contains:

```text
customer-orders-api
postgres
```

## How Networking Works

Inside Docker Compose, services can communicate by service name.

The API connects to PostgreSQL using:

```text
postgres:5432
```

`postgres` is the Docker Compose service name, not a public DNS record.

From your host machine, the API is available on:

```text
localhost:8000
```

## Run the Stack

From this folder:

```bash
docker compose up --build
```

Then test:

```bash
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8000/api/customers
curl http://127.0.0.1:8000/api/orders
curl http://127.0.0.1:8000/api/orders/failed
```

## Stop the Stack

```bash
docker compose down
```

## Stop and Remove the Database Volume

Use this when you want to reset the database data:

```bash
docker compose down -v
```

## PostgreSQL Initialization

The database is initialized from:

```text
db/init.sql
```

This script creates the required tables and inserts demo data.

## Configuration

The API reads its database connection settings from environment variables:

```text
DB_HOST
DB_PORT
DB_NAME
DB_USER
DB_PASSWORD
```

For local learning, Docker Compose contains non-sensitive demo values.

Do not use this pattern for production secrets.

## Security Notes

This phase intentionally uses local demo credentials to keep the lab simple.

In later phases, secrets will be moved to Kubernetes Secrets and then Azure Key Vault.

## Known Limitations

- No database migrations tool yet.
- No connection pooling yet.
- No Kubernetes PostgreSQL deployment yet.
- No managed Azure PostgreSQL yet.
- No secret manager yet.
- No retry/backoff strategy yet.

These topics will be addressed progressively.
