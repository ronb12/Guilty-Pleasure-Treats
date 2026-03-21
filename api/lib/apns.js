/**
 * Send push notifications via Apple APNs (no Firebase).
 * Set in Vercel: APNS_KEY_ID, APNS_TEAM_ID, APNS_BUNDLE_ID, APNS_KEY_P8 (full .p8 file content).
 * For development use APNS_SANDBOX=true.
 */
import { ApnsClient, Notification } from 'apns2';

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
 */
export async function notifyOrderStatusUpdate(deviceToken, orderId, status) {
  if (!deviceToken) return false;
  const statusText = String(status || 'updated').replace(/_/g, ' ');
  const title = 'Order update';
  const body = `Your order is now: ${statusText}. Tap to view.`;
  const data = { type: 'order_status', orderId: orderId || '' };
  return sendPushNotification(deviceToken, title, body, data);
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
