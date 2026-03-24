/**
 * GET /api/users/me — current user profile (auth required).
 * PATCH /api/users/me — update displayName; addPoints / redeemPoints; admin may addPoints with targetUserId.
 */
import { sql, hasDb } from '../../api/lib/db.js';
import { getTokenFromRequest, getSession } from '../../api/lib/auth.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';
import { ensureLoyaltyRewardsTable } from '../lib/loyaltyRewardsSchema.js';

function userResponse(row) {
  if (!row) return null;
  return {
    uid: row.id?.toString?.() ?? String(row.id),
    email: row.email ?? null,
    displayName: row.display_name ?? null,
    phone: row.phone ?? null,
    isAdmin: Boolean(row.is_admin),
    points: Number(row.points ?? 0),
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
  };
}

export default async function handler(req, res) {
  setCors(res);
  if ((req.method || '').toUpperCase() === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  res.setHeader('Content-Type', 'application/json');

  const token = getTokenFromRequest(req);
  const session = token ? await getSession(token) : null;
  if (!session?.userId) return res.status(401).json({ error: 'Unauthorized' });
  if (!hasDb() || !sql) return res.status(503).json({ error: 'Service unavailable' });

  const sessionUserId = String(session.userId);

  if ((req.method || '').toUpperCase() === 'GET') {
    try {
      const [row] = await sql`
        SELECT id, email, display_name, phone, is_admin, points, created_at
        FROM users WHERE id::text = ${sessionUserId} LIMIT 1
      `;
      if (!row) return res.status(404).json({ error: 'User not found' });
      let completedOrderCount = 0;
      try {
        const [cnt] = await sql`
          SELECT COUNT(*)::int AS c FROM orders WHERE user_id::text = ${sessionUserId}
        `;
        completedOrderCount = Number(cnt?.c ?? 0);
      } catch (e) {
        if (e?.code !== '42P01') console.error('[users/me] order count', e);
      }
      return res.status(200).json({ ...userResponse(row), completedOrderCount });
    } catch (err) {
      console.error('[users/me] GET', err);
      return res.status(500).json({ error: 'Failed to load profile' });
    }
  }

  if ((req.method || '').toUpperCase() === 'PATCH') {
    const body = req.body || {};
    try {
      let targetId = sessionUserId;
      const addPoints = body.addPoints != null ? Number(body.addPoints) : null;
      const redeemPoints = body.redeemPoints != null ? Number(body.redeemPoints) : null;
      const redeemLoyaltyRewardIdRaw = body.redeemLoyaltyRewardId ?? body.redeem_loyalty_reward_id;
      const redeemLoyaltyRewardId = redeemLoyaltyRewardIdRaw != null && String(redeemLoyaltyRewardIdRaw).trim() !== ''
        ? String(redeemLoyaltyRewardIdRaw).trim()
        : null;
      const targetUserId = body.targetUserId != null ? String(body.targetUserId).trim() : null;

      if (addPoints != null && addPoints > 0 && targetUserId && session.isAdmin === true) {
        targetId = targetUserId;
      }

      const [current] = await sql`
        SELECT id, email, display_name, phone, is_admin, points, created_at FROM users WHERE id::text = ${targetId} LIMIT 1
      `;
      if (!current) return res.status(404).json({ error: 'User not found' });

      let nextPoints = Number(current.points ?? 0);
      let nextDisplay = current.display_name;
      let nextPhone = current.phone;

      if (body.displayName !== undefined && targetId === sessionUserId) {
        nextDisplay = body.displayName == null ? null : String(body.displayName).trim() || null;
      }

      if (body.phone !== undefined && targetId === sessionUserId) {
        nextPhone = body.phone == null || body.phone === '' ? null : String(body.phone).trim();
      }

      if (redeemLoyaltyRewardId && redeemPoints != null && redeemPoints > 0) {
        return res.status(400).json({ error: 'Use either redeemLoyaltyRewardId or redeemPoints' });
      }

      if (addPoints != null && addPoints > 0) {
        if (targetId !== sessionUserId && session.isAdmin !== true) {
          return res.status(403).json({ error: 'Forbidden' });
        }
        nextPoints += addPoints;
      }

      if (redeemLoyaltyRewardId) {
        if (targetId !== sessionUserId) return res.status(403).json({ error: 'Forbidden' });
        try {
          await ensureLoyaltyRewardsTable(sql);
          const [rw] = await sql`
            SELECT id, points_required FROM loyalty_rewards
            WHERE id = ${redeemLoyaltyRewardId}::uuid AND is_active = true
            LIMIT 1
          `;
          if (!rw) return res.status(400).json({ error: 'Invalid or inactive reward' });
          const cost = Number(rw.points_required);
          if (nextPoints < cost) return res.status(400).json({ error: 'Not enough points' });
          nextPoints -= cost;
        } catch (e) {
          if (e?.code === '22P02') return res.status(400).json({ error: 'Invalid reward id' });
          throw e;
        }
      } else if (redeemPoints != null && redeemPoints > 0) {
        if (targetId !== sessionUserId) return res.status(403).json({ error: 'Forbidden' });
        if (nextPoints < redeemPoints) return res.status(400).json({ error: 'Not enough points' });
        nextPoints -= redeemPoints;
      }

      const [row] = await sql`
        UPDATE users
        SET display_name = ${nextDisplay}, phone = ${nextPhone}, points = ${nextPoints}, updated_at = NOW()
        WHERE id::text = ${targetId}
        RETURNING id, email, display_name, phone, is_admin, points, created_at
      `;
      return res.status(200).json(userResponse(row));
    } catch (err) {
      console.error('[users/me] PATCH', err);
      return res.status(500).json({ error: 'Update failed' });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
}
