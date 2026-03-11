const express = require('express');
const http2 = require('http2');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const router = express.Router();
const { getDb } = require('../config/database');
const { getDecryptedAccount, checkAccountOwnership } = require('../services/account-helper');
const { decrypt } = require('../services/encryption');

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
      resolve({ status, headers: responseHeaders, body: data ? JSON.parse(data) : null });
    });
    req.on('error', reject);

    req.write(JSON.stringify(body));
    req.end();
  });
}

router.post('/send', async (req, res, next) => {
  try {
    const {
      account_id,
      device_token,
      title,
      body: messageBody,
      badge,
      sound = 'default',
      bundle_id,
      sandbox = true,
      custom_data = {},
    } = req.body;

    if (!device_token || !title || !bundle_id) {
      return res.status(400).json({ success: false, message: '请填写 device_token、title 和 bundle_id' });
    }

    let keyId, teamId, privateKey;
    const db = getDb();

    if (req.body.push_key_id) {
      const pk = await db.prepare('SELECT * FROM push_keys WHERE id = ?').get(req.body.push_key_id);
      if (!pk) return res.status(404).json({ success: false, message: '推送密钥不存在' });
      if (pk.user_id && pk.user_id !== req.user.id && req.user.role !== 'superadmin') {
        return res.status(403).json({ success: false, message: '无权操作此推送密钥' });
      }
      keyId = pk.key_id;
      teamId = pk.team_id;
      privateKey = decrypt(pk.private_key);
    } else if (account_id) {
      const allowed = await checkAccountOwnership(account_id, req.user);
      if (!allowed) {
        return res.status(403).json({ success: false, message: '无权操作此账号' });
      }
      let account;
      try { account = await getDecryptedAccount(account_id); } catch (e) { if (e.status === 404) return res.status(404).json({ success: false, message: '账号不存在' }); throw e; }
      keyId = account.key_id;
      privateKey = account.private_key;
      teamId = req.body.team_id;
      if (!teamId) {
        return res.status(400).json({
          success: false,
          message: '使用账号的 .p8 Key 发送推送时需要提供 team_id (Apple Developer Team ID)'
        });
      }
    } else if (req.body.key_id && req.body.team_id && req.body.private_key) {
      keyId = req.body.key_id;
      teamId = req.body.team_id;
      privateKey = req.body.private_key;
    } else {
      return res.status(400).json({
        success: false,
        message: '请提供 account_id 或手动填写 key_id + team_id + private_key'
      });
    }

    console.log(`[Push /send] keyId=${keyId} teamId=${teamId} keyLen=${privateKey?.length || 0}`);

    let token;
    try {
      token = generateAPNsToken(keyId, teamId, privateKey);
    } catch (signErr) {
      return res.status(400).json({
        success: false,
        message: `JWT 签名失败: ${signErr.message}。请检查 Key ID、Team ID 和私钥是否正确。`
      });
    }

    const host = sandbox
      ? 'https://api.sandbox.push.apple.com'
      : 'https://api.push.apple.com';

    const payload = {
      aps: {
        alert: { title, body: messageBody || '' },
        sound,
      },
      ...custom_data,
    };
    if (badge !== undefined && badge !== null) {
      payload.aps.badge = Number(badge);
    }

    const apnsId = uuidv4();

    const result = await sendViaHTTP2(
      host,
      `/3/device/${device_token}`,
      {
        'authorization': `bearer ${token}`,
        'apns-topic': bundle_id,
        'apns-push-type': 'alert',
        'apns-id': apnsId,
        'apns-priority': '10',
        'apns-expiration': '0',
      },
      payload
    );

    if (result.status === 200) {
      res.json({ success: true, message: '推送发送成功', data: { apns_id: apnsId, status: result.status } });
    } else {
      res.json({
        success: false,
        message: `推送失败: ${result.body?.reason || '未知错误'}`,
        data: { status: result.status, reason: result.body?.reason, apns_id: apnsId }
      });
    }
  } catch (err) {
    next(err);
  }
});

// Register device token for push notifications
router.post('/register-device', async (req, res, next) => {
  try {
    const { device_token, platform = 'ios' } = req.body;
    if (!device_token) {
      return res.status(400).json({ success: false, message: '缺少 device_token' });
    }

    const db = getDb();
    const existing = await db.prepare(
      'SELECT id FROM push_devices WHERE device_token = ?'
    ).get(device_token);

    if (existing) {
      await db.prepare(
        'UPDATE push_devices SET user_id = ?, platform = ?, created_at = NOW() WHERE device_token = ?'
      ).run(req.user.id, platform, device_token);
    } else {
      await db.prepare(
        'INSERT INTO push_devices (user_id, device_token, platform) VALUES (?, ?, ?)'
      ).run(req.user.id, device_token, platform);
    }

    res.json({ success: true, message: '设备 Token 注册成功' });
  } catch (err) {
    next(err);
  }
});

// Unregister device token
router.delete('/unregister-device', async (req, res, next) => {
  try {
    const { device_token } = req.body;
    if (!device_token) {
      return res.status(400).json({ success: false, message: '缺少 device_token' });
    }

    const db = getDb();
    await db.prepare(
      'DELETE FROM push_devices WHERE device_token = ? AND user_id = ?'
    ).run(device_token, req.user.id);

    res.json({ success: true, message: '设备 Token 注销成功' });
  } catch (err) {
    next(err);
  }
});

router.get('/devices', async (req, res, next) => {
  try {
    const db = getDb();
    const devices = await db.prepare(
      `SELECT pd.id, pd.device_token, pd.platform, pd.created_at, u.username
       FROM push_devices pd
       LEFT JOIN users u ON pd.user_id = u.id
       ORDER BY pd.created_at DESC`
    ).all();
    res.json({ success: true, data: devices, total: devices.length });
  } catch (err) {
    next(err);
  }
});

