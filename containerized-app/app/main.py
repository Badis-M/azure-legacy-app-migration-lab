from fastapi import FastAPI

from app.config import APP_ENV, APP_NAME, APP_VERSION
from app.database import fetch_all_customers, fetch_all_orders, fetch_failed_orders

app = FastAPI(title=APP_NAME, version=APP_VERSION)


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
    return {"customers": fetch_all_customers()}


@app.get("/api/orders")
def list_orders():
    return {"orders": fetch_all_orders()}


@app.get("/api/orders/failed")
def list_failed_orders():
    return {"failed_orders": fetch_failed_orders()}
