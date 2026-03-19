/**
 * Server-authoritative loyalty earn: award points once when an order is marked completed.
 * Idempotent via orders.loyalty_points_awarded (NULL = never processed).
 *
 * Call only after the order row's status has been updated to completed for this request.
 * Matches prior client behavior: points = floor(total dollars), same as Swift Int(order.total).
 */

/**
 * @param {import('@neondatabase/serverless').NeonQueryFunction} sql
 * @param {string} orderId UUID string
 * @returns {Promise<{ userId: string, pointsAdded: number } | null>}
 */
export async function attemptAwardLoyaltyForCompletedOrder(sql, orderId) {
  const id = String(orderId ?? '').trim();
  if (!id) return null;

  try {
    const rows = await sql`
      WITH claimed AS (
        UPDATE orders
        SET
          loyalty_points_awarded = GREATEST(0, FLOOR(COALESCE(total, 0)::numeric))::int,
          updated_at = NOW()
        WHERE id = ${id}::uuid
          AND loyalty_points_awarded IS NULL
          AND user_id IS NOT NULL
          AND LOWER(TRIM(COALESCE(status, ''))) = 'completed'
        RETURNING user_id, loyalty_points_awarded AS pts
      )
      UPDATE users u
      SET
        points = COALESCE(u.points, 0) + c.pts,
        updated_at = NOW()
      FROM claimed c
      WHERE u.id = c.user_id AND c.pts > 0
      RETURNING u.id::text AS user_id, c.pts AS points_added
    `;
    const row = rows?.[0];
    if (row?.user_id != null && Number(row.points_added) > 0) {
      return { userId: String(row.user_id), pointsAdded: Number(row.points_added) };
    }
    return null;
  } catch (e) {
    console.error('[loyalty] attemptAwardLoyaltyForCompletedOrder', id, e?.message ?? e);
    throw e;
  }
}

/**
 * @param {unknown} statusFromRequest
 * @returns {boolean}
 */
export function requestSetsStatusToCompleted(statusFromRequest) {
  if (statusFromRequest == null) return false;
  return String(statusFromRequest).trim().toLowerCase() === 'completed';
}
