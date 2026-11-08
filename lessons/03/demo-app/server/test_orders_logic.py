import pytest

from orders_logic import (
    get_catalog,
    get_item,
    calculate_order_total,
    validate_order,
    build_order_record,
)


def test_catalog_not_empty():
    assert len(get_catalog()) > 0


def test_get_item_known():
    item = get_item("ring-gold-001")
    assert item is not None
    assert item["name"] == "Gold Engagement Ring"


def test_get_item_unknown():
    assert get_item("does-not-exist") is None


def test_calculate_order_total_single_item():
    total = calculate_order_total([{"item_id": "ring-gold-001", "quantity": 1}])
    assert total == 1200.00


def test_calculate_order_total_multiple_items():
    total = calculate_order_total(
        [
            {"item_id": "ring-gold-001", "quantity": 1},
            {"item_id": "necklace-silver-002", "quantity": 2},
        ]
    )
    assert total == 1200.00 + 2 * 350.00


def test_calculate_order_total_unknown_item_raises():
    with pytest.raises(ValueError):
        calculate_order_total([{"item_id": "does-not-exist", "quantity": 1}])


def test_calculate_order_total_invalid_quantity_raises():
    with pytest.raises(ValueError):
        calculate_order_total([{"item_id": "ring-gold-001", "quantity": 0}])


def test_validate_order_requires_customer_name():
    with pytest.raises(ValueError):
        validate_order("", [{"item_id": "ring-gold-001", "quantity": 1}])


def test_validate_order_requires_items():
    with pytest.raises(ValueError):
        validate_order("Dana", [])


def test_validate_order_valid():
    assert validate_order("Dana", [{"item_id": "ring-gold-001", "quantity": 1}]) is True


def test_build_order_record():
    record = build_order_record(1, "Dana", [{"item_id": "ring-gold-001", "quantity": 1}])
    assert record["id"] == 1
    assert record["customer_name"] == "Dana"
    assert record["total"] == 1200.00
    assert record["status"] == "pending"
