from flask import Flask, request, jsonify

import db
from orders_logic import get_catalog, calculate_order_total, validate_order

app = Flask(__name__)


@app.route("/health")
def health():
    return jsonify(status="ok")


@app.route("/api/catalog")
def catalog():
    return jsonify(get_catalog())


@app.route("/api/orders", methods=["GET"])
def orders_list():
    conn = db.get_connection()
    try:
        return jsonify(db.list_orders(conn))
    finally:
        conn.close()


@app.route("/api/orders", methods=["POST"])
def orders_create():
    payload = request.get_json(force=True)
    customer_name = payload.get("customer_name", "")
    items = payload.get("items", [])

    try:
        validate_order(customer_name, items)
    except ValueError as e:
        return jsonify(error=str(e)), 400

    total = calculate_order_total(items)
    conn = db.get_connection()
    try:
        row = db.insert_order(conn, customer_name, items, total)
        return jsonify(id=row["id"], total=total, status="pending"), 201
    finally:
        conn.close()


@app.route("/api/orders/<int:order_id>", methods=["GET"])
def orders_get(order_id):
    conn = db.get_connection()
    try:
        order = db.get_order(conn, order_id)
        if order is None:
            return jsonify(error="Order not found"), 404
        return jsonify(order)
    finally:
        conn.close()


if __name__ == "__main__":
    conn = db.get_connection()
    db.init_schema(conn)
    conn.close()
    app.run(host="0.0.0.0", port=5000)
