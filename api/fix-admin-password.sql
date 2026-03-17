-- Fix login: set a valid bcrypt hash so email/password sign-in works.
-- Run this once in Neon SQL Editor (Neon dashboard → SQL Editor).
--
-- After running, sign in with:
--   Email: ronellbradley@hotmail.com
--   Password: password1234
--
-- (If your admin email is different, change it in the WHERE clause below.)

UPDATE users
SET password_hash = '$2a$10$jcGh6c.LHDDyL7rzYjbJxOK1jA.1hw2cSCyJ0Ix0sbwfz0cEHt2bW'
WHERE LOWER(TRIM(email)) = 'ronellbradley@hotmail.com';

-- Verify: should return 1 row with has_password = yes
SELECT email, display_name,
       CASE WHEN password_hash IS NOT NULL AND password_hash LIKE '$2%' THEN 'yes' ELSE 'no' END AS has_password
FROM users
WHERE LOWER(TRIM(email)) = 'ronellbradley@hotmail.com';
