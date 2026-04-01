/**
 * Send push notifications via Apple APNs (no Firebase).
 * Set in Vercel: APNS_KEY_ID, APNS_TEAM_ID, APNS_BUNDLE_ID, APNS_KEY_P8 (full .p8 file content).
 * For development use APNS_SANDBOX=true.
 */
import { ApnsClient, Notification } from 'apns2';
import { customerOrderStatusMessage } from './orderStatusCustomerMessage.js';
import { hasValidParcelTracking, isShippingFulfillmentType } from './shippingReadyTrackingRule.js';

/** True when Vercel has all required APNs auth env vars (pushes will not send until this is true). */
export function isApnsConfigured() {
  const keyP8 = process.env.APNS_KEY_P8;
  const keyId = process.env.APNS_KEY_ID;
  const teamId = process.env.APNS_TEAM_ID;
  const bundleId = process.env.APNS_BUNDLE_ID;
  return !!(keyP8 && keyId && teamId && bundleId);
}

function getClient() {
  const keyP8 = process.env.APNS_KEY_P8;
  const keyId = process.env.APNS_KEY_ID;
  const teamId = process.env.APNS_TEAM_ID;
  const bundleId = process.env.APNS_BUNDLE_ID;
  if (!keyP8 || !keyId || !teamId || !bundleId) return null;
  const signingKey = Buffer.from(keyP8, 'utf8');
  const sandbox = process.env.APNS_SANDBOX === 'true';
  return new ApnsClient({
    team: teamId,
    keyId,
    signingKey,
    defaultTopic: bundleId,
    host: sandbox ? 'api.sandbox.push.apple.com' : 'api.push.apple.com',
  });
}

let cachedClient = null;

/** Human-facing order code (matches app: GPT- + first 8 hex chars of UUID). */
export function orderDisplayCode(orderId) {
  if (!orderId) return '';
  const s = String(orderId).trim();
  const compact = s.replace(/-/g, '');
  const eight =
    compact.length >= 8
      ? compact.slice(0, 8).toUpperCase()
      : s.replace(/-/g, '').slice(0, 12).toUpperCase() || s;
  return `GPT-${eight}`;
}

/**
 * Send a push notification to one device token.
 * @param {string} deviceToken - Hex string (e.g. from iOS deviceToken)
 * @param {string} title - Alert title
 * @param {string} body - Alert body
 * @param {Record<string, string>} [data] - Custom payload (e.g. orderId)
 * @returns {Promise<boolean>} - true if sent, false if APNs not configured or send failed
 */
export async function sendPushNotification(deviceToken, title, body, data = {}) {
  const client = cachedClient ?? getClient();
  if (!client) {
    if (!isApnsConfigured()) {
      console.warn(
        '[APNs] Push skipped: set APNS_KEY_P8, APNS_KEY_ID, APNS_TEAM_ID, APNS_BUNDLE_ID on Vercel (optional: APNS_SANDBOX=true for dev). See GET /api/health → apnsConfigured.'
      );
    }
    return false;
  }
  cachedClient = client;
  try {
    const notification = new Notification(deviceToken, {
      alert: { title, body },
      sound: 'default',
      data: data,
    });
    await client.send(notification);
    return true;
  } catch (err) {
    console.error('APNs send error', err?.reason ?? err);
    return false;
  }
}

/**
 * Send "new order" push to multiple admin device tokens (fire-and-forget).
 */
export async function notifyNewOrder(deviceTokens, orderId, customerName, total) {
  if (!Array.isArray(deviceTokens) || deviceTokens.length === 0) return;
  const title = 'New order';
  const code = orderDisplayCode(orderId);
  const body = customerName
    ? `${customerName} · ${code} – $${Number(total).toFixed(2)}`
    : `${code} – $${Number(total).toFixed(2)}`;
  const data = { type: 'new_order', orderId: orderId || '' };
  const client = cachedClient ?? getClient();
  if (!client) return;
  cachedClient = client;
  const notifications = deviceTokens.map((token) =>
    new Notification(token, {
      alert: { title, body },
      sound: 'default',
      data,
    })
  );
  try {
    await client.sendMany(notifications);
  } catch (err) {
    console.error('APNs sendMany new order', err?.reason ?? err);
  }
}

