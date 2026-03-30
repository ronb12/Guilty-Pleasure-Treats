/**
 * Server-side promotion validation (matches client discount math).
 * Supports rewards-style rules: min subtotal, min item count, first-order-only,
 * optional product_id (discount applies only to matching line items).
 */

function normPid(v) {
  return String(v ?? '')
    .trim()
    .toLowerCase();
}

/** Sum price*qty and total qty for all lines; used when promo is not product-scoped. */
function sumFullCart(lineItems) {
  let sub = 0;
  let qty = 0;
  const arr = Array.isArray(lineItems) ? lineItems : [];
  for (const li of arr) {
    const price = Number(li?.price ?? 0);
    const q = Math.trunc(Number(li?.quantity ?? 0));
    if (!Number.isFinite(price) || !Number.isFinite(q) || q < 0) continue;
    sub += price * q;
    if (q > 0) qty += q;
  }
  return { subtotal: sub, quantity: qty };
}

/** Subtotal and quantity for lines whose productId matches row.product_id. */
function sumEligibleForProduct(row, lineItems) {
  const target = row.product_id != null && String(row.product_id).trim() !== '' ? normPid(row.product_id) : '';
  if (!target) return sumFullCart(lineItems);
  let sub = 0;
  let qty = 0;
  const arr = Array.isArray(lineItems) ? lineItems : [];
  for (const li of arr) {
    const pid = normPid(li?.productId ?? li?.product_id);
    if (pid !== target) continue;
    const price = Number(li?.price ?? 0);
    const q = Math.trunc(Number(li?.quantity ?? 0));
    if (!Number.isFinite(price) || !Number.isFinite(q) || q < 0) continue;
    sub += price * q;
    if (q > 0) qty += q;
  }
  return { subtotal: sub, quantity: qty };
}

function computeDiscountDollars(row, itemsSubtotalDollars) {
  const sub = Number(itemsSubtotalDollars);
  if (!Number.isFinite(sub) || sub < 0) return null;
  const type = String(row.discount_type ?? '').toLowerCase();
  const value = Number(row.value ?? 0);
  if (!Number.isFinite(value) || value < 0) return null;
  if (type === 'none' || type.includes('none')) {
    return 0;
  }
  if (type.includes('percent')) {
    return sub * (value / 100);
  }
  if (type.includes('fixed')) {
    return Math.min(value, sub);
  }
  return null;
}

/**
 * @param {object} row - promotion row from DB (snake_case fields ok)
 * @param {number} itemsSubtotalDollars - pre-discount cart subtotal
 * @param {object} [ctx]
 * @param {number} [ctx.totalQuantity] - sum of line item quantities (full cart; ignored when product-scoped)
 * @param {Array<{productId?:string,product_id?:string,price?:number,quantity?:number}>} [ctx.lineItems]
 * @param {string|null} [ctx.userId] - checkout user id when signed in
 * @param {number|null} [ctx.priorOrderCount] - completed/prior orders for user (required when first_order_only)
 * @returns {{ code: string, message: string }|null} null if eligible
 */
export function promotionEligibilityFailure(row, itemsSubtotalDollars, ctx = {}) {
  if (!row || !row.is_active) {
    return { code: 'INACTIVE', message: 'This promo is not active.' };
  }
  const now = new Date();
  if (row.valid_from && new Date(row.valid_from) > now) {
    return { code: 'NOT_STARTED', message: 'This promo is not active yet.' };
  }
  if (row.valid_to && new Date(row.valid_to) < now) {
    return { code: 'EXPIRED', message: 'This promo has expired.' };
  }

  const lineItems = ctx.lineItems;
  const scoped = row.product_id != null && String(row.product_id).trim() !== '';
  const eligible = scoped ? sumEligibleForProduct(row, lineItems) : sumFullCart(lineItems);
  const sub = scoped ? eligible.subtotal : Number(itemsSubtotalDollars);
  if (scoped && eligible.subtotal + 1e-9 <= 0) {
    return {
      code: 'PRODUCT_REQUIRED',
      message: 'Add the promoted product to your cart to use this code.',
    };
  }
  if (!Number.isFinite(sub) || sub < 0) {
    return { code: 'BAD_SUBTOTAL', message: 'Invalid cart subtotal.' };
  }

  const minSub = row.min_subtotal != null ? Number(row.min_subtotal) : null;
  if (minSub != null && Number.isFinite(minSub) && minSub > 0 && sub + 1e-9 < minSub) {
    return {
      code: 'MIN_SUBTOTAL',
      message: `This promo needs a minimum of $${minSub.toFixed(2)} for ${scoped ? 'that product' : 'your cart'} before discount (you have $${sub.toFixed(2)}).`,
    };
  }

  const minQty = row.min_total_quantity != null ? Number(row.min_total_quantity) : null;
  const totalQty = scoped
    ? eligible.quantity
    : ctx.totalQuantity != null
      ? Math.trunc(Number(ctx.totalQuantity))
      : sumFullCart(lineItems).quantity;
  if (minQty != null && Number.isFinite(minQty) && minQty > 0 && totalQty < minQty) {
    return {
      code: 'MIN_QUANTITY',
      message: scoped
        ? `This promo needs at least ${minQty} of that product in your cart (you have ${totalQty}).`
        : `This promo needs at least ${minQty} items in your cart (you have ${totalQty}).`,
    };
  }

  if (row.first_order_only) {
    const uid = ctx.userId != null ? String(ctx.userId).trim() : '';
    if (!uid) {
      return {
        code: 'SIGNIN_REQUIRED',
        message: 'Sign in with your account to use this first-order promo.',
      };
    }
    const prior = ctx.priorOrderCount;
    if (prior == null || !Number.isFinite(Number(prior))) {
      return {
        code: 'ELIGIBILITY_UNKNOWN',
        message: 'Could not verify first-order eligibility. Please try again.',
      };
    }
    if (Number(prior) > 0) {
      return {
        code: 'NOT_FIRST_ORDER',
        message: 'This promo is only for your first order.',
      };
    }
  }

  return null;
}

/**
 * Discount dollars or null if not eligible / invalid type.
 */
export function promotionRowToDiscount(row, itemsSubtotalDollars, ctx = {}) {
  if (promotionEligibilityFailure(row, itemsSubtotalDollars, ctx)) return null;
  const scoped = row.product_id != null && String(row.product_id).trim() !== '';
  const base = scoped ? sumEligibleForProduct(row, ctx.lineItems).subtotal : Number(itemsSubtotalDollars);
  return computeDiscountDollars(row, base);
}

/**
 * @returns {{ ok: true, discountDollars: number } | { ok: false, code: string, message: string }}
 */
export function evaluatePromotion(row, itemsSubtotalDollars, ctx = {}) {
  const fail = promotionEligibilityFailure(row, itemsSubtotalDollars, ctx);
  if (fail) return { ok: false, ...fail };
  const scoped = row.product_id != null && String(row.product_id).trim() !== '';
  const base = scoped ? sumEligibleForProduct(row, ctx.lineItems).subtotal : Number(itemsSubtotalDollars);
  const discountDollars = computeDiscountDollars(row, base);
  if (discountDollars == null) {
    return { ok: false, code: 'BAD_PROMO', message: 'Invalid or expired promo code.' };
  }
  return { ok: true, discountDollars };
}
