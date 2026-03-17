# Database migrations

## New databases
Use **`schema.sql`** when creating the DB. The `products` table already includes the optional `cost` column.

## Existing databases (add product cost)
To add the optional product cost column for the Margins feature:

1. Open **Vercel Dashboard → Storage → Neon → SQL Editor** (or your Neon SQL Editor).
2. Run the contents of **`add-products-cost.sql`**:
   ```sql
   ALTER TABLE products ADD COLUMN IF NOT EXISTS cost DECIMAL(10,2);
   ```

Or run the full **`migrate-neon.sql`** if you need other past migrations (e.g. `is_vegetarian`, cake options tables) as well.