/**
 * Send "order status update" push to the customer who placed the order.
 * @param {string|null|undefined} fulfillmentType — order row fulfillment_type (Pickup / Delivery / Shipping)
 * @param {{ messageOverride?: string }} [options] — e.g. delivery confirmed while DB status is Completed
 */
export async function notifyOrderStatusUpdate(deviceToken, orderId, status, fulfillmentType = null, options = {}) {
  if (!deviceToken) return false;
  const title = 'Order update';
  const body =
    options.messageOverride ?? customerOrderStatusMessage(status, fulfillmentType);
  const data = { type: 'order_status', orderId: orderId || '' };
  return sendPushNotification(deviceToken, title, body, data);
}

/**
 * Customer push when a shipping order first has carrier + tracking number saved (admin or webhook).
 * Uses `order_status` in the payload so the app opens the order like other order updates.
 */
export async function notifyTrackingNumberAvailable(deviceToken, orderId) {
  if (!deviceToken) return false;
  const title = 'Tracking available';
  const body = 'Your tracking number is now available. Tap to view your order.';
  const data = { type: 'order_status', orderId: orderId || '' };
  return sendPushNotification(deviceToken, title, body, data);
}

/**
 * Notify signed-in customer when parcel tracking becomes valid for the first time on a shipping order.
 * @param {boolean} hadValidBefore — true if carrier + number were already valid before this update
 */
export async function notifyCustomerTrackingNumberAvailable(
  sql,
  orderId,
  userId,
  fulfillmentType,
  hadValidBefore,
  carrier,
  number
) {
  if (!sql || !orderId || !userId) return;
  if (hadValidBefore) return;
  if (!isShippingFulfillmentType(fulfillmentType)) return;
  if (!hasValidParcelTracking(carrier, number)) return;
  try {
    const tokenRows = await sql`
      SELECT device_token FROM push_tokens
      WHERE user_id = ${userId}
        AND device_token IS NOT NULL AND TRIM(device_token) != ''
    `;
    if (!tokenRows?.length) return;
    for (const row of tokenRows) {
      if (row.device_token) {
        await notifyTrackingNumberAvailable(row.device_token, orderId);
      }
    }
  } catch (e) {
    console.warn('[APNs] tracking available push', e?.message ?? e);
  }
}

/**
 * Send "new message" push to owner(s) when a customer submits the contact form.
 */
export async function notifyNewMessage(deviceTokens, messageId, fromName, subjectOrPreview, orderId) {
  if (!Array.isArray(deviceTokens) || deviceTokens.length === 0) return;
  const title = 'New message';
  let body = fromName
    ? (subjectOrPreview ? `${fromName}: ${subjectOrPreview}` : fromName)
    : (subjectOrPreview || 'Customer sent you a message');
  const oid = orderId && String(orderId).trim() ? String(orderId).trim() : '';
  if (oid) body = `${body} · ${orderDisplayCode(oid)}`;
  const data = { type: 'new_message', messageId: messageId || '', orderId: oid };
  const client = cachedClient ?? getClient();
  if (!client) return;
  cachedClient = client;
  const notifications = deviceTokens.map((token) =>
    new Notification(token, {
      alert: { title, body },
      sound: 'default',
      data,
    })
  );
  try {
    await client.sendMany(notifications);
  } catch (err) {
    console.error('APNs sendMany new message', err?.reason ?? err);
  }
}

/**
 * Admin push when a customer requests a quote from the cake gallery (contact form with source gallery_quote).
 * Same `new_message` type so Admin → Messages opens the thread.
 */
