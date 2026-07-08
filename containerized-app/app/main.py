import time

from fastapi import FastAPI, Request, Response
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest

from app.config import APP_ENV, APP_NAME, APP_VERSION
from app.database import fetch_all_customers, fetch_all_orders, fetch_failed_orders

app = FastAPI(title=APP_NAME, version=APP_VERSION)

HTTP_REQUESTS_TOTAL = Counter(
    "customer_orders_http_requests_total",
    "Total number of HTTP requests handled by the customer orders API.",
    ["method", "endpoint", "status_code"],
)

HTTP_REQUEST_DURATION_SECONDS = Histogram(
    "customer_orders_http_request_duration_seconds",
    "HTTP request duration in seconds for the customer orders API.",
    ["method", "endpoint"],
)

FAILED_ORDERS_TOTAL = Counter(
    "customer_orders_failed_orders_total",
    "Total number of failed orders returned by the customer orders API.",
)


@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    start_time = time.time()
    response = await call_next(request)
    duration = time.time() - start_time

    endpoint = request.url.path

    if endpoint != "/metrics":
        HTTP_REQUESTS_TOTAL.labels(
            method=request.method,
            endpoint=endpoint,
            status_code=response.status_code,
        ).inc()
        HTTP_REQUEST_DURATION_SECONDS.labels(
            method=request.method,
            endpoint=endpoint,
        ).observe(duration)

    return response


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


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/api/customers")
def list_customers():
    return {"customers": fetch_all_customers()}


@app.get("/api/orders")
def list_orders():
    return {"orders": fetch_all_orders()}


@app.get("/api/orders/failed")
def list_failed_orders():
    failed_orders = fetch_failed_orders()
    FAILED_ORDERS_TOTAL.inc(len(failed_orders))
    return {"failed_orders": failed_orders}