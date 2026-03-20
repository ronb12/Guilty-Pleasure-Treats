-- Standardize Apple account column to users.apple_sub.
-- Safe to run multiple times.

ALTER TABLE users ADD COLUMN IF NOT EXISTS apple_sub TEXT;

-- Backfill from legacy column when present.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'apple_id'
  ) THEN
    EXECUTE '
      UPDATE users
      SET apple_sub = apple_id
      WHERE apple_sub IS NULL
        AND apple_id IS NOT NULL
        AND BTRIM(apple_id) <> ''''
    ';
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_apple_sub
  ON users(apple_sub)
  WHERE apple_sub IS NOT NULL;

