/**
 * If tracking status text looks like a final delivery, mark Shipping orders Completed
 * (loyalty + APNs same as manual completion). No-op for pickup/delivery/cancelled/already done.
 */

import { attemptAwardLoyaltyForCompletedOrder } from './awardLoyaltyOnOrderCompleted.js';

/** @param {unknown} detail */
export function trackingDetailIndicatesDelivered(detail) {
  const s = String(detail ?? '').trim().toLowerCase();
  if (!s) return false;

  // Reject clear non-termination states even if "deliver" appears somewhere.
  const hardNo =
    /\bnot\s+delivered\b|attempted delivery|delivery attempted|unable to deliver|returned to sender|returning to sender|out for delivery|failed delivery|delivery failed|delivery exception|cancelled shipment/i;
  if (hardNo.test(s)) return false;

  if (/\bdelivered\b/.test(s)) return true;
  if (s.includes('delivery complete')) return true;
  return false;
}

/**
 * @param {import('@neondatabase/serverless').NeonQueryFunction} sql
 * @param {string} orderId
 * @param {string | null | undefined} mergedTrackingDetail - value after PATCH/webhook merge
 * @returns {Promise<{ completed: boolean }>}
 */
export async function completeShippingOrderIfTrackingDelivered(sql, orderId, mergedTrackingDetail) {
  if (!trackingDetailIndicatesDelivered(mergedTrackingDetail)) {
    return { completed: false };
  }
  const oid = String(orderId ?? '').trim();
  if (!oid) return { completed: false };

  let updatedRows;
  try {
    updatedRows = await sql`
      UPDATE orders SET status = 'Completed', updated_at = NOW()
      WHERE id = ${oid}
        AND LOWER(TRIM(COALESCE(fulfillment_type, ''))) = 'shipping'
        AND LOWER(TRIM(COALESCE(status, ''))) NOT IN ('completed', 'cancelled')
      RETURNING id, user_id
    `;
  } catch (e) {
    console.error('[tracking-delivered] status update', oid, e?.message ?? e);
    throw e;
  }

  const row = updatedRows?.[0];
  if (!row) return { completed: false };

  let loyaltyAward = null;
  try {
    loyaltyAward = await attemptAwardLoyaltyForCompletedOrder(sql, oid);
  } catch (e) {
    console.error('[tracking-delivered] loyalty', e?.message ?? e);
  }

  const userId = row.user_id;
  if (userId) {
    try {
      const tokenRows = await sql`
        SELECT device_token FROM push_tokens
        WHERE user_id = ${userId} AND device_token IS NOT NULL AND TRIM(device_token) != ''
      `;
      if (tokenRows?.length) {
        const { notifyOrderStatusUpdate } = await import('./apns.js');
        for (const t of tokenRows) {
          if (t.device_token) await notifyOrderStatusUpdate(t.device_token, oid, 'Completed');
        }
      }
    } catch (e) {
      console.warn('[tracking-delivered] order status push', e?.message ?? e);
    }
  }

  if (loyaltyAward?.userId && Number(loyaltyAward.pointsAdded) > 0) {
    try {
      const { isApnsConfigured, notifyLoyaltyPointsEarned } = await import('./apns.js');
      if (isApnsConfigured()) {
        const uid = String(loyaltyAward.userId);
        const tokenRows = await sql`
          SELECT device_token FROM push_tokens
          WHERE (user_id)::text = ${uid}
            AND device_token IS NOT NULL AND TRIM(device_token) != ''
        `;
        const tokens = (tokenRows || []).map((r) => r.device_token).filter(Boolean);
        if (tokens.length) {
          await notifyLoyaltyPointsEarned(tokens, oid, loyaltyAward.pointsAdded);
        }
      }
    } catch (e) {
      console.warn('[tracking-delivered] loyalty push', e?.message ?? e);
    }
  }

  return { completed: true };
}
