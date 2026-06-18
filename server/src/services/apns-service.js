const http2 = require('http2');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const http = require('http');
const tls = require('tls');
const url = require('url');

const PROD_HOST = 'https://api.push.apple.com';
const SANDBOX_HOST = 'https://api.sandbox.push.apple.com';
const JWT_TTL_MS = 50 * 60 * 1000; // 50 min (Apple max = 60 min)
const DEFAULT_TIMEOUT_MS = 15000;
const MAX_RETRY = 2;

// ==================== P8 Key Normalization ====================

function normalizeP8Key(key) {
  let k = key.trim();
  if (!k.includes('-----BEGIN PRIVATE KEY-----')) {
    k = k.replace(/-----BEGIN.*?-----/g, '').replace(/-----END.*?-----/g, '').replace(/\s/g, '');
    const lines = k.match(/.{1,64}/g) || [k];
    k = '-----BEGIN PRIVATE KEY-----\n' + lines.join('\n') + '\n-----END PRIVATE KEY-----';
  }
  return k;
}

// ==================== JWT Token Cache ====================

const tokenCache = new Map();

function getCachedToken(keyId, teamId, privateKey) {
  const cacheKey = `${keyId}:${teamId}`;
  const cached = tokenCache.get(cacheKey);
  if (cached && Date.now() - cached.createdAt < JWT_TTL_MS) {
    return cached.token;
  }
  const now = Math.floor(Date.now() / 1000);
  const normalizedKey = normalizeP8Key(privateKey);
  const token = jwt.sign(
    { iss: teamId, iat: now },
    normalizedKey,
    { algorithm: 'ES256', header: { alg: 'ES256', kid: keyId } }
  );
  tokenCache.set(cacheKey, { token, createdAt: Date.now() });
  return token;
}

function invalidateToken(keyId, teamId) {
  tokenCache.delete(`${keyId}:${teamId}`);
}

// ==================== HTTP/2 Connection Pool ====================

const connections = {};

function getProxyConfig() {
  const proxyUrl = process.env.HTTPS_PROXY || process.env.https_proxy || process.env.HTTP_PROXY || process.env.http_proxy;
  if (!proxyUrl) return null;
  const parsed = new url.URL(proxyUrl);
  return { host: parsed.hostname, port: parseInt(parsed.port, 10) };
}

function connectViaProxy(targetHost, targetPort, proxy) {
  return new Promise((resolve, reject) => {
    const req = http.request({
      host: proxy.host,
      port: proxy.port,
      method: 'CONNECT',
      path: `${targetHost}:${targetPort}`,
    });
    req.on('connect', (res, socket) => {
      if (res.statusCode !== 200) {
        socket.destroy();
        return reject(new Error(`Proxy CONNECT failed: ${res.statusCode}`));
      }
      const tlsSocket = tls.connect({
        host: targetHost,
        socket: socket,
        ALPNProtocols: ['h2'],
      }, () => resolve(tlsSocket));
      tlsSocket.on('error', reject);
    });
    req.on('error', reject);
    req.setTimeout(10000, () => { req.destroy(); reject(new Error('Proxy connect timeout')); });
    req.end();
  });
}

async function getConnection(host) {
  const existing = connections[host];
  if (existing && !existing.closed && !existing.destroyed) {
    return existing;
  }

  const parsed = new url.URL(host);
  const targetHost = parsed.hostname;
  const targetPort = parseInt(parsed.port, 10) || 443;
  const proxy = getProxyConfig();

  let client;
  if (proxy) {
    const tlsSocket = await connectViaProxy(targetHost, targetPort, proxy);
    client = http2.connect(host, { createConnection: () => tlsSocket });
    console.log(`[APNs] Connected to ${host} via proxy ${proxy.host}:${proxy.port}`);
  } else {
    client = http2.connect(host);
  }

  client.on('error', (err) => {
    console.error(`[APNs] Connection error (${host}):`, err.message);
    delete connections[host];
  });
  client.on('goaway', (errorCode) => {
    console.warn(`[APNs] GOAWAY received (${host}), code=${errorCode}. Reconnecting on next request.`);
    try { client.close(); } catch (_) {}
    delete connections[host];
  });
  client.on('close', () => {
    delete connections[host];
  });
  connections[host] = client;
  return client;
}

function closeAllConnections() {
  for (const host of Object.keys(connections)) {
    try { connections[host].close(); } catch (_) {}
    delete connections[host];
  }
}

function getConnectionStatus() {
  const result = {};
  for (const host of [PROD_HOST, SANDBOX_HOST]) {
    const conn = connections[host];
    result[host] = conn && !conn.closed && !conn.destroyed ? 'connected' : 'disconnected';
  }
  return result;
}

