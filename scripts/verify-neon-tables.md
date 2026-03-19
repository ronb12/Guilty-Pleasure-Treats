# Verify Neon Tables Are Updated

## 1. Apply or update tables (one-time or after schema changes)

From the project root. **Option A – Neon CLI** (see [docs/NEON_CLI_CONNECT.md](../docs/NEON_CLI_CONNECT.md)):

```bash
npx neonctl auth                    # one-time login
export POSTGRES_URL=$(npx neonctl connection-string)
node scripts/run-missing-tables.js
```

**Option B – Vercel env:**

```bash
vercel env pull .env.neon --environment=production
node --env-file=.env.neon scripts/run-missing-tables.js
```

**Option C – Connection string in environment:**

```bash
export POSTGRES_URL='postgres://user:pass@host.neon.tech/neondb?sslmode=require'
node scripts/run-missing-tables.js
```

You should see one line per table ending with `OK` and finally: `All missing tables are ready.`

---

## 2. Confirm in Neon Console

1. Open [Neon Console](https://console.neon.tech) → your project.
2. Go to **SQL Editor**.
3. Run:

```sql
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;
```

You should see at least these tables:

- admin_messages  
- ai_cake_designs  
- business_settings  
- cake_gallery  
- contact_message_replies  
- contact_messages  
- custom_cake_orders  
- customers  
- events  
- orders  
- product_categories  
- products  
- promotions  
- push_tokens  
- reviews  
- sessions  
- users  

---

## 3. Optional: quick row count

```sql
SELECT 'users' AS tbl, COUNT(*) FROM users
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'events', COUNT(*) FROM events;
```

This confirms the tables exist and are queryable.
