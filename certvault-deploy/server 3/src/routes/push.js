const express = require('express');
const { v4: uuidv4 } = require('uuid');
const router = express.Router();
const { getDb } = require('../config/database');
const { getDecryptedAccount, checkAccountOwnership } = require('../services/account-helper');
const { decrypt } = require('../services/encryption');
const { apnsService, APNsService } = require('../services/apns-service');
const { getTransporter } = require('../config/email');

async function sendNewDeviceEmail(token, platform, sandbox, label, username, totalDevices, isNew = true) {
  try {
    const t = getTransporter();
    if (!t) return;

    const adminEmail = process.env.ADMIN_EMAIL || process.env.SMTP_USER;
    if (!adminEmail) return;

    const env = sandbox ? '🟡 Sandbox' : '🟢 Production';
    const time = new Date().toLocaleString('zh-CN', { timeZone: 'Asia/Shanghai' });
    const fromName = process.env.SMTP_FROM_NAME || 'CertVault';
    const fromEmail = process.env.SMTP_USER;
    const emoji = isNew ? '📱' : '🔄';
    const action = isNew ? '新设备已注册' : '设备已上报';
    const subject = isNew
      ? `[CertVault] 新设备注册 — ${label || token.substring(0, 12) + '...'}`
      : `[CertVault] 设备上报 — ${label || token.substring(0, 12) + '...'}`;

    await t.sendMail({
      from: `"${fromName}" <${fromEmail}>`,
      to: adminEmail,
      subject,
      html: `
        <div style="max-width:520px;margin:0 auto;padding:32px;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif">
          <h2 style="color:#1d1e2c;margin:0 0 8px">${emoji} ${action}</h2>
          <p style="color:#909399;font-size:13px;margin:0 0 20px">${time}</p>
          <table style="width:100%;border-collapse:collapse;font-size:14px">
            <tr><td style="padding:10px 0;color:#909399;width:100px">设备信息</td><td style="padding:10px 0;color:#1d1e2c;font-weight:500">${label || '未知'}</td></tr>
            <tr style="border-top:1px solid #f0f0f0"><td style="padding:10px 0;color:#909399">平台</td><td style="padding:10px 0;color:#1d1e2c">${platform.toUpperCase()}</td></tr>
            <tr style="border-top:1px solid #f0f0f0"><td style="padding:10px 0;color:#909399">环境</td><td style="padding:10px 0;color:#1d1e2c">${env}</td></tr>
            <tr style="border-top:1px solid #f0f0f0"><td style="padding:10px 0;color:#909399">类型</td><td style="padding:10px 0;color:#1d1e2c">${isNew ? '🆕 首次注册' : '🔄 信息更新'}</td></tr>
            <tr style="border-top:1px solid #f0f0f0"><td style="padding:10px 0;color:#909399">用户</td><td style="padding:10px 0;color:#1d1e2c">${username || '未知'}</td></tr>
            <tr style="border-top:1px solid #f0f0f0"><td style="padding:10px 0;color:#909399">Token</td><td style="padding:10px 0;color:#1d1e2c;font-family:monospace;font-size:12px;word-break:break-all">${token}</td></tr>
          </table>
          <div style="margin-top:20px;padding:14px;background:#f4f4f5;border-radius:8px;text-align:center">
            <span style="font-size:24px;font-weight:700;color:#409eff">${totalDevices}</span>
            <span style="color:#909399;font-size:13px;margin-left:6px">台设备已注册</span>
          </div>
        </div>
      `,
    });
    console.log(`[Push] 设备${isNew ? '注册' : '上报'}邮件已发送 → ${adminEmail}`);
  } catch (err) {
    console.warn('[Push] 发送设备邮件失败:', err.message);
  }
}

// ==================== 推送设置 helpers ====================

async function getSettings() {
  const db = getDb();
  const rows = await db.prepare('SELECT key, value FROM push_settings').all();
  const settings = {};
  for (const row of rows) settings[row.key] = row.value;
  return settings;
}

