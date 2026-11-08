CATALOG = {
    "ring-gold-001": {"name": "Gold Engagement Ring", "price": 1200.00},
    "necklace-silver-002": {"name": "Silver Pearl Necklace", "price": 350.00},
    "bracelet-gold-003": {"name": "Gold Tennis Bracelet", "price": 890.00},
    "earrings-diamond-004": {"name": "Diamond Stud Earrings", "price": 2400.00},
}


def get_catalog():
    return CATALOG


def get_item(item_id):
    return CATALOG.get(item_id)


def calculate_order_total(items):
    """items: list of {"item_id": str, "quantity": int}"""
    total = 0.0
    for entry in items:
        item = get_item(entry["item_id"])
        if item is None:
            raise ValueError(f"Unknown item: {entry['item_id']}")
        quantity = entry["quantity"]
        if quantity <= 0:
            raise ValueError(f"Invalid quantity for {entry['item_id']}: {quantity}")
        total += item["price"] * quantity
    return round(total, 2)


def validate_order(customer_name, items):
    if not customer_name or not customer_name.strip():
        raise ValueError("Customer name is required")
    if not items:
        raise ValueError("Order must contain at least one item")
    calculate_order_total(items)  # raises if any item/quantity is invalid
    return True


def build_order_record(order_id, customer_name, items):
    validate_order(customer_name, items)
    return {
        "id": order_id,
        "customer_name": customer_name.strip(),
        "items": items,
        "total": calculate_order_total(items),
        "status": "pending",
    }
