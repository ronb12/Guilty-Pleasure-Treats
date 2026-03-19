#!/usr/bin/env node
/**
 * Create all tables that APIs expect but may be missing in Neon (contact, gallery, categories, customers, push).
 * Run once after schema.sql or when you see "relation does not exist" errors.
 * Usage: node --env-file=.env.neon scripts/run-missing-tables.js
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
    await sql`CREATE INDEX IF NOT EXISTS idx_product_categories_display_order ON product_categories(display_order ASC, name ASC)`;
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
    await sql`CREATE INDEX IF NOT EXISTS idx_events_start_at ON events(start_at ASC) WHERE start_at IS NOT NULL`;
    console.log('events OK');

    // reviews (customer reviews)
    await sql`
      CREATE TABLE IF NOT EXISTS reviews (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        author_name TEXT,
        rating INT CHECK (rating >= 1 AND rating <= 5),
        text TEXT,
        product_id TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW()
      )
    `;
    await sql`CREATE INDEX IF NOT EXISTS idx_reviews_created_at ON reviews(created_at DESC)`;
    console.log('reviews OK');

    console.log('\nAll missing tables are ready.');
  } catch (err) {
    console.error('Error:', err.message);
    process.exit(1);
  }
}

main();
