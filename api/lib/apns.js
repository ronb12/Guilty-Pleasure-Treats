/**
 * Send push notifications via Apple APNs (no Firebase).
 * Set in Vercel: APNS_KEY_ID, APNS_TEAM_ID, APNS_BUNDLE_ID, APNS_KEY_P8 (full .p8 file content).
 * For development use APNS_SANDBOX=true.
 */
import { ApnsClient, Notification } from 'apns2';

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
    console.warn('APNs not configured (APNS_KEY_P8, APNS_KEY_ID, APNS_TEAM_ID, APNS_BUNDLE_ID)');
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
  const body = customerName
    ? `${customerName} – $${Number(total).toFixed(2)}`
    : `Order #${(orderId || '').slice(-8)} – $${Number(total).toFixed(2)}`;
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
export async function notifyNewMessage(deviceTokens, messageId, fromName, subjectOrPreview) {
  if (!Array.isArray(deviceTokens) || deviceTokens.length === 0) return;
  const title = 'New message';
  const body = fromName
    ? (subjectOrPreview ? `${fromName}: ${subjectOrPreview}` : fromName)
    : (subjectOrPreview || 'Customer sent you a message');
  const data = { type: 'new_message', messageId: messageId || '' };
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
