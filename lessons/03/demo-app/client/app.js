// All calls go to /api/... on this same origin. nginx (see nginx.conf.template)
// reverse-proxies /api/ to the server container internally — the browser
// never talks to the server directly.

async function loadCatalog() {
  const res = await fetch('/api/catalog');
  const catalog = await res.json();

  const catalogDiv = document.getElementById('catalog');
  const select = document.getElementById('item-select');
  catalogDiv.innerHTML = '';
  select.innerHTML = '';

  for (const [id, item] of Object.entries(catalog)) {
    const row = document.createElement('div');
    row.className = 'item';
    row.innerHTML = `<span>${item.name}</span><span>$${item.price.toFixed(2)}</span>`;
    catalogDiv.appendChild(row);

    const option = document.createElement('option');
    option.value = id;
    option.textContent = item.name;
    select.appendChild(option);
  }
}

async function loadOrders() {
  const res = await fetch('/api/orders');
  const orders = await res.json();
  const tbody = document.querySelector('#orders-table tbody');
  tbody.innerHTML = '';
  for (const order of orders) {
    const tr = document.createElement('tr');
    tr.innerHTML = `<td>${order.id}</td><td>${order.customer_name}</td><td>$${order.total}</td><td>${order.status}</td>`;
    tbody.appendChild(tr);
  }
}

document.getElementById('order-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  const customerName = document.getElementById('customer-name').value;
  const itemId = document.getElementById('item-select').value;
  const quantity = parseInt(document.getElementById('item-quantity').value, 10);

  const res = await fetch('/api/orders', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      customer_name: customerName,
      items: [{ item_id: itemId, quantity }],
    }),
  });

  const resultDiv = document.getElementById('order-result');
  if (res.ok) {
    const data = await res.json();
    resultDiv.textContent = `Order #${data.id} placed — total $${data.total}`;
    loadOrders();
  } else {
    const err = await res.json();
    resultDiv.textContent = `Error: ${err.error}`;
  }
});

document.getElementById('refresh-orders').addEventListener('click', loadOrders);

loadCatalog();
loadOrders();
