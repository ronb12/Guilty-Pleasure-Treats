#!/usr/bin/env node
/**
 * Create all tables that the app and APIs expect in Neon.
 * Run once when setting up a new DB or when you see "relation does not exist" errors.
 * Usage: node --env-file=.env.neon scripts/run-missing-tables.js  (Node 20+)
 *        See docs/NEON_TABLES.md
 *
 * If PATCH /api/promotions/:id returns 503 and logs say promotions.updated_at missing,
 * run scripts/sql/fix-promotions-updated-at.sql in the Neon SQL Editor, or re-run this script.
 *
 * Product sizes (Small/Large, per-size pricing): `products.size_options` JSONB — see scripts/sql/add-products-size-options.sql
 * or rely on ALTER below; the products API also runs ALTER IF NOT EXISTS on first write if the column is missing.
 */
import { neon } from '@neondatabase/serverless';

const connectionString = process.env.POSTGRES_URL || process.env.DATABASE_URL;
if (!connectionString) {
  console.error('Set POSTGRES_URL. Run: vercel env pull .env.neon --environment=production');
  process.exit(1);
}

const sql = neon(connectionString);

async function main() {
  try {
    // --- Base tables (must exist before push_tokens, etc.) ---

    // users (auth, admin, push_tokens FK)
    await sql`
      CREATE TABLE IF NOT EXISTS users (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        email TEXT,
        display_name TEXT,
        is_admin BOOLEAN NOT NULL DEFAULT false,
        points INT NOT NULL DEFAULT 0,
        neon_auth_id TEXT,
        password_hash TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      )
    `;
    await sql`CREATE INDEX IF NOT EXISTS idx_users_email ON users(LOWER(email))`;
    await sql`ALTER TABLE users ADD COLUMN IF NOT EXISTS phone TEXT`;
    await sql`ALTER TABLE users ADD COLUMN IF NOT EXISTS apple_sub TEXT`;
    await sql`
      DO $$
      BEGIN
        IF EXISTS (
          SELECT 1
          FROM information_schema.columns
          WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'apple_id'
        ) THEN
          UPDATE users
          SET apple_sub = apple_id
          WHERE apple_sub IS NULL
            AND apple_id IS NOT NULL
            AND BTRIM(apple_id) <> '';
        END IF;
      END $$;
    `;
    await sql`CREATE UNIQUE INDEX IF NOT EXISTS idx_users_apple_sub ON users(apple_sub) WHERE apple_sub IS NOT NULL`;
    console.log('users OK');

    // sessions (local auth after login)
    await sql`
      CREATE TABLE IF NOT EXISTS sessions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        expires_at TIMESTAMPTZ NOT NULL
      )
    `;
    await sql`CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id)`;
    console.log('sessions OK');

    // password_reset_tokens (forgot-password / reset-password API)
    // Stores SHA-256 hex of the reset secret in `token` (matches common Neon setups).
    await sql`
      CREATE TABLE IF NOT EXISTS password_reset_tokens (
        user_id UUID NOT NULL,
        token TEXT NOT NULL,
        expires_at TIMESTAMPTZ NOT NULL,
        created_at TIMESTAMPTZ DEFAULT NOW()
      )
    `;
    await sql`CREATE UNIQUE INDEX IF NOT EXISTS idx_password_reset_token ON password_reset_tokens(token)`;
    await sql`CREATE INDEX IF NOT EXISTS idx_password_reset_user_id ON password_reset_tokens(user_id)`;
    console.log('password_reset_tokens OK');

    // newsletter_suppressions (marketing opt-out; /api/admin/newsletter excludes these emails)
    await sql`
      CREATE TABLE IF NOT EXISTS newsletter_suppressions (
        email TEXT PRIMARY KEY,
        created_at TIMESTAMPTZ DEFAULT NOW()
      )
    `;
    console.log('newsletter_suppressions OK');

    // orders (checkout, admin orders list, analytics)
    await sql`
      CREATE TABLE IF NOT EXISTS orders (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID,
        customer_name TEXT NOT NULL,
        customer_phone TEXT NOT NULL,
        customer_email TEXT,
        delivery_address TEXT,
        items JSONB NOT NULL DEFAULT '[]',
        subtotal DECIMAL(12,2) NOT NULL DEFAULT 0,
        tax DECIMAL(12,2) NOT NULL DEFAULT 0,
        total DECIMAL(12,2) NOT NULL DEFAULT 0,
        fulfillment_type TEXT NOT NULL DEFAULT 'Pickup',
        scheduled_pickup_date TIMESTAMPTZ,
        status TEXT NOT NULL DEFAULT 'Pending',
        stripe_payment_intent_id TEXT,
        manual_paid_at TIMESTAMPTZ,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW(),
        estimated_ready_time TIMESTAMPTZ,
        pickup_time TIMESTAMPTZ,
        ready_by TIMESTAMPTZ,
        tip_cents INT NOT NULL DEFAULT 0,
        tax_cents INT NOT NULL DEFAULT 0,
        custom_cake_order_ids TEXT[],
        ai_cake_design_ids TEXT[],
        loyalty_points_awarded INT
      )
    `;
    await sql`ALTER TABLE orders ADD COLUMN IF NOT EXISTS loyalty_points_awarded INT`;
    // Analytics / list API — GET /api/orders SELECTs these; missing columns cause 500 in admin.
    await sql`ALTER TABLE orders ADD COLUMN IF NOT EXISTS promo_code TEXT`;
    await sql`ALTER TABLE orders ADD COLUMN IF NOT EXISTS tip_cents INT NOT NULL DEFAULT 0`;
    await sql`ALTER TABLE orders ADD COLUMN IF NOT EXISTS tracking_carrier TEXT`;
    await sql`ALTER TABLE orders ADD COLUMN IF NOT EXISTS tracking_number TEXT`;
    await sql`ALTER TABLE orders ADD COLUMN IF NOT EXISTS tracking_status_detail TEXT`;
    await sql`ALTER TABLE orders ADD COLUMN IF NOT EXISTS tracking_updated_at TIMESTAMPTZ`;
    await sql`CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id)`;
    await sql`CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at DESC)`;
    await sql`CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status)`;
    console.log('orders OK');

    // products (menu, admin products)
    await sql`
      CREATE TABLE IF NOT EXISTS products (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        name TEXT NOT NULL,
        description TEXT,
        price DECIMAL(10,2) NOT NULL DEFAULT 0,
        cost DECIMAL(10,2),
        image_url TEXT,
        category TEXT NOT NULL DEFAULT '',
        is_featured BOOLEAN NOT NULL DEFAULT false,
        is_sold_out BOOLEAN NOT NULL DEFAULT false,
        is_vegan BOOLEAN NOT NULL DEFAULT false,
        stock_quantity INT,
        low_stock_threshold INT,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW(),
        is_available BOOLEAN NOT NULL DEFAULT true,
        available_from DATE,
        size_options JSONB DEFAULT '[]'::jsonb
      )
    `;
    // Existing DBs created before is_vegan existed — CREATE TABLE IF NOT EXISTS does not add columns.
    await sql`ALTER TABLE products ADD COLUMN IF NOT EXISTS is_vegan BOOLEAN NOT NULL DEFAULT false`;
    await sql`ALTER TABLE products ADD COLUMN IF NOT EXISTS is_available BOOLEAN NOT NULL DEFAULT true`;
    // Per-product sizes (e.g. Small/Large) with individual prices; app + API expect this column.
    await sql`ALTER TABLE products ADD COLUMN IF NOT EXISTS size_options JSONB DEFAULT '[]'::jsonb`;
    await sql`CREATE INDEX IF NOT EXISTS idx_products_category ON products(category)`;
    await sql`CREATE INDEX IF NOT EXISTS idx_products_created_at ON products(created_at DESC)`;
    console.log('products OK');

    // custom_cake_orders (custom cake builder → cart)
    await sql`
      CREATE TABLE IF NOT EXISTS custom_cake_orders (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID,
        order_id UUID,
        size TEXT NOT NULL,
        flavor TEXT NOT NULL,
        frosting TEXT NOT NULL,
        toppings JSONB DEFAULT '[]',
        message TEXT NOT NULL DEFAULT '',
        design_image_url TEXT,
        price DECIMAL(10,2) NOT NULL DEFAULT 0,
        created_at TIMESTAMPTZ DEFAULT NOW()
      )
    `;
    await sql`ALTER TABLE custom_cake_orders ADD COLUMN IF NOT EXISTS toppings JSONB DEFAULT '[]'`;
    await sql`CREATE INDEX IF NOT EXISTS idx_custom_cake_orders_user_id ON custom_cake_orders(user_id)`;
    await sql`CREATE INDEX IF NOT EXISTS idx_custom_cake_orders_order_id ON custom_cake_orders(order_id)`;
    console.log('custom_cake_orders OK');

    // ai_cake_designs (AI cake gallery orders)
    await sql`
      CREATE TABLE IF NOT EXISTS ai_cake_designs (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID,
        order_id UUID,
        size TEXT NOT NULL DEFAULT '',
        flavor TEXT NOT NULL DEFAULT '',
        frosting TEXT NOT NULL DEFAULT '',
        design_prompt TEXT NOT NULL DEFAULT '',
        generated_image_url TEXT,
        price DECIMAL(10,2) NOT NULL DEFAULT 0,
        created_at TIMESTAMPTZ DEFAULT NOW()
      )
    `;
    await sql`CREATE INDEX IF NOT EXISTS idx_ai_cake_designs_user_id ON ai_cake_designs(user_id)`;
    await sql`CREATE INDEX IF NOT EXISTS idx_ai_cake_designs_order_id ON ai_cake_designs(order_id)`;
    console.log('ai_cake_designs OK');

    // --- App / API tables ---

    // admin_messages (Admin → Messages “Send new message” / Sent list)
    await sql`
      CREATE TABLE IF NOT EXISTS admin_messages (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        to_user_id TEXT NOT NULL,
        body TEXT NOT NULL,
        created_at TIMESTAMPTZ DEFAULT NOW()
      )
    `;
    await sql`CREATE INDEX IF NOT EXISTS idx_admin_messages_created_at ON admin_messages(created_at DESC)`;
    console.log('admin_messages OK');

    // contact_messages (contact form)
    await sql`
      CREATE TABLE IF NOT EXISTS contact_messages (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        name TEXT,
        email TEXT NOT NULL,
        subject TEXT,
        message TEXT NOT NULL,
        user_id TEXT,
        read_at TIMESTAMPTZ,
        created_at TIMESTAMPTZ DEFAULT NOW()
      )
    `;
    await sql`CREATE INDEX IF NOT EXISTS idx_contact_messages_created_at ON contact_messages(created_at DESC)`;
    await sql`ALTER TABLE contact_messages ADD COLUMN IF NOT EXISTS order_id UUID`;
    console.log('contact_messages OK');

    // contact_message_replies (depends on contact_messages)
    await sql`
      CREATE TABLE IF NOT EXISTS contact_message_replies (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        contact_message_id UUID NOT NULL REFERENCES contact_messages(id) ON DELETE CASCADE,
        body TEXT NOT NULL,
        created_at TIMESTAMPTZ DEFAULT NOW()
      )
    `;
    await sql`CREATE INDEX IF NOT EXISTS idx_contact_message_replies_message_id ON contact_message_replies(contact_message_id)`;
    console.log('contact_message_replies OK');

    // cake_gallery
    await sql`
      CREATE TABLE IF NOT EXISTS cake_gallery (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        image_url TEXT NOT NULL,
        title TEXT NOT NULL DEFAULT '',
        description TEXT,
        category TEXT,
        price DECIMAL(10,2),
        display_order INT NOT NULL DEFAULT 0,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      )
    `;
    await sql`CREATE INDEX IF NOT EXISTS idx_cake_gallery_display_order ON cake_gallery(display_order ASC, created_at DESC)`;
    console.log('cake_gallery OK');

    // product_categories
    await sql`
      CREATE TABLE IF NOT EXISTS product_categories (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        name TEXT NOT NULL,
        display_order INT NOT NULL DEFAULT 0,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      )
    `;
    await sql`CREATE UNIQUE INDEX IF NOT EXISTS idx_product_categories_name_lower_unique ON product_categories (LOWER(TRIM(name)))`;
    await sql`CREATE INDEX IF NOT EXISTS idx_product_categories_display_order ON product_categories(display_order ASC, name ASC)`;
    await sql`
      INSERT INTO product_categories (name, display_order)
      VALUES
        ('Cupcakes', 10),
        ('Cookies', 20),
        ('Cakes', 30),
        ('Brownies', 40),
        ('Seasonal Treats', 50),
        ('Treat 4 Paws', 60)
      ON CONFLICT (LOWER(TRIM(name))) DO NOTHING
    `;
    console.log('product_categories OK');

    // customers (saved customers / address book)
    await sql`
      CREATE TABLE IF NOT EXISTS customers (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        name TEXT NOT NULL,
        phone TEXT NOT NULL DEFAULT '',
        email TEXT,
        address TEXT,
        street TEXT,
        address_line_2 TEXT,
        city TEXT,
        state TEXT,
        postal_code TEXT,
        notes TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      )
    `;
    await sql`CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(name ASC)`;
    await sql`ALTER TABLE customers ADD COLUMN IF NOT EXISTS food_allergies TEXT`;
    console.log('customers OK');

    // push_tokens (requires users table)
    await sql`
      CREATE TABLE IF NOT EXISTS push_tokens (
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        device_token TEXT NOT NULL,
        is_admin BOOLEAN NOT NULL DEFAULT false,
        updated_at TIMESTAMPTZ DEFAULT NOW(),
        PRIMARY KEY (user_id)
      )
    `;
    await sql`CREATE INDEX IF NOT EXISTS idx_push_tokens_updated ON push_tokens(updated_at)`;
    console.log('push_tokens OK');

    // events (tastings, pop-ups)
    await sql`
      CREATE TABLE IF NOT EXISTS events (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        title TEXT NOT NULL,
        description TEXT,
        start_at TIMESTAMPTZ,
        end_at TIMESTAMPTZ,
        image_url TEXT,
        location TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      )
    `;
    await sql`ALTER TABLE events ADD COLUMN IF NOT EXISTS start_at TIMESTAMPTZ`;
    await sql`ALTER TABLE events ADD COLUMN IF NOT EXISTS end_at TIMESTAMPTZ`;
    await sql`ALTER TABLE events ADD COLUMN IF NOT EXISTS image_url TEXT`;
    await sql`ALTER TABLE events ADD COLUMN IF NOT EXISTS location TEXT`;
    await sql`ALTER TABLE events ADD COLUMN IF NOT EXISTS description TEXT`;
    await sql`CREATE INDEX IF NOT EXISTS idx_events_start_at ON events(start_at ASC) WHERE start_at IS NOT NULL`;
    console.log('events OK');

    // reviews (customer reviews; order-based like DoorDash)
    await sql`
      CREATE TABLE IF NOT EXISTS reviews (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        author_name TEXT,
        rating INT CHECK (rating >= 1 AND rating <= 5),
        text TEXT,
        product_id TEXT,
        order_id UUID,
        user_id TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW()
      )
    `;
    await sql`CREATE INDEX IF NOT EXISTS idx_reviews_created_at ON reviews(created_at DESC)`;
    await sql`ALTER TABLE reviews ADD COLUMN IF NOT EXISTS order_id UUID`;
    await sql`ALTER TABLE reviews ADD COLUMN IF NOT EXISTS user_id TEXT`;
    await sql`ALTER TABLE reviews ADD COLUMN IF NOT EXISTS author_name TEXT`;
    await sql`CREATE UNIQUE INDEX IF NOT EXISTS idx_reviews_order_user ON reviews(order_id, user_id) WHERE order_id IS NOT NULL AND user_id IS NOT NULL`;
    console.log('reviews OK');

    // promotions (discount codes, admin)
    await sql`
      CREATE TABLE IF NOT EXISTS promotions (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        code TEXT NOT NULL UNIQUE,
        discount_type TEXT NOT NULL DEFAULT 'Percent off',
        value DECIMAL(10,2) NOT NULL DEFAULT 0,
        valid_from TIMESTAMPTZ,
        valid_to TIMESTAMPTZ,
        is_active BOOLEAN NOT NULL DEFAULT true,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW(),
        min_subtotal DECIMAL(10,2),
        min_total_quantity INTEGER,
        first_order_only BOOLEAN NOT NULL DEFAULT false
      )
    `;
    // Older Neon DBs: table existed before updated_at — PATCH /api/promotions/:id fails with 42703 until this runs.
    await sql`ALTER TABLE promotions ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW()`;
    await sql`CREATE INDEX IF NOT EXISTS idx_promotions_code ON promotions(code)`;
    await sql`CREATE INDEX IF NOT EXISTS idx_promotions_created_at ON promotions(created_at DESC)`;
    await sql`ALTER TABLE promotions ADD COLUMN IF NOT EXISTS min_subtotal DECIMAL(10,2)`;
    await sql`ALTER TABLE promotions ADD COLUMN IF NOT EXISTS min_total_quantity INTEGER`;
    await sql`ALTER TABLE promotions ADD COLUMN IF NOT EXISTS first_order_only BOOLEAN NOT NULL DEFAULT false`;
    console.log('promotions OK');

    // loyalty_rewards (admin-editable: points → free catalog product)
    await sql`
      CREATE TABLE IF NOT EXISTS loyalty_rewards (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        name TEXT NOT NULL,
        points_required INT NOT NULL CHECK (points_required > 0),
        product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
        sort_order INT NOT NULL DEFAULT 0,
        is_active BOOLEAN NOT NULL DEFAULT true,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      )
    `;
    await sql`CREATE INDEX IF NOT EXISTS idx_loyalty_rewards_active ON loyalty_rewards (is_active, sort_order)`;
    console.log('loyalty_rewards OK');

    // business_settings (custom_cake_options, main config, etc.)
    await sql`
      CREATE TABLE IF NOT EXISTS business_settings (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        key TEXT NOT NULL UNIQUE,
        value_json JSONB NOT NULL DEFAULT '{}',
        updated_at TIMESTAMPTZ DEFAULT NOW()
      )
    `;
    await sql`ALTER TABLE business_settings ADD COLUMN IF NOT EXISTS key TEXT`;
    await sql`ALTER TABLE business_settings ADD COLUMN IF NOT EXISTS value_json JSONB DEFAULT '{}'`;
    await sql`ALTER TABLE business_settings ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW()`;
    // Denormalized for Neon console / audits; API also stores in value_json on save.
    await sql`ALTER TABLE business_settings ADD COLUMN IF NOT EXISTS settings_last_updated_by_name TEXT`;
    try {
      const mainRow = await sql`SELECT 1 FROM business_settings WHERE key = 'main' LIMIT 1`;
      if (mainRow.length === 0) {
        await sql`INSERT INTO business_settings (key, value_json) VALUES ('main', '{"lead_time_hours": 24, "business_hours": {"mon":"9-17","tue":"9-17","wed":"9-17","thu":"9-17","fri":"9-17","sat":"9-15","sun":null}, "min_order_cents": 0, "tax_rate_percent": 0}'::jsonb)`;
      }
    } catch (e) {
      if (!/duplicate key|unique constraint/i.test(e?.message || '')) throw e;
    }
    console.log('business_settings OK');

    // order_idempotency (POST /api/orders Idempotency-Key)
    await sql`
      CREATE TABLE IF NOT EXISTS order_idempotency (
        idempotency_key TEXT PRIMARY KEY,
        order_id UUID,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `;
    await sql`CREATE INDEX IF NOT EXISTS idx_order_idempotency_created_at ON order_idempotency(created_at DESC)`;
    console.log('order_idempotency OK');

    console.log('\nAll missing tables are ready.');

    const coreTables = [
      'users', 'sessions', 'password_reset_tokens', 'orders', 'products',
      'custom_cake_orders', 'ai_cake_designs', 'admin_messages', 'contact_messages',
      'contact_message_replies', 'cake_gallery', 'product_categories', 'customers',
      'push_tokens', 'events', 'reviews', 'promotions', 'loyalty_rewards', 'business_settings',
      'order_idempotency',
    ];
    const verify = await sql`
      SELECT tablename FROM pg_tables
      WHERE schemaname = 'public'
        AND tablename IN (
          'users', 'sessions', 'password_reset_tokens', 'orders', 'products',
          'custom_cake_orders', 'ai_cake_designs', 'admin_messages', 'contact_messages',
          'contact_message_replies', 'cake_gallery', 'product_categories', 'customers',
          'push_tokens', 'events', 'reviews', 'promotions', 'loyalty_rewards', 'business_settings',
          'order_idempotency'
        )
      ORDER BY tablename
    `;
    const got = (verify || []).map((r) => r.tablename);
    const missing = coreTables.filter((t) => !got.includes(t));
    if (missing.length) console.warn('Missing tables:', missing.join(', '));
    console.log(`Verified ${got.length}/${coreTables.length} core tables: ${got.join(', ')}`);
  } catch (err) {
    console.error('Error:', err.message);
    process.exit(1);
  }
}

main();