// ==================== Core Send via HTTP/2 ====================

async function sendRequest(host, path, headers, body, timeoutMs = DEFAULT_TIMEOUT_MS) {
  let client;
  try {
    client = await getConnection(host);
  } catch (err) {
    throw new Error(`Failed to connect to ${host}: ${err.message}`);
  }

  return new Promise((resolve, reject) => {
    let settled = false;
    const timer = setTimeout(() => {
      if (!settled) {
        settled = true;
        reject(new Error(`APNs request timed out after ${timeoutMs}ms`));
      }
    }, timeoutMs);

    const req = client.request({ ':method': 'POST', ':path': path, ...headers });

    let responseHeaders = {};
    let data = '';

    req.on('response', (h) => { responseHeaders = h; });
    req.on('data', (chunk) => { data += chunk; });
    req.on('end', () => {
      if (!settled) {
        settled = true;
        clearTimeout(timer);
        const status = responseHeaders[':status'];
        let parsedBody = null;
        if (data) {
          try { parsedBody = JSON.parse(data); } catch (_) { parsedBody = { raw: data }; }
        }
        resolve({ status, headers: responseHeaders, body: parsedBody });
      }
    });
    req.on('error', (err) => {
      if (!settled) {
        settled = true;
        clearTimeout(timer);
        delete connections[host];
        reject(err);
      }
    });

    req.write(JSON.stringify(body));
    req.end();
  });
}

// ==================== APNs Service ====================

class APNsService {
  /**
   * Send a push notification to a single device.
   *
   * @param {string} deviceToken - hex device token
   * @param {object} payload - APNs JSON payload ({ aps: { ... }, ... })
   * @param {object} options
   * @param {string} options.keyId
   * @param {string} options.teamId
   * @param {string} options.privateKey
   * @param {string} options.bundleId - apns-topic
   * @param {boolean} [options.sandbox=false]
   * @param {string} [options.pushType='alert'] - alert|background|voip|complication|fileprovider|mdm
   * @param {number} [options.priority=10] - 10|5|1
   * @param {number|string} [options.expiration='0'] - 0 = immediate, unix timestamp, or seconds
   * @param {string} [options.collapseId] - apns-collapse-id
   * @param {string} [options.apnsId] - apns-id (auto-generated if omitted)
   * @param {number} [options.timeoutMs=15000]
   * @returns {Promise<{status, body, apnsId, duration}>}
   */
  async send(deviceToken, payload, options = {}) {
    const {
      keyId, teamId, privateKey, bundleId,
      sandbox = false,
      pushType = 'alert',
      priority = 10,
      expiration = '0',
      collapseId,
      apnsId = uuidv4(),
      timeoutMs = DEFAULT_TIMEOUT_MS,
    } = options;

    if (!keyId || !teamId || !privateKey) {
      throw new Error('Missing APNs credentials (keyId, teamId, privateKey)');
    }
    if (!bundleId) {
      throw new Error('Missing bundleId (apns-topic)');
    }

    const token = getCachedToken(keyId, teamId, privateKey);
    const host = sandbox ? SANDBOX_HOST : PROD_HOST;

    const headers = {
      'authorization': `bearer ${token}`,
      'apns-topic': bundleId,
      'apns-push-type': pushType,
      'apns-priority': String(priority),
      'apns-expiration': String(expiration),
      'apns-id': apnsId,
    };
    if (collapseId) headers['apns-collapse-id'] = collapseId;

    const startTime = Date.now();
    let lastError;

    for (let attempt = 0; attempt <= MAX_RETRY; attempt++) {
      try {
        const result = await sendRequest(host, `/3/device/${deviceToken}`, headers, payload, timeoutMs);

        if (result.status === 403 && result.body?.reason === 'ExpiredProviderToken') {
          invalidateToken(keyId, teamId);
          const newToken = getCachedToken(keyId, teamId, privateKey);
          headers['authorization'] = `bearer ${newToken}`;
          continue;
        }

        if (result.status === 429) {
          const retryAfter = parseInt(result.headers['retry-after'] || '1', 10);
          if (attempt < MAX_RETRY) {
            await sleep(retryAfter * 1000);
            continue;
          }
        }

        return {
          status: result.status,
          body: result.body,
          apnsId,
          duration: Date.now() - startTime,
        };
      } catch (err) {
        lastError = err;
        if (attempt < MAX_RETRY) {
          await sleep(500 * (attempt + 1));
          continue;
        }
      }
    }

    throw lastError || new Error('APNs send failed after retries');
  }