export async function notifyGalleryQuoteRequest(deviceTokens, messageId, fromLine, designTitle) {
  if (!Array.isArray(deviceTokens) || deviceTokens.length === 0) return;
  const title = 'Gallery quote request';
  const nameOrEmail = fromLine && String(fromLine).trim() ? String(fromLine).trim() : 'Customer';
  const design = designTitle && String(designTitle).trim() ? String(designTitle).trim() : 'Gallery design';
  const body = `${nameOrEmail} — ${design}`;
  const data = {
    type: 'new_message',
    messageId: messageId || '',
    orderId: '',
    galleryQuote: '1',
  };
  const client = cachedClient ?? getClient();
  if (!client) return;
  cachedClient = client;
  const notifications = deviceTokens.map((token) =>
    new Notification(token, {
      alert: { title, body },
      sound: 'default',
      data,
    })
  );
  try {
    await client.sendMany(notifications);
  } catch (err) {
    console.error('APNs sendMany gallery quote', err?.reason ?? err);
  }
}

/**
 * Send "message from store" push to customer(s) when admin sends a message.
 */
export async function notifyAdminMessage(deviceTokens, adminMessageId, title, body) {
  if (!Array.isArray(deviceTokens) || deviceTokens.length === 0) return;
  const notifTitle = title || 'Message from store';
  const notifBody = (body && body.length > 80) ? body.slice(0, 77) + '...' : (body || 'You have a new message.');
  const data = { type: 'admin_message', messageId: adminMessageId || '' };
  const client = cachedClient ?? getClient();
  if (!client) return;
  cachedClient = client;
  const notifications = deviceTokens.map((token) =>
    new Notification(token, {
      alert: { title: notifTitle, body: notifBody },
      sound: 'default',
      data,
    })
  );
  try {
    await client.sendMany(notifications);
  } catch (err) {
    console.error('APNs sendMany admin message', err?.reason ?? err);
  }
}

/**
 * Send "new event" push to customers when admin creates an event.
 */
export async function notifyNewEvent(deviceTokens, eventId, title, subtitle) {
  if (!Array.isArray(deviceTokens) || deviceTokens.length === 0) return;
  const notifTitle = 'New event';
  const body = title ? (subtitle ? `${title} – ${subtitle}` : title) : (subtitle || 'Check out our new event');
  const data = { type: 'new_event', eventId: eventId || '' };
  const client = cachedClient ?? getClient();
  if (!client) return;
  cachedClient = client;
  const notifications = deviceTokens.map((token) =>
    new Notification(token, {
      alert: { title: notifTitle, body },
      sound: 'default',
      data,
    })
  );
  try {
    await client.sendMany(notifications);
  } catch (err) {
    console.error('APNs sendMany new event', err?.reason ?? err);
  }
}

/**
 * Customer push when admin replies on a contact thread (contact_message_replies).
 */
export async function notifyContactThreadReply(deviceTokens, contactMessageId, previewBody) {
  if (!Array.isArray(deviceTokens) || deviceTokens.length === 0) return;
  const client = cachedClient ?? getClient();
  if (!client) return;
  cachedClient = client;
  const title = 'Reply from the store';
  const raw = previewBody ? String(previewBody).trim() : '';
  const body = raw.length > 100 ? `${raw.slice(0, 97)}...` : (raw || 'Open Messages to read the reply.');
  const data = { type: 'contact_reply', messageId: contactMessageId || '' };
  const notifications = deviceTokens.map((token) =>
    new Notification(token, {
      alert: { title, body },
      sound: 'default',
      data,
    })
  );
  try {
    await client.sendMany(notifications);
  } catch (err) {
    console.error('APNs sendMany contact reply', err?.reason ?? err);
  }
}

/**
 * Admin push when a customer saves a new custom cake request.
 */
