import os

import psycopg2
import psycopg2.extras
from psycopg2.extras import RealDictCursor


def get_connection():
    return psycopg2.connect(
        host=os.environ.get("DB_HOST", "localhost"),
        port=os.environ.get("DB_PORT", "5432"),
        dbname=os.environ.get("DB_NAME", "jewelry"),
        user=os.environ.get("DB_USER", "jewelry"),
        password=os.environ.get("DB_PASSWORD", ""),
        cursor_factory=RealDictCursor,
    )


def init_schema(conn):
    with conn.cursor() as cur:
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS orders (
                id SERIAL PRIMARY KEY,
                customer_name TEXT NOT NULL,
                items JSONB NOT NULL,
                total NUMERIC(10, 2) NOT NULL,
                status TEXT NOT NULL DEFAULT 'pending',
                created_at TIMESTAMPTZ NOT NULL DEFAULT now()
            )
            """
        )
        conn.commit()


def insert_order(conn, customer_name, items, total, status="pending"):
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO orders (customer_name, items, total, status)
            VALUES (%s, %s, %s, %s)
            RETURNING id, created_at
            """,
            (customer_name, psycopg2.extras.Json(items), total, status),
        )
        row = cur.fetchone()
        conn.commit()
        return row


def list_orders(conn):
    with conn.cursor() as cur:
        cur.execute("SELECT * FROM orders ORDER BY created_at DESC")
        return cur.fetchall()


def get_order(conn, order_id):
    with conn.cursor() as cur:
        cur.execute("SELECT * FROM orders WHERE id = %s", (order_id,))
        return cur.fetchone()
