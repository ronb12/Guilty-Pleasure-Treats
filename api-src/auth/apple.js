import { sql, hasDb } from '../../api/lib/db.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';
import { createSession } from '../../api/lib/auth.js';
import jwt from 'jsonwebtoken';
import jwksClient from 'jwks-rsa';

const APPLE_KEYS_URL = 'https://appleid.apple.com/auth/keys';
const APPLE_ISSUER = 'https://appleid.apple.com';

const client = jwksClient({
  jwksUri: APPLE_KEYS_URL,
  cache: true,
  cacheMaxAge: 600000,
});

function getAppleSigningKey(header, callback) {
  client.getSigningKey(header.kid, (err, key) => {
    if (err) return callback(err);
    const cert = key?.getPublicKey();
    callback(null, cert);
  });
}

async function verifyAppleToken(identityToken, bundleId) {
  return new Promise((resolve, reject) => {
    const options = {
      algorithms: ['RS256'],
      issuer: APPLE_ISSUER,
      ...(bundleId && { audience: bundleId }),
    };
    jwt.verify(identityToken, getAppleSigningKey, options, (err, decoded) => {
      if (err) return reject(err);
      resolve(decoded);
    });
  });
}

export default async function handler(req, res) {
  setCors(res);
  if (req.method === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }
  if (!hasDb() || !sql) {
    return res.status(503).json({ error: 'Database not configured' });
  }

  const { identityToken, fullName } = req.body || {};
  if (!identityToken) {
    return res.status(400).json({ error: 'identityToken required' });
  }

  const bundleId = process.env.APPLE_BUNDLE_ID || 'com.bradleyvirtualsolutions.Guilty-Pleasure-Treats';

  let decoded;
  try {
    decoded = await verifyAppleToken(identityToken, bundleId);
  } catch (e) {
    return res.status(401).json({ error: 'Invalid Apple token' });
  }

  const appleId = decoded.sub;
  const email = decoded.email || null;

  let rows = await sql`SELECT id, email, display_name, is_admin, points FROM users WHERE apple_id = ${appleId} LIMIT 1`;
  let user = rows[0];

  if (!user) {
    const displayName = fullName ? [fullName.givenName, fullName.familyName].filter(Boolean).join(' ') : null;
    const isAdmin = process.env.OWNER_EMAILS?.split(',').map((e) => e.trim().toLowerCase()).includes((email || '').toLowerCase()) ?? false;
    rows = await sql`
      INSERT INTO users (email, display_name, apple_id, is_admin, points)
      VALUES (${email}, ${displayName || null}, ${appleId}, ${isAdmin}, 0)
      RETURNING id, email, display_name, is_admin, points
    `;
    user = rows[0];
  }

  if (!user) {
    return res.status(500).json({ error: 'Failed to create or find user' });
  }

  const session = await createSession(user.id);
  if (!session) {
    return res.status(500).json({ error: 'Failed to create session' });
  }

  res.status(200).json({
    token: String(session.id),
    user: {
      uid: user.id != null ? String(user.id) : user.id,
      email: user.email,
      displayName: user.display_name,
      isAdmin: user.is_admin,
      points: Number(user.points ?? 0),
    },
  });
}
