const express = require('express');
const router = express.Router();
const { getDb } = require('../config/database');
const AppleApiService = require('../services/apple-api');
const { getDecryptedAccount } = require('../services/account-helper');

const SEVERITY = { critical: 'critical', warning: 'warning', info: 'info', ok: 'ok' };

function daysDiff(dateStr) {
  if (!dateStr) return null;
  const target = new Date(dateStr);
  const now = new Date();
  return Math.ceil((target - now) / (1000 * 60 * 60 * 24));
}

function certStatus(daysLeft) {
  if (daysLeft === null) return { severity: SEVERITY.info, label: '未知', color: '#909399' };
  if (daysLeft < 0) return { severity: SEVERITY.critical, label: '已过期', color: '#f56c6c' };
  if (daysLeft <= 7) return { severity: SEVERITY.critical, label: `${daysLeft} 天后过期`, color: '#f56c6c' };
  if (daysLeft <= 30) return { severity: SEVERITY.warning, label: `${daysLeft} 天后过期`, color: '#e6a23c' };
  if (daysLeft <= 90) return { severity: SEVERITY.info, label: `${daysLeft} 天后过期`, color: '#409eff' };
  return { severity: SEVERITY.ok, label: `有效 (${daysLeft} 天)`, color: '#67c23a' };
}

router.get('/local', async (req, res) => {
  const db = getDb();
  const issues = [];
  const summary = { total: 0, critical: 0, warning: 0, info: 0, ok: 0 };

  const certs = req.user.role === 'superadmin'
    ? await db.prepare('SELECT * FROM certificates ORDER BY created_at DESC').all()
    : await db.prepare('SELECT * FROM certificates WHERE user_id = ? ORDER BY created_at DESC').all(req.user.id);
  const certResults = certs.map(cert => {
    const days = daysDiff(cert.expires_at);
    const status = certStatus(days);
    summary.total++;
    summary[status.severity]++;

    if (status.severity === SEVERITY.critical || status.severity === SEVERITY.warning) {
      issues.push({
        type: 'certificate',
        severity: status.severity,
        id: cert.id,
        name: cert.name,
        message: days < 0
          ? `证书「${cert.name}」已过期 ${Math.abs(days)} 天，请尽快更换`
          : `证书「${cert.name}」将在 ${days} 天后过期`,
        suggestion: cert.is_self_signed
          ? '请重新生成自签证书'
          : '请在证书管理中重新创建并下载新的 P12 证书',
        expires_at: cert.expires_at,
      });
    }

    return {
      id: cert.id,
      name: cert.name,
      type: cert.type,
      is_self_signed: !!cert.is_self_signed,
      expires_at: cert.expires_at,
      days_left: days,
      ...status,
    };
  });

  const profiles = req.user.role === 'superadmin'
    ? await db.prepare('SELECT * FROM profiles ORDER BY created_at DESC').all()
    : await db.prepare('SELECT * FROM profiles WHERE account_id IN (SELECT id FROM accounts WHERE user_id = ?) ORDER BY created_at DESC').all(req.user.id);
  const profileResults = profiles.map(profile => {
    const days = daysDiff(profile.expires_at);
    const status = certStatus(days);
    summary.total++;
    summary[status.severity]++;

    if (status.severity === SEVERITY.critical || status.severity === SEVERITY.warning) {
      issues.push({
        type: 'profile',
        severity: status.severity,
        id: profile.id,
        name: profile.name,
        message: days < 0
          ? `描述文件「${profile.name}」已过期 ${Math.abs(days)} 天`
          : `描述文件「${profile.name}」将在 ${days} 天后过期`,
        suggestion: '请在描述文件管理中重新创建',
        expires_at: profile.expires_at,
      });
    }

    return {
      id: profile.id,
      name: profile.name,
      type: profile.type,
      expires_at: profile.expires_at,
      days_left: days,
      ...status,
    };
  });

  const accounts = req.user.role === 'superadmin'
    ? await db.prepare('SELECT id, name, issuer_id, key_id FROM accounts').all()
    : await db.prepare('SELECT id, name, issuer_id, key_id FROM accounts WHERE user_id = ?').all(req.user.id);
  if (accounts.length === 0) {
    issues.push({
      type: 'account',
      severity: SEVERITY.warning,
      message: '尚未配置任何 Apple 开发者账号',
      suggestion: '请在账号管理中添加 API Key 配置',
    });
    summary.total++;
    summary.warning++;
  }

  for (const acc of accounts) {
    const certCount = await db.prepare('SELECT COUNT(*) as c FROM certificates WHERE account_id = ?').get(acc.id);
    if (certCount.c === 0) {
      issues.push({
        type: 'account',
        severity: SEVERITY.info,
        id: acc.id,
        name: acc.name,
        message: `账号「${acc.name}」下没有任何证书`,
        suggestion: '如需使用该账号，请创建开发或发布证书',
      });
      summary.total++;
      summary.info++;
    }
  }

  issues.sort((a, b) => {
    const order = { critical: 0, warning: 1, info: 2 };
    return (order[a.severity] ?? 3) - (order[b.severity] ?? 3);
  });

  res.json({
    success: true,
    data: {
      check_time: new Date().toISOString(),
      summary,
      issues,
      certificates: certResults,
      profiles: profileResults,
    }
  });
});

