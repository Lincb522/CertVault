const http2 = require('http2');
const jwt = require('jsonwebtoken');
const { getDb } = require('../config/database');
const { decrypt } = require('./encryption');

function normalizeP8Key(key) {
  let k = key.trim();
  if (!k.includes('-----BEGIN PRIVATE KEY-----')) {
    k = k.replace(/-----BEGIN.*?-----/g, '').replace(/-----END.*?-----/g, '').replace(/\s/g, '');
    const lines = k.match(/.{1,64}/g) || [k];
    k = '-----BEGIN PRIVATE KEY-----\n' + lines.join('\n') + '\n-----END PRIVATE KEY-----';
  }
  return k;
}

function generateAPNsToken(keyId, teamId, privateKey) {
  const now = Math.floor(Date.now() / 1000);
  const normalizedKey = normalizeP8Key(privateKey);
  return jwt.sign(
    { iss: teamId, iat: now },
    normalizedKey,
    { algorithm: 'ES256', header: { alg: 'ES256', kid: keyId } }
  );
}

function sendViaHTTP2(host, path, headers, body) {
  return new Promise((resolve, reject) => {
    const client = http2.connect(host);
    client.on('error', reject);
    const req = client.request({ ':method': 'POST', ':path': path, ...headers });
    let responseHeaders = {};
    let data = '';
    req.on('response', (h) => { responseHeaders = h; });
    req.on('data', (chunk) => { data += chunk; });
    req.on('end', () => {
      client.close();
      const status = responseHeaders[':status'];
      resolve({ status, body: data ? JSON.parse(data) : null });
    });
    req.on('error', reject);
    req.write(JSON.stringify(body));
    req.end();
  });
}

async function getActivePushKey() {
  const db = getDb();
  const key = await db.prepare('SELECT * FROM push_keys ORDER BY created_at DESC LIMIT 1').get();
  if (!key) return null;
  return {
    keyId: key.key_id,
    teamId: key.team_id,
    privateKey: decrypt(key.private_key),
    bundleIds: key.bundle_ids,
  };
}

async function sendPushToUser(userId, title, body, customData = {}) {
  try {
    const pushKey = await getActivePushKey();
    if (!pushKey) {
      console.log('[Push] No push key configured, skipping notification');
      return;
    }

    const db = getDb();
    const devices = await db.prepare(
      'SELECT device_token FROM push_devices WHERE user_id = ?'
    ).all(userId);

    if (!devices.length) {
      console.log(`[Push] No devices registered for user ${userId}`);
      return;
    }

    const bundleId = pushKey.bundleIds ? pushKey.bundleIds.split(',')[0].trim() : 'com.certvault.app';
    const token = generateAPNsToken(pushKey.keyId, pushKey.teamId, pushKey.privateKey);
    const host = process.env.APNS_SANDBOX === 'false'
      ? 'https://api.push.apple.com'
      : 'https://api.sandbox.push.apple.com';

    const payload = {
      aps: {
        alert: { title, body: body || '' },
        sound: 'default',
      },
      ...customData,
    };

    const results = [];
    for (const device of devices) {
      try {
        const result = await sendViaHTTP2(
          host,
          `/3/device/${device.device_token}`,
          {
            'authorization': `bearer ${token}`,
            'apns-topic': bundleId,
            'apns-push-type': 'alert',
            'apns-priority': '10',
            'apns-expiration': '0',
          },
          payload
        );
        results.push({ token: device.device_token.substring(0, 8), status: result.status });

        if (result.status === 410) {
          await db.prepare('DELETE FROM push_devices WHERE device_token = ?').run(device.device_token);
          console.log(`[Push] Removed unregistered token ${device.device_token.substring(0, 8)}...`);
        }
      } catch (e) {
        console.error(`[Push] Failed to send to ${device.device_token.substring(0, 8)}...:`, e.message);
      }
    }

    console.log(`[Push] Sent "${title}" to ${results.length} device(s) for user ${userId}`);
    return results;
  } catch (err) {
    console.error('[Push] sendPushToUser error:', err.message);
  }
}

module.exports = { sendPushToUser };
