-- If menu shows "sold out" but stock looks fine, `is_available` may be out of sync with `is_sold_out`.
-- Run in Neon SQL Editor after deploying API that sets both columns together.

UPDATE products
SET is_available = (NOT is_sold_out)
WHERE is_available IS DISTINCT FROM (NOT is_sold_out);