  /**
   * Send push notifications to multiple devices in parallel batches.
   *
   * @param {Array<{device_token, sandbox?}>} devices
   * @param {object} payload
   * @param {object} options - same as send(), minus deviceToken/sandbox
   * @param {number} [concurrency=10]
   * @returns {Promise<{success, failed, unregistered, errors, duration}>}
   */
  async sendBatch(devices, payload, options = {}, concurrency = 10) {
    const results = { success: 0, failed: 0, unregistered: 0, errors: [] };
    const startTime = Date.now();

    for (let i = 0; i < devices.length; i += concurrency) {
      const batch = devices.slice(i, i + concurrency);
      await Promise.all(batch.map(async (device) => {
        try {
          const r = await this.send(device.device_token, payload, {
            ...options,
            sandbox: device.sandbox ?? options.sandbox ?? false,
          });
          if (r.status === 200) {
            results.success++;
          } else if (r.status === 410) {
            results.unregistered++;
          } else {
            results.failed++;
            results.errors.push({
              token: device.device_token.substring(0, 8) + '...',
              reason: r.body?.reason || `HTTP ${r.status}`,
            });
          }
          return r;
        } catch (e) {
          results.failed++;
          results.errors.push({
            token: device.device_token.substring(0, 8) + '...',
            reason: e.message,
          });
          return null;
        }
      }));
    }

    results.duration = Date.now() - startTime;
    return results;
  }

  /**
   * Build a standard APNs payload.
   */
  static buildPayload({
    title, body, badge, sound = 'default',
    mutableContent, threadId, collapseId,
    interruptionLevel, relevanceScore,
    customData = {},
  }) {
    const aps = {};

    if (title || body) {
      aps.alert = {};
      if (title) aps.alert.title = title;
      if (body) aps.alert.body = body;
    }
    if (sound) aps.sound = sound;
    if (badge !== undefined && badge !== null) aps.badge = Number(badge);
    if (mutableContent) aps['mutable-content'] = 1;
    if (threadId) aps['thread-id'] = threadId;
    if (interruptionLevel) aps['interruption-level'] = interruptionLevel;
    if (relevanceScore !== undefined) aps['relevance-score'] = Number(relevanceScore);

    return { aps, ...customData };
  }

  getConnectionStatus() {
    return getConnectionStatus();
  }

  close() {
    closeAllConnections();
    tokenCache.clear();
  }
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// ==================== Convenience: send push to a user's devices ====================

const apnsInstance = new APNsService();

async function sendPushToUser(userId, title, body, customData = {}) {
  try {
    const { getDb } = require('../config/database');
    const { decrypt } = require('./encryption');
    const db = getDb();

    const key = await db.prepare('SELECT * FROM push_keys ORDER BY created_at DESC LIMIT 1').get();
    if (!key) {
      console.log('[Push] No push key configured, skipping notification');
      return;
    }

    const devices = await db.prepare(
      'SELECT device_token, sandbox FROM push_devices WHERE user_id = ?'
    ).all(userId);

    if (!devices.length) {
      console.log(`[Push] No devices registered for user ${userId}`);
      return;
    }

    const bundleId = key.bundle_ids ? key.bundle_ids.split(',')[0].trim() : 'com.certvault.app';
    const privateKey = decrypt(key.private_key);
    const payload = APNsService.buildPayload({ title, body, customData });

    const results = await apnsInstance.sendBatch(devices, payload, {
      keyId: key.key_id,
      teamId: key.team_id,
      privateKey,
      bundleId,
    }, 5);

    console.log(`[Push] Sent "${title}" to ${devices.length} device(s) for user ${userId}: ${results.success} ok, ${results.failed} failed`);

    if (results.unregistered > 0) {
      const unreg = await db.prepare(
        'SELECT device_token FROM push_devices WHERE user_id = ?'
      ).all(userId);
      for (const d of unreg) {
        try {
          const r = await apnsInstance.send(d.device_token, { aps: { 'content-available': 1 } }, {
            keyId: key.key_id, teamId: key.team_id, privateKey, bundleId,
            sandbox: d.sandbox ?? false, pushType: 'background', priority: 5,
          });
          if (r.status === 410) {
            await db.prepare('DELETE FROM push_devices WHERE device_token = ?').run(d.device_token);
            console.log(`[Push] Removed unregistered token ${d.device_token.substring(0, 8)}...`);
          }
        } catch (_) {}
      }
    }

    return results;
  } catch (err) {
    console.error('[Push] sendPushToUser error:', err.message);
  }
}

module.exports = {
  APNsService,
  normalizeP8Key,
  apnsService: apnsInstance,
  sendPushToUser,
};