router.get('/remote', async (req, res, next) => {
  try {
    const { account_id } = req.query;
    if (!account_id) return res.status(400).json({ success: false, message: '缺少 account_id' });

    const db = getDb();
    let account;
    try { account = await getDecryptedAccount(account_id); } catch (e) { if (e.status === 404) return res.status(404).json({ success: false, message: '账号不存在' }); throw e; }

    // Check if the db account belongs to this user
    const dbAccount = await db.prepare('SELECT user_id FROM accounts WHERE id = ?').get(account_id);
    if (dbAccount && dbAccount.user_id && dbAccount.user_id !== req.user.id && req.user.role !== 'superadmin') {
      return res.status(403).json({ success: false, message: '无权操作此账号' });
    }

    const api = new AppleApiService(account);
    const issues = [];

    let apiOk = false;
    try {
      await api.listCertificates({ limit: 1 });
      apiOk = true;
    } catch (err) {
      issues.push({
        type: 'api',
        severity: SEVERITY.critical,
        message: `Apple API 连接失败: ${err.message}`,
        suggestion: '请检查 Issuer ID、Key ID 和 .p8 私钥是否正确',
      });
    }

    if (!apiOk) {
      return res.json({ success: true, data: { api_status: 'failed', issues } });
    }

    const remoteCerts = await api.listCertificates();
    const remoteCertResults = (remoteCerts.data || []).map(cert => {
      const days = daysDiff(cert.attributes.expirationDate);
      const status = certStatus(days);

      if (status.severity === SEVERITY.critical || status.severity === SEVERITY.warning) {
        issues.push({
          type: 'remote_certificate',
          severity: status.severity,
          apple_id: cert.id,
          name: cert.attributes.name || cert.attributes.certificateType,
          message: days < 0
            ? `Apple 证书「${cert.attributes.name || cert.id}」(${cert.attributes.certificateType}) 已过期`
            : `Apple 证书「${cert.attributes.name || cert.id}」(${cert.attributes.certificateType}) 将在 ${days} 天后过期`,
          suggestion: '请重新创建该类型证书',
          expires_at: cert.attributes.expirationDate,
        });
      }

      return {
        id: cert.id,
        apple_id: cert.id,
        name: cert.attributes.name,
        type: cert.attributes.certificateType,
        expires_at: cert.attributes.expirationDate,
        days_left: days,
        ...status,
      };
    });

    const remoteProfiles = await api.listProfiles();
    const remoteProfileResults = (remoteProfiles.data || []).map(p => {
      const days = daysDiff(p.attributes.expirationDate);
      const status = certStatus(days);

      if (status.severity === SEVERITY.critical || status.severity === SEVERITY.warning) {
        issues.push({
          type: 'remote_profile',
          severity: status.severity,
          apple_id: p.id,
          name: p.attributes.name,
          message: `描述文件「${p.attributes.name}」(${p.attributes.profileType}) ${days < 0 ? '已过期' : `${days} 天后过期`}`,
          suggestion: '请删除旧描述文件并重新创建',
        });
      }

      return {
        id: p.id,
        apple_id: p.id,
        name: p.attributes.name,
        type: p.attributes.profileType,
        state: p.attributes.profileState,
        expires_at: p.attributes.expirationDate,
        days_left: days,
        ...status,
      };
    });

    const bundleIds = await api.listBundleIds();
    const capabilityResults = [];

    for (const bid of (bundleIds.data || []).slice(0, 10)) {
      try {
        const caps = await api.listCapabilities(bid.id);
        const enabledCaps = (caps.data || []).map(c => c.attributes.capabilityType);

        const hasPush = enabledCaps.includes('PUSH_NOTIFICATIONS');
        const hasSignIn = enabledCaps.includes('APPLE_ID_AUTH');

        capabilityResults.push({
          bundle_id: bid.id,
          identifier: bid.attributes.identifier,
          name: bid.attributes.name,
          enabled_count: enabledCaps.length,
          capabilities: enabledCaps,
          has_push: hasPush,
          has_sign_in: hasSignIn,
        });

        if (!hasPush) {
          issues.push({
            type: 'capability',
            severity: SEVERITY.info,
            bundle_id: bid.id,
            name: bid.attributes.identifier,
            message: `「${bid.attributes.identifier}」未开启推送通知权限`,
            suggestion: '如需推送功能，请在权限管理中开启 PUSH_NOTIFICATIONS',
          });
        }
      } catch {
        // some bundle IDs may not support capabilities
      }
    }

    issues.sort((a, b) => {
      const order = { critical: 0, warning: 1, info: 2 };
      return (order[a.severity] ?? 3) - (order[b.severity] ?? 3);
    });

    res.json({
      success: true,
      data: {
        api_status: 'ok',
        check_time: new Date().toISOString(),
        issues,
        certificates: remoteCertResults,
        profiles: remoteProfileResults,
        capabilities: capabilityResults,
      }
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
