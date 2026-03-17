-- Seed admin user so you can log in to the admin area.
-- Email: ronellbradley@hotmail.com  |  Password: password1234
-- Run this once in Neon SQL Editor (Vercel → Storage → Neon → SQL Editor).

INSERT INTO users (email, display_name, password_hash, is_admin, points)
VALUES ('ronellbradley@hotmail.com', 'Admin', '$2a$10$VP4L4AQbuRnlfjvMQf0jpuKaeX4Zf4k0YR5CVYN7E2t6n1D0il2Xi', true, 0)
ON CONFLICT (email) DO UPDATE SET
  password_hash = EXCLUDED.password_hash,
  is_admin = true,
  display_name = COALESCE(EXCLUDED.display_name, users.display_name);
