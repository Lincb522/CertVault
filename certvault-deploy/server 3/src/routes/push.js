const express = require('express');
const { v4: uuidv4 } = require('uuid');
const router = express.Router();
const { getDb } = require('../config/database');
const { getDecryptedAccount, checkAccountOwnership } = require('../services/account-helper');
const { decrypt } = require('../services/encryption');
const { apnsService, APNsService } = require('../services/apns-service');
const { getTransporter } = require('../config/email');

async function sendNewDeviceEmail({ token, platform, sandbox, label, username, totalDevices, isNew = true,
                                    deviceName, model, osVersion, appVersion, remark } = {}) {
  try {
    const t = getTransporter();
    if (!t) return;

    const adminEmail = process.env.ADMIN_EMAIL || process.env.SMTP_USER;
    if (!adminEmail) return;

    const time = new Date().toLocaleString('zh-CN', { timeZone: 'Asia/Shanghai' });
    const fromName = process.env.SMTP_FROM_NAME || 'CertVault';
    const fromEmail = process.env.SMTP_USER;

    const displayName = remark || deviceName || model || label || '未知设备';
    const subject = isNew
      ? `[CertVault] 新设备注册 — ${displayName}`
      : `[CertVault] 设备上报 — ${displayName}`;

    const envColor = sandbox ? '#f59e0b' : '#22c55e';
    const envBg = sandbox ? '#fef3c7' : '#dcfce7';
    const envText = sandbox ? 'Sandbox' : 'Production';
    const actionColor = isNew ? '#3b82f6' : '#8b5cf6';
    const actionBg = isNew ? '#dbeafe' : '#ede9fe';
    const actionText = isNew ? '首次注册' : '信息更新';

    const svgIcon = (paths, color = '#f8fafc', size = 24) =>
      `<svg width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">${paths.map(d => `<path d="${d}" stroke="${color}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>`).join('')}</svg>`;

    const iconDevice = svgIcon([
      'M7 4h10a2 2 0 012 2v12a2 2 0 01-2 2H7a2 2 0 01-2-2V6a2 2 0 012-2z',
      'M11 17h2',
    ]);
    const iconRefresh = svgIcon([
      'M4 12a8 8 0 0114.93-4M20 12a8 8 0 01-14.93 4',
      'M20 4v4h-4', 'M4 20v-4h4',
    ]);
    const iconPhone = svgIcon([
      'M7 4h10a2 2 0 012 2v12a2 2 0 01-2 2H7a2 2 0 01-2-2V6a2 2 0 012-2z',
      'M11 17h2',
    ], '#7c3aed', 16);
    const iconCpu = svgIcon([
      'M9 3v2M15 3v2M9 19v2M15 19v2M3 9h2M3 15h2M19 9h2M19 15h2',
      'M7 7h10v10H7z',
    ], '#0284c7', 16);
    const iconApp = svgIcon([
      'M12 2L2 7l10 5 10-5-10-5z', 'M2 17l10 5 10-5', 'M2 12l10 5 10-5',
    ], '#ea580c', 16);
    const iconUser = svgIcon([
      'M12 12a4 4 0 100-8 4 4 0 000 8z',
      'M20 21a8 8 0 10-16 0',
    ], '#3b82f6', 16);
    const iconGrid = svgIcon([
      'M3 3h7v7H3zM14 3h7v7h-7zM3 14h7v7H3zM14 14h7v7h-7z',
    ], '#64748b', 16);
    const iconKey = svgIcon([
      'M21 2l-2 2m-7.61 7.61a5.5 5.5 0 11-7.778 7.778 5.5 5.5 0 017.777-7.777zm0 0L15.5 7.5m0 0l3 3L22 7l-3-3m-3.5 3.5L19 4',
    ], '#94a3b8', 16);
    const iconNote = svgIcon([
      'M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z',
      'M14 2v6h6', 'M16 13H8', 'M16 17H8', 'M10 9H8',
    ], '#64748b', 16);

    const infoRow = (icon, lbl, val, color) => val ? `
      <tr>
        <td style="padding:11px 16px;color:#64748b;font-size:13px;white-space:nowrap;vertical-align:middle">
          <span style="display:inline-block;vertical-align:middle;margin-right:6px">${icon}</span>${lbl}
        </td>
        <td style="padding:11px 16px;color:${color || '#0f172a'};font-size:13px;font-weight:500">${val}</td>
      </tr>` : '';

    await t.sendMail({
      from: `"${fromName}" <${fromEmail}>`,
      to: adminEmail,
      subject,
      html: `
<!DOCTYPE html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#f1f5f9;font-family:-apple-system,BlinkMacSystemFont,'SF Pro Text','Segoe UI',Roboto,Helvetica,Arial,sans-serif">
<div style="max-width:560px;margin:32px auto;background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.06)">

  <!-- Header -->
  <div style="background:linear-gradient(135deg,#0f172a 0%,#1e293b 100%);padding:32px 28px 28px;text-align:center">
    <div style="display:inline-block;width:56px;height:56px;line-height:56px;background:rgba(255,255,255,0.1);border-radius:16px;margin-bottom:16px;padding:14px;box-sizing:border-box">
      ${isNew ? iconDevice : iconRefresh}
    </div>
    <h1 style="margin:0;color:#f8fafc;font-size:20px;font-weight:700;letter-spacing:-0.3px">
      ${isNew ? '新设备已注册' : '设备信息更新'}
    </h1>
    <p style="margin:8px 0 0;color:#94a3b8;font-size:13px">${time}</p>
  </div>

  <!-- Device Card -->
  <div style="padding:24px 28px 0">
    <div style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:12px;padding:20px;text-align:center">
      <div style="font-size:17px;font-weight:700;color:#0f172a;margin-bottom:4px">${displayName}</div>
      ${model ? `<div style="font-size:14px;color:#7c3aed;font-weight:600;margin-bottom:10px">${model}</div>` : ''}
      <div style="display:inline-block">
        <span style="display:inline-block;font-size:11px;font-weight:700;color:${envColor};background:${envBg};padding:4px 10px;border-radius:20px;margin:2px 3px">${envText}</span>
        <span style="display:inline-block;font-size:11px;font-weight:700;color:${actionColor};background:${actionBg};padding:4px 10px;border-radius:20px;margin:2px 3px">${actionText}</span>
        ${osVersion ? `<span style="display:inline-block;font-size:11px;font-weight:700;color:#0284c7;background:#e0f2fe;padding:4px 10px;border-radius:20px;margin:2px 3px">${osVersion}</span>` : ''}
        ${appVersion ? `<span style="display:inline-block;font-size:11px;font-weight:700;color:#ea580c;background:#fff7ed;padding:4px 10px;border-radius:20px;margin:2px 3px">v${appVersion}</span>` : ''}
      </div>
    </div>
  </div>

  <!-- Details Table -->
  <div style="padding:20px 28px 0">
    <table style="width:100%;border-collapse:collapse;border-spacing:0">
      <tbody>
        ${infoRow(iconPhone, '设备名称', deviceName)}
        ${infoRow(iconPhone, '设备机型', model, '#7c3aed')}
        ${infoRow(iconCpu, '系统版本', osVersion, '#0284c7')}
        ${infoRow(iconApp, 'App 版本', appVersion ? 'v' + appVersion : null, '#ea580c')}
        ${infoRow(iconGrid, '平台', platform ? platform.toUpperCase() : null)}
        ${infoRow(iconUser, '注册用户', username, '#3b82f6')}
        ${infoRow(iconNote, '备注', remark)}
      </tbody>
    </table>
  </div>

  <!-- Token -->
  <div style="padding:16px 28px 0">
    <div style="font-size:11px;text-transform:uppercase;letter-spacing:1px;color:#94a3b8;font-weight:700;margin-bottom:6px">
      <span style="display:inline-block;vertical-align:middle;margin-right:4px">${iconKey}</span>Device Token
    </div>
    <div style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:8px;padding:10px 14px;font-family:'SF Mono','Fira Code',Consolas,monospace;font-size:11px;color:#475569;word-break:break-all;line-height:1.5">${token}</div>
  </div>

  <!-- Stats Footer -->
  <div style="padding:20px 28px 28px">
    <div style="background:linear-gradient(135deg,#eff6ff,#f0fdf4);border:1px solid #e2e8f0;border-radius:12px;padding:16px;text-align:center">
      <span style="font-size:32px;font-weight:800;color:#0f172a">${totalDevices}</span>
      <span style="color:#64748b;font-size:13px;margin-left:6px">台设备已注册</span>
    </div>
  </div>

</div>

<!-- Footer -->
<div style="text-align:center;padding:0 0 32px;font-size:11px;color:#94a3b8">
  Sent by CertVault &middot; Push Notification Service
</div>

</body></html>`,
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
      'tf_auto_push_enabled', 'tf_auto_push_title', 'tf_auto_push_body',
      'tf_auto_push_group_id', 'tf_auto_push_bundle_id',
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

    if (!ok && (result.status === 410 || result.body?.reason === 'Unregistered' || result.body?.reason === 'BadDeviceToken')) {
      try {
        const info = await db.prepare('SELECT device_name, model, os_version, app_version, label, remark FROM push_devices WHERE device_token = ?').get(device_token);
        await db.prepare(
          `INSERT INTO device_register_history (device_token, user_id, username, action, device_name, model, os_version, app_version, label, remark)
           VALUES (?, ?, ?, 'invalidated', ?, ?, ?, ?, ?, ?)`
        ).run(device_token, req.user.id, req.user.username,
              info?.device_name || null, info?.model || null,
              info?.os_version || null, info?.app_version || null,
              info?.label || null, info?.remark || null);
      } catch (_) {}
    }

    const reason = result.body?.reason;
    const reasonCN = ok ? '推送发送成功' : getReasonCN(reason);
    if (ok) {
      res.json({ success: true, message: '推送发送成功', data: { apns_id: result.apnsId, status: result.status, reason_cn: reasonCN } });
    } else {
      res.json({ success: false, message: `推送失败: ${reasonCN}`,
        data: { status: result.status, reason, reason_cn: reasonCN, apns_id: result.apnsId } });
    }
  } catch (err) { next(err); }
});

// Parse legacy label format: "设备名 · 机型 · iOS xx.x · vX.X(X)"
function parseLegacyLabel(label) {
  if (!label) return {};
  const parts = label.split(' · ').map(s => s.trim());
  if (parts.length < 2) return {};
  const result = {};
  result.device_name = parts[0] || null;
  if (parts.length >= 2) result.model = parts[1] || null;
  for (let i = 2; i < parts.length; i++) {
    const p = parts[i];
    if (/^iOS\s/i.test(p)) result.os_version = p;
    else if (/^v\d/.test(p)) result.app_version = p.replace(/^v/, '');
  }
  return result;
}

// Register device token for push notifications
router.post('/register-device', async (req, res, next) => {
  try {
    let { device_token, platform = 'ios', sandbox = false, label, remark,
            device_name, model, os_version, app_version, reported_at } = req.body;
    if (!device_token) {
      return res.status(400).json({ success: false, message: '缺少 device_token' });
    }

    const hasStructuredFields = !!(device_name || model);
    let parsed = {};
    if (!hasStructuredFields && label) {
      parsed = parseLegacyLabel(label);
    }

    const db = getDb();

    const existing = await db.prepare(
      `SELECT id, remark as old_remark, device_name as old_device_name, model as old_model,
       os_version as old_os_version, app_version as old_app_version FROM push_devices WHERE device_token = ?`
    ).get(device_token);

    const isNew = !existing;

    let finalDeviceName, finalModel, finalOsVersion, finalAppVersion;
    if (hasStructuredFields) {
      finalDeviceName = device_name || (existing?.old_device_name) || null;
      finalModel = model || (existing?.old_model) || null;
      finalOsVersion = os_version || (existing?.old_os_version) || null;
      finalAppVersion = app_version || (existing?.old_app_version) || null;
    } else if (existing) {
      finalDeviceName = existing.old_device_name || parsed.device_name || null;
      finalModel = existing.old_model || parsed.model || null;
      finalOsVersion = existing.old_os_version || parsed.os_version || null;
      finalAppVersion = existing.old_app_version || parsed.app_version || null;
    } else {
      finalDeviceName = parsed.device_name || null;
      finalModel = parsed.model || null;
      finalOsVersion = parsed.os_version || null;
      finalAppVersion = parsed.app_version || null;
    }

    const finalRemark = remark || (existing?.old_remark) || null;

    const reportTime = reported_at || new Date().toLocaleString('zh-CN', { timeZone: 'Asia/Shanghai', hour12: false,
      year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit'
    }).replace(/\//g, '-');
    const finalLabel = label ? `${label} · ${reportTime}` : reportTime;

    if (existing) {
      await db.prepare(
        `UPDATE push_devices SET user_id = ?, platform = ?, sandbox = ?, label = ?,
         remark = ?, device_name = ?, model = ?, os_version = ?, app_version = ?,
         created_at = NOW() WHERE device_token = ?`
      ).run(req.user.id, platform, sandbox, finalLabel,
            finalRemark, finalDeviceName, finalModel, finalOsVersion, finalAppVersion,
            device_token);
    } else {
      await db.prepare(
        `INSERT INTO push_devices (user_id, device_token, platform, sandbox, label, remark,
         device_name, model, os_version, app_version) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
      ).run(req.user.id, device_token, platform, sandbox, finalLabel, finalRemark,
            finalDeviceName, finalModel, finalOsVersion, finalAppVersion);
    }

    const totalCount = await db.prepare('SELECT COUNT(*) as count FROM push_devices').get();

    try {
      await db.prepare(
        `INSERT INTO device_register_history (device_token, user_id, username, action, platform, sandbox,
         label, remark, device_name, model, os_version, app_version)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
      ).run(device_token, req.user.id, req.user.username, isNew ? 'register' : 'report',
            platform, sandbox, finalLabel, finalRemark,
            finalDeviceName, finalModel, finalOsVersion, finalAppVersion);
    } catch (_) {}

    sendNewDeviceEmail({
      token: device_token, platform, sandbox, label, username: req.user.username,
      totalDevices: totalCount.count, isNew, remark: finalRemark,
      deviceName: finalDeviceName, model: finalModel, osVersion: finalOsVersion, appVersion: finalAppVersion,
    }).catch(() => {});

    res.json({ success: true, message: '设备 Token 注册成功' });
  } catch (err) {
    next(err);
  }
});

// Device registration history list
router.get('/device-history', async (req, res, next) => {
  try {
    const db = getDb();
    const { device_token, action, limit = 50, offset = 0 } = req.query;

    let sql = `SELECT * FROM device_register_history WHERE 1=1`;
    const params = [];

    if (device_token) {
      sql += ` AND device_token = ?`;
      params.push(device_token);
    }
    if (action) {
      sql += ` AND action = ?`;
      params.push(action);
    }

    const countSql = sql.replace('SELECT *', 'SELECT COUNT(*) as total');
    const countResult = await db.prepare(countSql).get(...params);

    sql += ` ORDER BY created_at DESC LIMIT ? OFFSET ?`;
    params.push(parseInt(limit), parseInt(offset));

    const rows = await db.prepare(sql).all(...params);

    res.json({
      success: true,
      data: rows,
      total: parseInt(countResult?.total) || 0,
      limit: parseInt(limit),
      offset: parseInt(offset),
    });
  } catch (err) { next(err); }
});

// Device registration history detail
router.get('/device-history/:id', async (req, res, next) => {
  try {
    const db = getDb();
    const row = await db.prepare('SELECT * FROM device_register_history WHERE id = ?').get(req.params.id);
    if (!row) return res.status(404).json({ success: false, message: '记录不存在' });
    res.json({ success: true, data: row });
  } catch (err) { next(err); }
});

// Unregister device token
router.delete('/unregister-device', async (req, res, next) => {
  try {
    const { device_token } = req.body;
    if (!device_token) {
      return res.status(400).json({ success: false, message: '缺少 device_token' });
    }

    const db = getDb();

    const deviceInfo = await db.prepare(
      'SELECT device_name, model, os_version, app_version, label, remark FROM push_devices WHERE device_token = ? AND user_id = ?'
    ).get(device_token, req.user.id);

    await db.prepare(
      'DELETE FROM push_devices WHERE device_token = ? AND user_id = ?'
    ).run(device_token, req.user.id);

    try {
      await db.prepare(
        `INSERT INTO device_register_history (device_token, user_id, username, action, device_name, model, os_version, app_version, label, remark)
         VALUES (?, ?, ?, 'unregister', ?, ?, ?, ?, ?, ?)`
      ).run(device_token, req.user.id, req.user.username,
            deviceInfo?.device_name || null, deviceInfo?.model || null,
            deviceInfo?.os_version || null, deviceInfo?.app_version || null,
            deviceInfo?.label || null, deviceInfo?.remark || null);
    } catch (_) {}

    res.json({ success: true, message: '设备 Token 注销成功' });
  } catch (err) {
    next(err);
  }
});

router.get('/devices', async (req, res, next) => {
  try {
    const db = getDb();
    const devices = await db.prepare(
      `SELECT pd.id, pd.device_token, pd.platform, pd.sandbox, pd.label, pd.remark,
              pd.device_name, pd.model, pd.os_version, pd.app_version,
              pd.created_at, u.username
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

    // Record invalidated devices from broadcast
    for (const err of (results.errors || [])) {
      if (err.reason === 'Unregistered' && err.token) {
        try {
          const fullToken = devices.find(d => d.device_token.startsWith(err.token?.replace('...', '')))?.device_token || err.token;
          const info = await db.prepare('SELECT device_name, model, os_version, app_version, label, remark FROM push_devices WHERE device_token = ?').get(fullToken);
          await db.prepare(
            `INSERT INTO device_register_history (device_token, user_id, username, action, device_name, model, os_version, app_version, label, remark)
             VALUES (?, ?, ?, 'invalidated', ?, ?, ?, ?, ?, ?)`
          ).run(fullToken, req.user.id, req.user.username,
                info?.device_name || null, info?.model || null,
                info?.os_version || null, info?.app_version || null,
                info?.label || null, info?.remark || null);
        } catch (_) {}
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

    const enrichedErrors = (results.errors || []).map(e => ({
      ...e, reason_cn: getReasonCN(e.reason),
    }));

    const msg = `广播完成：${results.success} 成功，${results.failed} 失败` +
      (results.unregistered > 0 ? `，${results.unregistered} 已注销` : '');

    res.json({ success: true, message: msg, data: { total: devices.length, ...results, errors: enrichedErrors } });
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

router.post('/devices/batch-update', async (req, res, next) => {
  try {
    const { ids, sandbox, label } = req.body;
    if (!ids || !Array.isArray(ids) || !ids.length) {
      return res.status(400).json({ success: false, message: '请提供要更新的设备 ID 列表' });
    }

    const db = getDb();
    const updates = [];
    const params = [];

    if (sandbox !== undefined) { updates.push('sandbox = ?'); params.push(sandbox); }
    if (label !== undefined) { updates.push('label = ?'); params.push(label); }

    if (!updates.length) {
      return res.status(400).json({ success: false, message: '没有需要更新的字段' });
    }

    const placeholders = ids.map(() => '?').join(',');
    const result = await db.prepare(
      `UPDATE push_devices SET ${updates.join(', ')} WHERE id IN (${placeholders})`
    ).run(...params, ...ids);

    res.json({ success: true, message: `已更新 ${result.changes} 个设备`, data: { updated: result.changes } });
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
            const info = await db.prepare('SELECT device_name, model, os_version, app_version, label, remark FROM push_devices WHERE id = ?').get(device.id);
            await db.prepare('DELETE FROM push_devices WHERE id = ?').run(device.id);
            try {
              await db.prepare(
                `INSERT INTO device_register_history (device_token, user_id, username, action, device_name, model, os_version, app_version, label, remark)
                 VALUES (?, ?, ?, 'invalidated', ?, ?, ?, ?, ?, ?)`
              ).run(device.device_token, req.user.id, req.user.username,
                    info?.device_name || null, info?.model || null,
                    info?.os_version || null, info?.app_version || null,
                    info?.label || null, info?.remark || null);
            } catch (_) {}
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

// Validate single device token (silent push)
router.post('/devices/:id/validate', async (req, res, next) => {
  try {
    const db = getDb();
    const device = await db.prepare('SELECT * FROM push_devices WHERE id = ?').get(req.params.id);
    if (!device) return res.status(404).json({ success: false, message: '设备不存在' });

    const settings = await getSettings();
    const { bundle_id } = req.body;
    const bundleId = bundle_id || settings.default_bundle_id;
    if (!bundleId) return res.status(400).json({ success: false, message: '请提供 bundle_id 或设置默认 Bundle ID' });

    const pushKeyId = req.body.push_key_id || settings.default_push_key_id;
    if (!pushKeyId) return res.status(400).json({ success: false, message: '请提供 push_key_id 或设置默认推送密钥' });

    let creds;
    try { creds = await resolvePushCredentials({ push_key_id: pushKeyId }, req.user); }
    catch (e) { return res.status(e.status || 400).json({ success: false, message: e.message }); }

    const silentPayload = { aps: { 'content-available': 1 } };
    const r = await apnsService.send(device.device_token, silentPayload, {
      ...creds, bundleId,
      sandbox: device.sandbox ?? false,
      pushType: 'background', priority: 5,
    });

    const valid = r.status === 200;
    const reason = r.body?.reason;
    const reasonCN = valid ? '有效' : getReasonCN(reason);

    if (!valid && (r.status === 410 || reason === 'Unregistered' || reason === 'BadDeviceToken')) {
      try {
        await db.prepare(
          `INSERT INTO device_register_history (device_token, user_id, username, action, device_name, model, os_version, app_version, label, remark)
           VALUES (?, ?, ?, 'invalidated', ?, ?, ?, ?, ?, ?)`
        ).run(device.device_token, req.user.id, req.user.username,
              device.device_name || null, device.model || null,
              device.os_version || null, device.app_version || null,
              device.label || null, device.remark || null);
      } catch (_) {}
    }

    res.json({
      success: true,
      data: {
        valid, status: r.status, reason: reason || null, reason_cn: reasonCN,
        device_id: device.id, device_token: device.device_token,
        device_name: device.device_name, model: device.model,
      },
    });
  } catch (err) { next(err); }
});

// Validate all device tokens (silent push)
router.post('/devices/validate-all', async (req, res, next) => {
  try {
    const settings = await getSettings();
    const { bundle_id } = req.body;
    const bundleId = bundle_id || settings.default_bundle_id;
    if (!bundleId) return res.status(400).json({ success: false, message: '请提供 bundle_id 或设置默认 Bundle ID' });

    const pushKeyId = req.body.push_key_id || settings.default_push_key_id;
    if (!pushKeyId) return res.status(400).json({ success: false, message: '请提供 push_key_id 或设置默认推送密钥' });

    let creds;
    try { creds = await resolvePushCredentials({ push_key_id: pushKeyId }, req.user); }
    catch (e) { return res.status(e.status || 400).json({ success: false, message: e.message }); }

    const db = getDb();
    const devices = await db.prepare('SELECT * FROM push_devices').all();
    if (!devices.length) {
      return res.json({ success: true, message: '没有设备', data: { total: 0, results: [] } });
    }

    const silentPayload = { aps: { 'content-available': 1 } };
    const concurrency = parseInt(settings.max_concurrency || '10', 10);
    const results = [];

    for (let i = 0; i < devices.length; i += concurrency) {
      const batch = devices.slice(i, i + concurrency);
      await Promise.all(batch.map(async (device) => {
        try {
          const r = await apnsService.send(device.device_token, silentPayload, {
            ...creds, bundleId,
            sandbox: device.sandbox ?? false,
            pushType: 'background', priority: 5,
          });
          const valid = r.status === 200;
          const reason = r.body?.reason;

          if (!valid && (r.status === 410 || reason === 'Unregistered' || reason === 'BadDeviceToken')) {
            try {
              await db.prepare(
                `INSERT INTO device_register_history (device_token, user_id, username, action, device_name, model, os_version, app_version, label, remark)
                 VALUES (?, ?, ?, 'invalidated', ?, ?, ?, ?, ?, ?)`
              ).run(device.device_token, req.user.id, req.user.username,
                    device.device_name || null, device.model || null,
                    device.os_version || null, device.app_version || null,
                    device.label || null, device.remark || null);
            } catch (_) {}
          }

          results.push({
            device_id: device.id, device_token: device.device_token,
            device_name: device.device_name, model: device.model,
            sandbox: device.sandbox, valid, status: r.status,
            reason: reason || null, reason_cn: valid ? '有效' : getReasonCN(reason),
          });
        } catch (e) {
          results.push({
            device_id: device.id, device_token: device.device_token,
            device_name: device.device_name, model: device.model,
            sandbox: device.sandbox, valid: false, status: 0,
            reason: 'NetworkError', reason_cn: `网络错误: ${e.message}`,
          });
        }
      }));
    }

    const validCount = results.filter(r => r.valid).length;
    const invalidCount = results.filter(r => !r.valid).length;

    res.json({
      success: true,
      message: `检测完成：${validCount} 有效，${invalidCount} 无效`,
      data: { total: devices.length, valid: validCount, invalid: invalidCount, results },
    });
  } catch (err) { next(err); }
});

// 手动添加设备 token（管理员）
router.post('/devices/add', async (req, res, next) => {
  try {
    const { device_token, platform = 'ios', sandbox = false, label, remark } = req.body;
    if (!device_token) {
      return res.status(400).json({ success: false, message: '请填写 device_token' });
    }

    const db = getDb();

    const existing = await db.prepare('SELECT id FROM push_devices WHERE device_token = ?').get(device_token);
    if (existing) {
      return res.status(409).json({ success: false, message: '该 Device Token 已存在' });
    }

    await db.prepare(
      'INSERT INTO push_devices (user_id, device_token, platform, sandbox, label, remark) VALUES (?, ?, ?, ?, ?, ?)'
    ).run(req.user.id, device_token, platform, sandbox, label || null, remark || null);

    res.json({ success: true, message: '设备 Token 添加成功' });
  } catch (err) {
    next(err);
  }
});

// 更新设备 token 备注/标签
router.put('/devices/:id', async (req, res, next) => {
  try {
    const db = getDb();

    const device = await db.prepare('SELECT * FROM push_devices WHERE id = ?').get(req.params.id);
    if (!device) {
      return res.status(404).json({ success: false, message: '设备不存在' });
    }

    const { label, sandbox, remark } = req.body;
    const updates = [];
    const params = [];

    if (label !== undefined) { updates.push('label = ?'); params.push(label); }
    if (sandbox !== undefined) { updates.push('sandbox = ?'); params.push(sandbox); }
    if (remark !== undefined) { updates.push('remark = ?'); params.push(remark); }

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
        total: parseInt(total.count) || 0,
        sandbox: parseInt(sandbox.count) || 0,
        production: parseInt(production.count) || 0,
        ios: parseInt(ios.count) || 0,
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

    res.json({ success: true, data: items, total: parseInt(total.count) || 0, page: parseInt(page), limit: parseInt(limit) });
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
        total_pushes: parseInt(total.count) || 0,
        today_pushes: parseInt(today.count) || 0,
        total_delivered: parseInt(totalSuccess.count) || 0,
        total_failed: parseInt(totalFailed.count) || 0,
        broadcasts: parseInt(broadcasts.count) || 0,
        singles: parseInt(singles.count) || 0,
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

const APNS_REASON_CN = {
  'Success': '推送发送成功',
  'BadCollapseId': 'collapse-id 标头值无效（不能超过 64 字节）',
  'BadDeviceToken': 'Device Token 格式无效或与环境不匹配',
  'BadExpirationDate': '过期时间 (apns-expiration) 格式错误',
  'BadMessageId': 'apns-id 标头值格式错误',
  'BadPriority': '推送优先级 (apns-priority) 值无效',
  'BadTopic': 'Bundle ID (apns-topic) 无效或未授权',
  'DeviceTokenNotForTopic': 'Device Token 与 Bundle ID 不匹配',
  'DuplicateHeaders': '请求中有重复的标头',
  'IdleTimeout': '连接空闲超时',
  'InvalidPushType': 'apns-push-type 值无效',
  'MissingDeviceToken': '缺少 Device Token',
  'MissingTopic': '缺少 apns-topic 标头（多 Topic 证书时必填）',
  'PayloadEmpty': '推送内容不能为空',
  'PayloadTooLarge': '推送内容超过 4KB 限制',
  'TopicDisallowed': '发送此 Topic 的推送未被授权',
  'BadCertificate': '证书/Key 无效或已撤销',
  'BadCertificateEnvironment': '证书与推送环境不匹配（沙盒/生产）',
  'ExpiredProviderToken': 'JWT Token 已过期（最长有效 1 小时，请重新生成）',
  'Forbidden': '指定的操作不被允许',
  'InvalidProviderToken': '.p8 JWT Token 无效，请检查 Key ID 和 Team ID',
  'MissingProviderToken': '缺少认证 Token，请配置推送密钥',
  'BadPath': 'API 请求路径错误',
  'ExpiredToken': 'Device Token 已过期失效',
  'MethodNotAllowed': '仅支持 POST 请求',
  'Unregistered': '设备 Token 已失效（用户可能已卸载 App 或关闭推送）',
  'TooManyProviderTokenUpdates': '短时间内 Token 更新过于频繁',
  'TooManyRequests': '对同一设备请求过于频繁，请稍后再试',
  'InternalServerError': 'APNs 服务端内部错误，请稍后重试',
  'ServiceUnavailable': 'APNs 服务暂不可用，请稍后重试',
  'Shutdown': 'APNs 服务正在重启，请稍后重试',
};

function getReasonCN(reason) {
  return APNS_REASON_CN[reason] || reason || '未知错误';
}

router.get('/error-codes', (req, res) => {
  const data = Object.entries(APNS_REASON_CN)
    .filter(([k]) => k !== 'Success')
    .map(([reason, desc]) => {
      let code = 400;
      if (['BadCertificate', 'BadCertificateEnvironment', 'ExpiredProviderToken', 'Forbidden', 'InvalidProviderToken', 'MissingProviderToken'].includes(reason)) code = 403;
      else if (['BadPath'].includes(reason)) code = 404;
      else if (['ExpiredToken', 'MethodNotAllowed', 'Unregistered'].includes(reason)) code = 410;
      else if (['TooManyProviderTokenUpdates', 'TooManyRequests'].includes(reason)) code = 429;
      else if (['InternalServerError'].includes(reason)) code = 500;
      else if (['ServiceUnavailable', 'Shutdown'].includes(reason)) code = 503;
      return { code, reason, desc };
    });
  data.unshift({ code: 200, reason: 'Success', desc: '推送发送成功' });
  res.json({ success: true, data });
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

// ==================== 定时推送 ====================

router.get('/scheduled', async (req, res, next) => {
  try {
    const db = getDb();
    const { status, page = 1, limit = 20 } = req.query;
    const offset = (Math.max(1, parseInt(page)) - 1) * parseInt(limit);
    const conditions = [];
    const params = [];
    if (status) { conditions.push('sp.status = ?'); params.push(status); }
    const where = conditions.length ? 'WHERE ' + conditions.join(' AND ') : '';
    const total = await db.prepare(`SELECT COUNT(*) as count FROM scheduled_pushes sp ${where}`).get(...params);
    const items = await db.prepare(
      `SELECT sp.*, u.username FROM scheduled_pushes sp
       LEFT JOIN users u ON sp.user_id = u.id
       ${where} ORDER BY sp.scheduled_at DESC LIMIT ? OFFSET ?`
    ).all(...params, parseInt(limit), offset);
    res.json({ success: true, data: items, total: parseInt(total.count) || 0, page: parseInt(page) });
  } catch (err) { next(err); }
});

router.get('/scheduled/:id', async (req, res, next) => {
  try {
    const db = getDb();
    const item = await db.prepare(
      `SELECT sp.*, u.username FROM scheduled_pushes sp
       LEFT JOIN users u ON sp.user_id = u.id WHERE sp.id = ?`
    ).get(req.params.id);
    if (!item) return res.status(404).json({ success: false, message: '定时任务不存在' });
    res.json({ success: true, data: item });
  } catch (err) { next(err); }
});

router.post('/scheduled', async (req, res, next) => {
  try {
    const {
      type = 'broadcast', title, body: msgBody, bundle_id,
      sandbox = false, device_token, push_key_id, custom_data, scheduled_at
    } = req.body;
    if (!title) return res.status(400).json({ success: false, message: '请填写推送标题' });
    if (!scheduled_at) return res.status(400).json({ success: false, message: '请设置定时时间' });

    const scheduledTime = new Date(scheduled_at);
    if (isNaN(scheduledTime.getTime())) return res.status(400).json({ success: false, message: '定时时间格式无效' });
    if (scheduledTime <= new Date()) return res.status(400).json({ success: false, message: '定时时间必须在未来' });

    const db = getDb();
    const result = await db.prepare(
      `INSERT INTO scheduled_pushes (user_id, type, title, body, bundle_id, sandbox, device_token, push_key_id, custom_data, scheduled_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    ).run(
      req.user.id, type, title, msgBody || null, bundle_id || null,
      sandbox, device_token || null, push_key_id || null,
      custom_data ? JSON.stringify(custom_data) : null, scheduled_at
    );

    res.json({ success: true, message: '定时推送已创建', data: { id: result.lastInsertRowid || result.lastID } });
  } catch (err) { next(err); }
});

router.put('/scheduled/:id', async (req, res, next) => {
  try {
    const db = getDb();
    const existing = await db.prepare('SELECT * FROM scheduled_pushes WHERE id = ?').get(req.params.id);
    if (!existing) return res.status(404).json({ success: false, message: '定时任务不存在' });
    if (existing.status !== 'pending') return res.status(400).json({ success: false, message: '只能修改待执行的定时任务' });

    const { title, body: msgBody, bundle_id, sandbox, device_token, push_key_id, custom_data, scheduled_at, type } = req.body;
    const updates = [];
    const params = [];
    if (title !== undefined) { updates.push('title = ?'); params.push(title); }
    if (msgBody !== undefined) { updates.push('body = ?'); params.push(msgBody); }
    if (bundle_id !== undefined) { updates.push('bundle_id = ?'); params.push(bundle_id); }
    if (sandbox !== undefined) { updates.push('sandbox = ?'); params.push(sandbox); }
    if (device_token !== undefined) { updates.push('device_token = ?'); params.push(device_token); }
    if (push_key_id !== undefined) { updates.push('push_key_id = ?'); params.push(push_key_id); }
    if (custom_data !== undefined) { updates.push('custom_data = ?'); params.push(JSON.stringify(custom_data)); }
    if (scheduled_at !== undefined) { updates.push('scheduled_at = ?'); params.push(scheduled_at); }
    if (type !== undefined) { updates.push('type = ?'); params.push(type); }

    if (!updates.length) return res.status(400).json({ success: false, message: '没有需要更新的字段' });

    params.push(req.params.id);
    await db.prepare(`UPDATE scheduled_pushes SET ${updates.join(', ')} WHERE id = ?`).run(...params);
    res.json({ success: true, message: '定时推送已更新' });
  } catch (err) { next(err); }
});

router.delete('/scheduled/:id', async (req, res, next) => {
  try {
    const db = getDb();
    const existing = await db.prepare('SELECT * FROM scheduled_pushes WHERE id = ?').get(req.params.id);
    if (!existing) return res.status(404).json({ success: false, message: '定时任务不存在' });
    await db.prepare('DELETE FROM scheduled_pushes WHERE id = ?').run(req.params.id);
    res.json({ success: true, message: '定时推送已删除' });
  } catch (err) { next(err); }
});

router.post('/scheduled/:id/cancel', async (req, res, next) => {
  try {
    const db = getDb();
    const existing = await db.prepare('SELECT * FROM scheduled_pushes WHERE id = ?').get(req.params.id);
    if (!existing) return res.status(404).json({ success: false, message: '定时任务不存在' });
    if (existing.status !== 'pending') return res.status(400).json({ success: false, message: '只能取消待执行的定时任务' });
    await db.prepare("UPDATE scheduled_pushes SET status = 'cancelled' WHERE id = ?").run(req.params.id);
    res.json({ success: true, message: '定时推送已取消' });
  } catch (err) { next(err); }
});

// ---- 定时推送调度器 ----
async function executeScheduledPushes() {
  try {
    const db = getDb();
    const pending = await db.prepare(
      "SELECT * FROM scheduled_pushes WHERE status = 'pending' AND scheduled_at <= NOW()"
    ).all();

    for (const task of pending) {
      try {
        await db.prepare("UPDATE scheduled_pushes SET status = 'executing' WHERE id = ?").run(task.id);

        const settings = {};
        const rows = await db.prepare('SELECT key, value FROM push_settings').all();
        rows.forEach(r => settings[r.key] = r.value);

        const bundleId = task.bundle_id || settings.default_bundle_id;
        const pushKeyId = task.push_key_id || settings.default_push_key_id;

        if (!bundleId || !pushKeyId) {
          await db.prepare("UPDATE scheduled_pushes SET status = 'failed', result = ?, executed_at = NOW() WHERE id = ?")
            .run(JSON.stringify({ error: '缺少 bundle_id 或 push_key_id' }), task.id);
          continue;
        }

        const keyRow = await db.prepare('SELECT * FROM push_keys WHERE id = ?').get(pushKeyId);
        if (!keyRow) {
          await db.prepare("UPDATE scheduled_pushes SET status = 'failed', result = ?, executed_at = NOW() WHERE id = ?")
            .run(JSON.stringify({ error: '推送密钥不存在' }), task.id);
          continue;
        }

        const creds = {
          keyId: keyRow.key_id,
          teamId: keyRow.team_id,
          privateKey: decrypt(keyRow.private_key),
        };

        const payload = APNsService.buildPayload({
          title: task.title,
          body: task.body,
          customData: task.custom_data ? (typeof task.custom_data === 'string' ? JSON.parse(task.custom_data) : task.custom_data) : undefined,
        });

        let result;
        if (task.type === 'broadcast') {
          let devices;
          if (task.sandbox === true) {
            devices = await db.prepare('SELECT device_token, sandbox FROM push_devices WHERE sandbox = true').all();
          } else if (task.sandbox === false) {
            devices = await db.prepare('SELECT device_token, sandbox FROM push_devices WHERE sandbox = false OR sandbox IS NULL').all();
          } else {
            devices = await db.prepare('SELECT device_token, sandbox FROM push_devices').all();
          }

          if (devices.length === 0) {
            result = { error: '没有可用设备' };
          } else {
            const batchResult = await apnsService.sendBatch(devices, payload, {
              ...creds, bundleId, priority: 10,
            }, parseInt(settings.max_concurrency || '10', 10));
            result = { total: devices.length, success: batchResult.success, failed: batchResult.failed };

            const status = batchResult.failed === 0 ? 'success' : batchResult.success > 0 ? 'partial' : 'failed';
            await logPushHistory(db, {
              user_id: task.user_id, type: 'broadcast', title: task.title, body: task.body,
              bundle_id: bundleId, sandbox: task.sandbox, target_count: devices.length,
              success_count: batchResult.success, failed_count: batchResult.failed,
              unregistered_count: batchResult.unregistered,
              errors: batchResult.errors?.length ? batchResult.errors : null,
              status, duration_ms: batchResult.duration,
            });
          }
        } else {
          if (!task.device_token) {
            result = { error: '缺少 device_token' };
          } else {
            const sendResult = await apnsService.send(task.device_token, payload, {
              ...creds, bundleId, sandbox: task.sandbox ?? false, priority: 10,
            });
            const ok = sendResult.status === 200;
            const schedReason = sendResult.body?.reason;
            result = { status: sendResult.status, apns_id: sendResult.apnsId, reason: schedReason, reason_cn: ok ? '推送发送成功' : getReasonCN(schedReason) };

            await logPushHistory(db, {
              user_id: task.user_id, type: 'single', title: task.title, body: task.body,
              bundle_id: bundleId, sandbox: task.sandbox, device_token: task.device_token,
              apns_id: sendResult.apnsId, target_count: 1,
              success_count: ok ? 1 : 0, failed_count: ok ? 0 : 1,
              errors: ok ? null : [{ token: task.device_token.substring(0, 8) + '...', reason: sendResult.body?.reason }],
              status: ok ? 'success' : 'failed', duration_ms: sendResult.duration,
            });
          }
        }

        const finalStatus = result.error ? 'failed' : (result.failed > 0 && result.success > 0 ? 'partial' : result.failed > 0 ? 'failed' : 'success');
        await db.prepare("UPDATE scheduled_pushes SET status = ?, result = ?, executed_at = NOW() WHERE id = ?")
          .run(finalStatus, JSON.stringify(result), task.id);

      } catch (err) {
        console.error(`定时推送 #${task.id} 执行失败:`, err.message);
        await db.prepare("UPDATE scheduled_pushes SET status = 'failed', result = ?, executed_at = NOW() WHERE id = ?")
          .run(JSON.stringify({ error: err.message }), task.id);
      }
    }
  } catch (err) {
    console.error('定时推送调度器错误:', err.message);
  }
}

setInterval(executeScheduledPushes, 30000);
setTimeout(executeScheduledPushes, 5000);

module.exports = router;