async function updateSettings(updates) {
  const db = getDb();
  for (const [key, value] of Object.entries(updates)) {
    await db.prepare(
      `INSERT INTO push_settings (key, value, updated_at) VALUES (?, ?, NOW())
       ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW()`
    ).run(key, String(value));
  }
}

async function pushEnabledMiddleware(req, res, next) {
  try {
    const settings = await getSettings();
    if (settings.push_enabled === 'false') {
      return res.status(503).json({ success: false, message: '推送服务已关闭' });
    }
    req.pushSettings = settings;
    next();
  } catch (err) { next(err); }
}

// ==================== 推送设置 API ====================

router.get('/settings', async (req, res, next) => {
  try {
    const settings = await getSettings();
    res.json({ success: true, data: settings });
  } catch (err) { next(err); }
});

router.put('/settings', async (req, res, next) => {
  try {
    const allowed = [
      'push_enabled', 'default_push_key_id', 'default_bundle_id', 'default_sandbox',
      'apns_expiration', 'apns_priority', 'max_concurrency',
      'auto_cleanup_enabled', 'history_retention_days',
    ];
    const updates = {};
    for (const key of allowed) {
      if (req.body[key] !== undefined) updates[key] = req.body[key];
    }
    if (!Object.keys(updates).length) {
      return res.status(400).json({ success: false, message: '没有有效的设置项' });
    }
    await updateSettings(updates);
    const settings = await getSettings();
    res.json({ success: true, message: '设置已更新', data: settings });
  } catch (err) { next(err); }
});

router.get('/status', async (req, res, next) => {
  try {
    const db = getDb();
    const settings = await getSettings();
    const connStatus = apnsService.getConnectionStatus();
    const deviceCount = await db.prepare('SELECT COUNT(*) as count FROM push_devices').get();
    const keyCount = await db.prepare('SELECT COUNT(*) as count FROM push_keys').get();
    res.json({
      success: true,
      data: {
        push_enabled: settings.push_enabled === 'true',
        connections: connStatus,
        device_count: parseInt(deviceCount.count, 10),
        key_count: parseInt(keyCount.count, 10),
        default_push_key_id: settings.default_push_key_id || null,
        default_bundle_id: settings.default_bundle_id || null,
        default_sandbox: settings.default_sandbox === 'true',
      },
    });
  } catch (err) { next(err); }
});

// ==================== 解析推送密钥 ====================
async function resolvePushCredentials(reqBody, user) {
  const db = getDb();
  if (reqBody.push_key_id) {
    let pk = await db.prepare('SELECT * FROM push_keys WHERE id = ?').get(reqBody.push_key_id);
    if (!pk) pk = await db.prepare('SELECT * FROM push_keys WHERE key_id = ?').get(reqBody.push_key_id);
    if (!pk) throw Object.assign(new Error('推送密钥不存在'), { status: 404 });
    if (pk.user_id && pk.user_id !== user.id && user.role !== 'superadmin') {
      throw Object.assign(new Error('无权操作此推送密钥'), { status: 403 });
    }
    return { keyId: pk.key_id, teamId: pk.team_id, privateKey: decrypt(pk.private_key) };
  }
  if (reqBody.account_id) {
    const allowed = await checkAccountOwnership(reqBody.account_id, user);
    if (!allowed) throw Object.assign(new Error('无权操作此账号'), { status: 403 });
    let account;
    try { account = await getDecryptedAccount(reqBody.account_id); } catch (e) { throw e; }
    if (!reqBody.team_id) throw Object.assign(new Error('请提供 team_id'), { status: 400 });
    return { keyId: account.key_id, teamId: reqBody.team_id, privateKey: account.private_key };
  }
  if (reqBody.key_id && reqBody.team_id && reqBody.private_key) {
    return { keyId: reqBody.key_id, teamId: reqBody.team_id, privateKey: reqBody.private_key };
  }
  throw Object.assign(new Error('请提供推送密钥或账号'), { status: 400 });
}