export async function notifyNewCustomCakeRequest(deviceTokens, customCakeOrderId, summary) {
  if (!Array.isArray(deviceTokens) || deviceTokens.length === 0) return;
  const client = cachedClient ?? getClient();
  if (!client) return;
  cachedClient = client;
  const title = 'New custom cake request';
  const body = summary ? String(summary).slice(0, 120) : 'A customer submitted a custom cake design.';
  const data = {
    type: 'new_custom_cake',
    customCakeOrderId: customCakeOrderId || '',
  };
  const notifications = deviceTokens.map((token) =>
    new Notification(token, {
      alert: { title, body },
      sound: 'default',
      data,
    })
  );
  try {
    await client.sendMany(notifications);
  } catch (err) {
    console.error('APNs sendMany custom cake', err?.reason ?? err);
  }
}

/**
 * Customer push when loyalty points are awarded on order completion.
 */
export async function notifyLoyaltyPointsEarned(deviceTokens, orderId, pointsAdded) {
  if (!Array.isArray(deviceTokens) || deviceTokens.length === 0) return;
  const client = cachedClient ?? getClient();
  if (!client) return;
  cachedClient = client;
  const pts = Number(pointsAdded);
  const title = 'Rewards';
  const body = Number.isFinite(pts) && pts > 0
    ? `You earned ${pts} point${pts === 1 ? '' : 's'}! Tap to view Rewards.`
    : 'You earned rewards points. Tap to view Rewards.';
  const data = {
    type: 'loyalty_points',
    orderId: orderId || '',
    points: String(Number.isFinite(pts) ? pts : 0),
  };
  const notifications = deviceTokens.map((token) =>
    new Notification(token, {
      alert: { title, body },
      sound: 'default',
      data,
    })
  );
  try {
    await client.sendMany(notifications);
  } catch (err) {
    console.error('APNs sendMany loyalty', err?.reason ?? err);
  }
}

/**
 * Admin push when a customer submits an order review.
 */
export async function notifyNewReview(deviceTokens, reviewId, orderId, rating) {
  if (!Array.isArray(deviceTokens) || deviceTokens.length === 0) return;
  const client = cachedClient ?? getClient();
  if (!client) return;
  cachedClient = client;
  const r = Number(rating);
  const n = Number.isFinite(r) ? Math.min(5, Math.max(1, Math.round(r))) : null;
  const title = 'New review';
  const starPart = n != null ? `${n} star${n === 1 ? '' : 's'}` : 'New rating';
  const body = `Order ${orderDisplayCode(orderId)} · ${starPart}. Tap to view Reviews.`;
  const data = {
    type: 'new_review',
    reviewId: reviewId || '',
    orderId: orderId || '',
    rating: n != null ? String(n) : '',
  };
  const notifications = deviceTokens.map((token) =>
    new Notification(token, {
      alert: { title, body },
      sound: 'default',
      data,
    })
  );
  try {
    await client.sendMany(notifications);
  } catch (err) {
    console.error('APNs sendMany new review', err?.reason ?? err);
  }
}

/**
 * Admin push when tracked stock crosses into "low" (matches app: stock ≤ threshold and stock &gt; 0).
 */
export async function notifyLowInventory(deviceTokens, productId, productName, stockQuantity, threshold) {
  if (!Array.isArray(deviceTokens) || deviceTokens.length === 0) return;
  const client = cachedClient ?? getClient();
  if (!client) return;
  cachedClient = client;
  const title = 'Low inventory';
  const name = productName ? String(productName).slice(0, 60) : 'A product';
  const body = `${name}: ${stockQuantity} in stock (alert at ≤ ${threshold}). Tap to view Inventory.`;
  const data = { type: 'low_inventory', productId: productId || '' };
  const notifications = deviceTokens.map(
    (token) =>
      new Notification(token, {
        alert: { title, body },
        sound: 'default',
        data,
      })
  );
  try {
    await client.sendMany(notifications);
  } catch (err) {
    console.error('APNs sendMany low inventory', err?.reason ?? err);
  }
}
