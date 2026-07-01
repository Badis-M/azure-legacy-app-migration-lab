import os

import psycopg
from psycopg.rows import dict_row


def get_database_connection():
    return psycopg.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", "5432"),
        dbname=os.getenv("DB_NAME", "customer_orders"),
        user=os.getenv("DB_USER", "app_user"),
        password=os.getenv("DB_PASSWORD", "app_password"),
        row_factory=dict_row,
    )


def fetch_all_customers():
    with get_database_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute("SELECT id, name, tier FROM customers ORDER BY id;")
            return cursor.fetchall()


def fetch_all_orders():
    with get_database_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT id, customer_id, status, amount
                FROM orders
                ORDER BY id;
                """
            )
            return cursor.fetchall()


def fetch_failed_orders():
    with get_database_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT id, customer_id, status, amount
                FROM orders
                WHERE status = %s
                ORDER BY id;
                """,
                ("failed",),
            )
            return cursor.fetchall()