// ==================== 记录推送历史 ====================
async function logPushHistory(db, data) {
  await db.prepare(
    `INSERT INTO push_history (user_id, type, title, body, bundle_id, sandbox, device_token, apns_id, target_count, success_count, failed_count, unregistered_count, errors, status, duration_ms)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
  ).run(
    data.user_id, data.type, data.title, data.body || '', data.bundle_id, data.sandbox ?? false,
    data.device_token || null, data.apns_id || null,
    data.target_count ?? 1, data.success_count ?? 0, data.failed_count ?? 0, data.unregistered_count ?? 0,
    data.errors ? JSON.stringify(data.errors) : null,
    data.status || 'success', data.duration_ms || 0
  );
}

router.post('/send', pushEnabledMiddleware, async (req, res, next) => {
  try {
    const settings = req.pushSettings || await getSettings();
    const {
      device_token, title, body: messageBody, badge,
      sound = 'default', custom_data = {},
      thread_id, collapse_id, mutable_content, interruption_level, relevance_score,
    } = req.body;

    const bundle_id = req.body.bundle_id || settings.default_bundle_id;
    const sandbox = req.body.sandbox !== undefined ? req.body.sandbox : (settings.default_sandbox === 'true');
    const priority = req.body.priority || parseInt(settings.apns_priority || '10', 10);
    const expiration = req.body.expiration || settings.apns_expiration || '0';

    if (!device_token || !title || !bundle_id) {
      return res.status(400).json({ success: false, message: '请填写 device_token、title 和 bundle_id' });
    }

    const db = getDb();

    let creds;
    if (!req.body.push_key_id && !req.body.account_id && !req.body.key_id && settings.default_push_key_id) {
      req.body.push_key_id = settings.default_push_key_id;
    }
    try { creds = await resolvePushCredentials(req.body, req.user); } catch (e) {
      return res.status(e.status || 400).json({ success: false, message: e.message });
    }

    const payload = APNsService.buildPayload({
      title, body: messageBody, badge, sound,
      mutableContent: mutable_content, threadId: thread_id,
      interruptionLevel: interruption_level, relevanceScore: relevance_score,
      customData: custom_data,
    });

    const result = await apnsService.send(device_token, payload, {
      ...creds, bundleId: bundle_id, sandbox, priority, expiration,
      collapseId: collapse_id,
    });

    const ok = result.status === 200;

    await logPushHistory(db, {
      user_id: req.user.id, type: 'single', title, body: messageBody, bundle_id, sandbox,
      device_token, apns_id: result.apnsId, target_count: 1,
      success_count: ok ? 1 : 0, failed_count: ok ? 0 : 1,
      errors: ok ? null : [{ token: device_token.substring(0, 8) + '...', reason: result.body?.reason }],
      status: ok ? 'success' : 'failed', duration_ms: result.duration,
    });

    if (ok) {
      res.json({ success: true, message: '推送发送成功', data: { apns_id: result.apnsId, status: result.status } });
    } else {
      res.json({ success: false, message: `推送失败: ${result.body?.reason || '未知错误'}`,
        data: { status: result.status, reason: result.body?.reason, apns_id: result.apnsId } });
    }
  } catch (err) { next(err); }
});

// Register device token for push notifications
router.post('/register-device', async (req, res, next) => {
  try {
    const { device_token, platform = 'ios', sandbox = false, label } = req.body;
    if (!device_token) {
      return res.status(400).json({ success: false, message: '缺少 device_token' });
    }

    const db = getDb();

    try { await db.exec('ALTER TABLE push_devices ADD COLUMN sandbox BOOLEAN DEFAULT false'); } catch (_) {}
    try { await db.exec('ALTER TABLE push_devices ADD COLUMN label TEXT'); } catch (_) {}

    const existing = await db.prepare(
      'SELECT id FROM push_devices WHERE device_token = ?'
    ).get(device_token);

    const isNew = !existing;

    if (existing) {
      await db.prepare(
        'UPDATE push_devices SET user_id = ?, platform = ?, sandbox = ?, label = ?, created_at = NOW() WHERE device_token = ?'
      ).run(req.user.id, platform, sandbox, label || null, device_token);
    } else {
      await db.prepare(
        'INSERT INTO push_devices (user_id, device_token, platform, sandbox, label) VALUES (?, ?, ?, ?, ?)'
      ).run(req.user.id, device_token, platform, sandbox, label || null);
    }

    const totalCount = await db.prepare('SELECT COUNT(*) as count FROM push_devices').get();
    sendNewDeviceEmail(device_token, platform, sandbox, label, req.user.username, totalCount.count, isNew).catch(() => {});

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
      `SELECT pd.id, pd.device_token, pd.platform, pd.sandbox, pd.label, pd.created_at, u.username
       FROM push_devices pd
       LEFT JOIN users u ON pd.user_id = u.id
       ORDER BY pd.created_at DESC`
    ).all();
    res.json({ success: true, data: devices, total: devices.length });
  } catch (err) {
    next(err);
  }
});

router.post('/broadcast', pushEnabledMiddleware, async (req, res, next) => {
  try {
    const settings = req.pushSettings || await getSettings();
    const {
      title, body: messageBody, badge, sound = 'default',
      custom_data = {},
      thread_id, collapse_id, mutable_content, interruption_level, relevance_score,
    } = req.body;

    const bundle_id = req.body.bundle_id || settings.default_bundle_id;
    const sandbox = req.body.sandbox;
    const priority = req.body.priority || parseInt(settings.apns_priority || '10', 10);
    const expiration = req.body.expiration || settings.apns_expiration || '0';
    const concurrency = parseInt(settings.max_concurrency || '10', 10);

    if (!title || !bundle_id) {
      return res.status(400).json({ success: false, message: '请填写标题和 Bundle ID' });
    }

    const db = getDb();

    if (!req.body.push_key_id && !req.body.account_id && !req.body.key_id && settings.default_push_key_id) {
      req.body.push_key_id = settings.default_push_key_id;
    }
    let creds;
    try { creds = await resolvePushCredentials(req.body, req.user); } catch (e) {
      return res.status(e.status || 400).json({ success: false, message: e.message });
    }

    let devices;
    if (sandbox === true) {
      devices = await db.prepare('SELECT device_token, sandbox FROM push_devices WHERE sandbox = true').all();
    } else if (sandbox === false) {
      devices = await db.prepare('SELECT device_token, sandbox FROM push_devices WHERE sandbox = false OR sandbox IS NULL').all();
    } else {
      devices = await db.prepare('SELECT device_token, sandbox FROM push_devices').all();
    }
    if (!devices.length) {
      return res.json({ success: false, message: '没有已注册的设备，无法广播' });
    }

    const payload = APNsService.buildPayload({
      title, body: messageBody, badge, sound,
      mutableContent: mutable_content, threadId: thread_id,
      interruptionLevel: interruption_level, relevanceScore: relevance_score,
      customData: custom_data,
    });

    const results = await apnsService.sendBatch(devices, payload, {
      ...creds, bundleId: bundle_id, priority, expiration,
      collapseId: collapse_id,
    }, concurrency);

    // Auto-cleanup 410 devices
    for (const err of (results.errors || [])) {
      if (err.reason === 'Unregistered') {
        // already counted via unregistered
      }
    }

    const status = results.failed === 0 && results.success > 0 ? 'success'
      : results.success > 0 ? 'partial' : 'failed';

    await logPushHistory(db, {
      user_id: req.user.id, type: 'broadcast', title, body: messageBody, bundle_id,
      sandbox: sandbox ?? null, target_count: devices.length,
      success_count: results.success, failed_count: results.failed,
      unregistered_count: results.unregistered,
      errors: results.errors.length ? results.errors : null,
      status, duration_ms: results.duration,
    });

    const msg = `广播完成：${results.success} 成功，${results.failed} 失败` +
      (results.unregistered > 0 ? `，${results.unregistered} 已注销` : '');

    res.json({ success: true, message: msg, data: { total: devices.length, ...results } });
  } catch (err) { next(err); }
});

// ==================== Device Token 管理 ====================

// 删除单个设备 token
router.delete('/devices/:id', async (req, res, next) => {
  try {
    const db = getDb();
    const device = await db.prepare('SELECT * FROM push_devices WHERE id = ?').get(req.params.id);
    if (!device) {
      return res.status(404).json({ success: false, message: '设备不存在' });
    }
    await db.prepare('DELETE FROM push_devices WHERE id = ?').run(req.params.id);
    res.json({ success: true, message: '设备已删除' });
  } catch (err) {
    next(err);
  }
});

// 批量删除设备 tokens
router.post('/devices/batch-delete', async (req, res, next) => {
  try {
    const { ids } = req.body;
    if (!ids || !Array.isArray(ids) || !ids.length) {
      return res.status(400).json({ success: false, message: '请提供要删除的设备 ID 列表' });
    }
    const db = getDb();
    const placeholders = ids.map(() => '?').join(',');
    const result = await db.prepare(`DELETE FROM push_devices WHERE id IN (${placeholders})`).run(...ids);
    res.json({ success: true, message: `已删除 ${result.changes} 个设备`, data: { deleted: result.changes } });
  } catch (err) {
    next(err);
  }
});

router.post('/devices/cleanup', async (req, res, next) => {
  try {
    const settings = await getSettings();
    const { bundle_id } = req.body;
    const bundleId = bundle_id || settings.default_bundle_id;
    if (!bundleId) {
      return res.status(400).json({ success: false, message: '请提供 bundle_id' });
    }

    const db = getDb();
    let creds;
    const pushKeyId = req.body.push_key_id || settings.default_push_key_id;
    if (!pushKeyId) {
      return res.status(400).json({ success: false, message: '请提供 push_key_id 或设置默认推送密钥' });
    }
    try {
      creds = await resolvePushCredentials({ push_key_id: pushKeyId }, req.user);
    } catch (e) {
      return res.status(e.status || 400).json({ success: false, message: e.message });
    }

    const devices = await db.prepare('SELECT id, device_token, sandbox FROM push_devices').all();
    if (!devices.length) {
      return res.json({ success: true, message: '没有设备需要清理', data: { total: 0, removed: 0 } });
    }

    const silentPayload = { aps: { 'content-available': 1 } };
    const concurrency = parseInt(settings.max_concurrency || '10', 10);
    let removed = 0, valid = 0, errored = 0;

    for (let i = 0; i < devices.length; i += concurrency) {
      const batch = devices.slice(i, i + concurrency);
      await Promise.all(batch.map(async (device) => {
        try {
          const r = await apnsService.send(device.device_token, silentPayload, {
            ...creds, bundleId,
            sandbox: device.sandbox ?? false,
            pushType: 'background', priority: 5,
          });
          if (r.status === 410 || r.body?.reason === 'Unregistered') {
            await db.prepare('DELETE FROM push_devices WHERE id = ?').run(device.id);
            removed++;
          } else if (r.status === 200) {
            valid++;
          } else {
            errored++;
          }
        } catch (_) {
          errored++;
        }
      }));
    }

    res.json({
      success: true,
      message: `清理完成：${valid} 有效，${removed} 已清除，${errored} 未知`,
      data: { total: devices.length, valid, removed, errored }
    });
  } catch (err) {
    next(err);
  }
});

// 手动添加设备 token（管理员）
router.post('/devices/add', async (req, res, next) => {
  try {
    const { device_token, platform = 'ios', sandbox = false, label } = req.body;
    if (!device_token) {
      return res.status(400).json({ success: false, message: '请填写 device_token' });
    }

    const db = getDb();
    try { await db.exec('ALTER TABLE push_devices ADD COLUMN sandbox BOOLEAN DEFAULT false'); } catch (_) {}
    try { await db.exec('ALTER TABLE push_devices ADD COLUMN label TEXT'); } catch (_) {}

    const existing = await db.prepare('SELECT id FROM push_devices WHERE device_token = ?').get(device_token);
    if (existing) {
      return res.status(409).json({ success: false, message: '该 Device Token 已存在' });
    }

    await db.prepare(
      'INSERT INTO push_devices (user_id, device_token, platform, sandbox, label) VALUES (?, ?, ?, ?, ?)'
    ).run(req.user.id, device_token, platform, sandbox, label || null);

    res.json({ success: true, message: '设备 Token 添加成功' });
  } catch (err) {
    next(err);
  }
});

// 更新设备 token 备注/标签
router.put('/devices/:id', async (req, res, next) => {
  try {
    const db = getDb();
    try { await db.exec('ALTER TABLE push_devices ADD COLUMN label TEXT'); } catch (_) {}

    const device = await db.prepare('SELECT * FROM push_devices WHERE id = ?').get(req.params.id);
    if (!device) {
      return res.status(404).json({ success: false, message: '设备不存在' });
    }

    const { label, sandbox } = req.body;
    const updates = [];
    const params = [];

    if (label !== undefined) { updates.push('label = ?'); params.push(label); }
    if (sandbox !== undefined) { updates.push('sandbox = ?'); params.push(sandbox); }

    if (!updates.length) {
      return res.status(400).json({ success: false, message: '没有需要更新的字段' });
    }

    params.push(req.params.id);
    await db.prepare(`UPDATE push_devices SET ${updates.join(', ')} WHERE id = ?`).run(...params);

    res.json({ success: true, message: '设备信息已更新' });
  } catch (err) {
    next(err);
  }
});

// 获取单个设备详情
router.get('/devices/:id', async (req, res, next) => {
  try {
    const db = getDb();
    const device = await db.prepare(
      `SELECT pd.*, u.username FROM push_devices pd
       LEFT JOIN users u ON pd.user_id = u.id
       WHERE pd.id = ?`
    ).get(req.params.id);
    if (!device) {
      return res.status(404).json({ success: false, message: '设备不存在' });
    }
    res.json({ success: true, data: device });
  } catch (err) {
    next(err);
  }
});

// 设备统计
router.get('/devices-stats', async (req, res, next) => {
  try {
    const db = getDb();
    const total = await db.prepare('SELECT COUNT(*) as count FROM push_devices').get();
    const sandbox = await db.prepare('SELECT COUNT(*) as count FROM push_devices WHERE sandbox = true').get();
    const production = await db.prepare('SELECT COUNT(*) as count FROM push_devices WHERE sandbox = false OR sandbox IS NULL').get();
    const ios = await db.prepare("SELECT COUNT(*) as count FROM push_devices WHERE platform = 'ios'").get();
    res.json({
      success: true,
      data: {
        total: total.count,
        sandbox: sandbox.count,
        production: production.count,
        ios: ios.count,
      }
    });
  } catch (err) {
    next(err);
  }
});

// ==================== 推送历史 ====================

router.get('/history', async (req, res, next) => {
  try {
    const db = getDb();
    const { page = 1, limit = 20, type, status } = req.query;
    const offset = (Math.max(1, parseInt(page)) - 1) * parseInt(limit);
    const conditions = [];
    const params = [];

    if (type) { conditions.push('ph.type = ?'); params.push(type); }
    if (status) { conditions.push('ph.status = ?'); params.push(status); }

    const where = conditions.length ? 'WHERE ' + conditions.join(' AND ') : '';

    const total = await db.prepare(`SELECT COUNT(*) as count FROM push_history ph ${where}`).get(...params);
    const items = await db.prepare(
      `SELECT ph.id, ph.type, ph.title, ph.body, ph.bundle_id, ph.sandbox,
              ph.device_token, ph.apns_id, ph.target_count, ph.success_count,
              ph.failed_count, ph.unregistered_count, ph.status, ph.duration_ms,
              ph.created_at, u.username
       FROM push_history ph
       LEFT JOIN users u ON ph.user_id = u.id
       ${where}
       ORDER BY ph.created_at DESC
       LIMIT ? OFFSET ?`
    ).all(...params, parseInt(limit), offset);

    res.json({ success: true, data: items, total: total.count, page: parseInt(page), limit: parseInt(limit) });
  } catch (err) { next(err); }
});

router.get('/history/stats', async (req, res, next) => {
  try {
    const db = getDb();
    const total = await db.prepare('SELECT COUNT(*) as count FROM push_history').get();
    const today = await db.prepare("SELECT COUNT(*) as count FROM push_history WHERE created_at >= CURRENT_DATE").get();
    const totalSuccess = await db.prepare('SELECT COALESCE(SUM(success_count), 0) as count FROM push_history').get();
    const totalFailed = await db.prepare('SELECT COALESCE(SUM(failed_count), 0) as count FROM push_history').get();
    const broadcasts = await db.prepare("SELECT COUNT(*) as count FROM push_history WHERE type = 'broadcast'").get();
    const singles = await db.prepare("SELECT COUNT(*) as count FROM push_history WHERE type = 'single'").get();
    res.json({
      success: true,
      data: {
        total_pushes: total.count,
        today_pushes: today.count,
        total_delivered: totalSuccess.count,
        total_failed: totalFailed.count,
        broadcasts: broadcasts.count,
        singles: singles.count,
      }
    });
  } catch (err) { next(err); }
});

router.get('/history/:id', async (req, res, next) => {
  try {
    const db = getDb();
    const item = await db.prepare(
      `SELECT ph.*, u.username FROM push_history ph
       LEFT JOIN users u ON ph.user_id = u.id WHERE ph.id = ?`
    ).get(req.params.id);
    if (!item) return res.status(404).json({ success: false, message: '记录不存在' });
    res.json({ success: true, data: item });
  } catch (err) { next(err); }
});

router.delete('/history/:id', async (req, res, next) => {
  try {
    const db = getDb();
    await db.prepare('DELETE FROM push_history WHERE id = ?').run(req.params.id);
    res.json({ success: true, message: '记录已删除' });
  } catch (err) { next(err); }
});

router.post('/history/clear', async (req, res, next) => {
  try {
    const db = getDb();
    const { before_days } = req.body;
    if (before_days) {
      await db.prepare(`DELETE FROM push_history WHERE created_at < NOW() - INTERVAL '${parseInt(before_days)} days'`).run();
    } else {
      await db.prepare('DELETE FROM push_history').run();
    }
    res.json({ success: true, message: '历史记录已清理' });
  } catch (err) { next(err); }
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

// ==================== 推送密钥管理 (整合自 push-keys.js) ====================

const path = require('path');
const fs = require('fs');
const multer = require('multer');
const { encrypt } = require('../services/encryption');

const P8_DIR = path.join(__dirname, '../../data/p8keys');
if (!fs.existsSync(P8_DIR)) fs.mkdirSync(P8_DIR, { recursive: true });

const upload = multer({
  storage: multer.diskStorage({
    destination: (req, file, cb) => cb(null, P8_DIR),
    filename: (req, file, cb) => cb(null, `push_${uuidv4()}${path.extname(file.originalname)}`)
  }),
  fileFilter: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    if (['.p8', '.pem', '.key'].includes(ext)) cb(null, true);
    else cb(new Error('仅支持 .p8 / .pem / .key 格式'));
  },
  limits: { fileSize: 1024 * 100 }
});

function normalizeKey(content) {
  let k = content.trim();
  if (!k.includes('-----BEGIN')) {
    k = `-----BEGIN PRIVATE KEY-----\n${k}\n-----END PRIVATE KEY-----`;
  }
  return k;
}

function guessKeyId(filename) {
  const match = filename.match(/AuthKey_(\w+)\.p8/i);
  return match ? match[1] : '';
}

router.get('/keys', async (req, res) => {
  const db = getDb();
  const keys = req.user.role === 'superadmin'
    ? await db.prepare('SELECT id, name, key_id, team_id, bundle_ids, created_at FROM push_keys ORDER BY created_at DESC').all()
    : await db.prepare('SELECT id, name, key_id, team_id, bundle_ids, created_at FROM push_keys WHERE user_id = ? ORDER BY created_at DESC').all(req.user.id);
  res.json({ success: true, data: keys });
});

router.post('/keys', upload.single('file'), async (req, res) => {
  let { name, key_id, team_id, private_key, bundle_ids } = req.body;

  if (req.file) {
    private_key = fs.readFileSync(req.file.path, 'utf-8');
    if (!key_id) key_id = guessKeyId(req.file.originalname);
  }

  if (!name || !key_id || !team_id || !private_key) {
    return res.status(400).json({ success: false, message: '请填写名称、Key ID、Team ID 并提供 .p8 密钥' });
  }

  private_key = normalizeKey(private_key);

  const db = getDb();
  const id = uuidv4();
  await db.prepare('INSERT INTO push_keys (id, user_id, name, key_id, team_id, private_key, bundle_ids) VALUES (?, ?, ?, ?, ?, ?, ?)')
    .run(id, req.user.id, name, key_id.trim(), team_id.trim(), encrypt(private_key), bundle_ids || '');

  res.json({ success: true, data: { id, name, key_id, team_id }, message: '推送密钥导入成功' });
});

router.put('/keys/:id', async (req, res) => {
  const { name, key_id, team_id, private_key, bundle_ids } = req.body;
  const db = getDb();
  const existing = await db.prepare('SELECT * FROM push_keys WHERE id = ?').get(req.params.id);
  if (!existing) return res.status(404).json({ success: false, message: '推送密钥不存在' });
  if (existing.user_id && existing.user_id !== req.user.id && req.user.role !== 'superadmin') {
    return res.status(403).json({ success: false, message: '无权操作此推送密钥' });
  }

  await db.prepare('UPDATE push_keys SET name = ?, key_id = ?, team_id = ?, private_key = ?, bundle_ids = ? WHERE id = ?')
    .run(
      name || existing.name,
      key_id || existing.key_id,
      team_id || existing.team_id,
      private_key ? encrypt(normalizeKey(private_key)) : existing.private_key,
      bundle_ids !== undefined ? bundle_ids : existing.bundle_ids,
      req.params.id
    );

  res.json({ success: true, message: '更新成功' });
});

router.delete('/keys/:id', async (req, res) => {
  const db = getDb();
  const existing = await db.prepare('SELECT * FROM push_keys WHERE id = ?').get(req.params.id);
  if (!existing) return res.status(404).json({ success: false, message: '推送密钥不存在' });
  if (existing.user_id && existing.user_id !== req.user.id && req.user.role !== 'superadmin') {
    return res.status(403).json({ success: false, message: '无权操作此推送密钥' });
  }
  await db.prepare('DELETE FROM push_keys WHERE id = ?').run(req.params.id);
  res.json({ success: true, message: '删除成功' });
});

router.get('/keys/:id/download', async (req, res) => {
  const db = getDb();
  const key = await db.prepare('SELECT * FROM push_keys WHERE id = ?').get(req.params.id);
  if (!key) return res.status(404).json({ success: false, message: '推送密钥不存在' });
  if (key.user_id && key.user_id !== req.user.id && req.user.role !== 'superadmin') {
    return res.status(403).json({ success: false, message: '无权操作此推送密钥' });
  }

  const filename = `APNsKey_${key.key_id}.p8`;
  res.setHeader('Content-Type', 'application/octet-stream');
  res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
  res.send(decrypt(key.private_key));
});

module.exports = router;
