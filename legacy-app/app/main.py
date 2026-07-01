from fastapi import FastAPI
from app.config import APP_ENV, APP_NAME, APP_VERSION

app = FastAPI(title=APP_NAME, version=APP_VERSION)


CUSTOMERS = [
    {"id": 1, "name": "Acme Bank", "tier": "enterprise"},
    {"id": 2, "name": "Helios Retail", "tier": "standard"},
    {"id": 3, "name": "Nova Insurance", "tier": "enterprise"},
]

ORDERS = [
    {"id": 1001, "customer_id": 1, "status": "processing", "amount": 12500},
    {"id": 1002, "customer_id": 2, "status": "completed", "amount": 3200},
    {"id": 1003, "customer_id": 3, "status": "failed", "amount": 7800},
]


@app.get("/")
def root():
    return {
        "service": APP_NAME,
        "version": APP_VERSION,
        "environment": APP_ENV,
        "status": "running",
    }


@app.get("/health")
def health():
    return {
        "status": "healthy",
        "service": APP_NAME,
        "environment": APP_ENV,
    }


@app.get("/api/customers")
def list_customers():
    return {"customers": CUSTOMERS}


@app.get("/api/orders")
def list_orders():
    return {"orders": ORDERS}


@app.get("/api/orders/failed")
def list_failed_orders():
    failed_orders = [order for order in ORDERS if order["status"] == "failed"]
    return {"failed_orders": failed_orders}