router.post('/broadcast', async (req, res, next) => {
  try {
    const {
      title,
      body: messageBody,
      badge,
      sound = 'default',
      bundle_id,
      sandbox = true,
      custom_data = {},
    } = req.body;

    if (!title || !bundle_id) {
      return res.status(400).json({ success: false, message: '请填写标题和 Bundle ID' });
    }

    let keyId, teamId, privateKey;
    const db = getDb();

    if (req.body.push_key_id) {
      const pk = await db.prepare('SELECT * FROM push_keys WHERE id = ?').get(req.body.push_key_id);
      if (!pk) return res.status(404).json({ success: false, message: '推送密钥不存在' });
      keyId = pk.key_id;
      teamId = pk.team_id;
      privateKey = decrypt(pk.private_key);
    } else if (req.body.account_id) {
      const allowed = await checkAccountOwnership(req.body.account_id, req.user);
      if (!allowed) return res.status(403).json({ success: false, message: '无权操作此账号' });
      let account;
      try { account = await getDecryptedAccount(req.body.account_id); } catch (e) { if (e.status === 404) return res.status(404).json({ success: false, message: '账号不存在' }); throw e; }
      keyId = account.key_id;
      privateKey = account.private_key;
      teamId = req.body.team_id;
      if (!teamId) return res.status(400).json({ success: false, message: '请提供 Team ID' });
    } else {
      return res.status(400).json({ success: false, message: '请提供推送密钥或账号' });
    }

    const devices = await db.prepare('SELECT device_token FROM push_devices').all();
    if (!devices.length) {
      return res.json({ success: false, message: '没有已注册的设备，无法广播' });
    }

    let token;
    try {
      token = generateAPNsToken(keyId, teamId, privateKey);
    } catch (signErr) {
      return res.status(400).json({ success: false, message: `JWT 签名失败: ${signErr.message}` });
    }

    const host = sandbox
      ? 'https://api.sandbox.push.apple.com'
      : 'https://api.push.apple.com';

    const payload = {
      aps: { alert: { title, body: messageBody || '' }, sound },
      ...custom_data,
    };
    if (badge !== undefined && badge !== null) payload.aps.badge = Number(badge);

    const CONCURRENCY = 10;
    const results = { success: 0, failed: 0, unregistered: 0, errors: [] };

    for (let i = 0; i < devices.length; i += CONCURRENCY) {
      const batch = devices.slice(i, i + CONCURRENCY);
      const promises = batch.map(async (device) => {
        try {
          const r = await sendViaHTTP2(
            host,
            `/3/device/${device.device_token}`,
            {
              'authorization': `bearer ${token}`,
              'apns-topic': bundle_id,
              'apns-push-type': 'alert',
              'apns-priority': '10',
              'apns-expiration': '0',
            },
            payload
          );
          if (r.status === 200) {
            results.success++;
          } else if (r.status === 410) {
            results.unregistered++;
            await db.prepare('DELETE FROM push_devices WHERE device_token = ?').run(device.device_token);
          } else {
            results.failed++;
            results.errors.push({ token: device.device_token.substring(0, 8) + '...', reason: r.body?.reason });
          }
        } catch (e) {
          results.failed++;
          results.errors.push({ token: device.device_token.substring(0, 8) + '...', reason: e.message });
        }
      });
      await Promise.all(promises);
    }

    const msg = `广播完成：${results.success} 成功，${results.failed} 失败` +
      (results.unregistered > 0 ? `，${results.unregistered} 已注销(自动清理)` : '');

    res.json({ success: true, message: msg, data: { total: devices.length, ...results } });
  } catch (err) {
    next(err);
  }
});

router.get('/error-codes', (req, res) => {
  res.json({
    success: true, data: [
      { code: 200, reason: 'Success', desc: '推送发送成功' },
      { code: 400, reason: 'BadDeviceToken', desc: 'Device Token 格式无效' },
      { code: 400, reason: 'BadTopic', desc: 'Bundle ID (apns-topic) 无效' },
      { code: 400, reason: 'DeviceTokenNotForTopic', desc: 'Device Token 与 Bundle ID 不匹配' },
      { code: 400, reason: 'PayloadTooLarge', desc: '推送内容超过 4KB 限制' },
      { code: 400, reason: 'BadExpirationDate', desc: '过期时间格式错误' },
      { code: 400, reason: 'MissingDeviceToken', desc: '缺少 Device Token' },
      { code: 403, reason: 'BadCertificate', desc: '证书/Key 无效或已撤销' },
      { code: 403, reason: 'Forbidden', desc: '指定的操作不被允许' },
      { code: 403, reason: 'InvalidProviderToken', desc: '.p8 JWT Token 无效，检查 Key ID 和 Team ID' },
      { code: 403, reason: 'ExpiredProviderToken', desc: 'JWT Token 已过期（最长有效 1 小时）' },
      { code: 404, reason: 'BadPath', desc: 'API 请求路径错误' },
      { code: 405, reason: 'MethodNotAllowed', desc: '仅支持 POST 请求' },
      { code: 410, reason: 'Unregistered', desc: '设备已注销，应停止向此 Token 推送' },
      { code: 413, reason: 'PayloadTooLarge', desc: '推送 Payload 超过 4096 字节' },
      { code: 429, reason: 'TooManyRequests', desc: '请求过于频繁' },
      { code: 500, reason: 'InternalServerError', desc: 'APNs 服务端内部错误' },
      { code: 503, reason: 'ServiceUnavailable', desc: 'APNs 服务暂不可用' },
    ]
  });
});

module.exports = router;
