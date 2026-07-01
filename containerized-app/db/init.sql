CREATE TABLE IF NOT EXISTS customers (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    tier TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS orders (
    id INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers(id),
    status TEXT NOT NULL,
    amount INTEGER NOT NULL
);

INSERT INTO customers (id, name, tier) VALUES
    (1, 'Acme Bank', 'enterprise'),
    (2, 'Helios Retail', 'standard'),
    (3, 'Nova Insurance', 'enterprise')
ON CONFLICT (id) DO NOTHING;

INSERT INTO orders (id, customer_id, status, amount) VALUES
    (1001, 1, 'processing', 12500),
    (1002, 2, 'completed', 3200),
    (1003, 3, 'failed', 7800)
ON CONFLICT (id) DO NOTHING;
