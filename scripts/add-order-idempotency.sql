-- Run in Neon SQL editor (once). Used for POST /api/orders idempotency (Idempotency-Key header).
CREATE TABLE IF NOT EXISTS order_idempotency (
  idempotency_key TEXT PRIMARY KEY,
  order_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_order_idempotency_created_at ON order_idempotency(created_at DESC);
