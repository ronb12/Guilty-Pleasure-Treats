-- Run this in Neon SQL Editor to verify your login user.
-- Replace the email below with yours if different.

-- 1) See if your user exists and has a password set
SELECT id, email, display_name,
       CASE WHEN password_hash IS NOT NULL THEN 'yes' ELSE 'no' END AS has_password,
       CASE WHEN apple_id IS NOT NULL THEN 'yes' ELSE 'no' END AS has_apple
FROM users
WHERE LOWER(TRIM(email)) = 'ronellbradley@hotmail.com';

-- 2) If the row exists but has_password = 'no', set a password (use your own):
-- First generate a bcrypt hash for "password1234" (run in Node: require('bcryptjs').hash('password1234', 10).then(console.log))
-- Then run:
-- UPDATE users SET password_hash = '$2a$10$YOUR_HASH_HERE' WHERE LOWER(TRIM(email)) = 'ronellbradley@hotmail.com';
