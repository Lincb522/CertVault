const express = require('express');
const router = express.Router();
const path = require('path');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');
const { getDb } = require('../config/database');
const AppleApiService = require('../services/apple-api');
const { getDecryptedAccount, checkAccountOwnership } = require('../services/account-helper');
const { parseProvisioningProfile, parseProfileFromBase64 } = require('../services/profile-parser');
const { sendPushToUser } = require('../services/push-helper');

const PROFILE_DIR = path.join(__dirname, '../../data/profiles');
if (!fs.existsSync(PROFILE_DIR)) fs.mkdirSync(PROFILE_DIR, { recursive: true });

const PROFILE_TYPES = [
  { value: 'IOS_APP_DEVELOPMENT', label: 'iOS 开发描述文件',      desc: '用于真机调试，需选择设备' },
  { value: 'IOS_APP_STORE',       label: 'iOS App Store 描述文件', desc: '用于提交 App Store 审核发布' },
  { value: 'IOS_APP_ADHOC',       label: 'iOS Ad Hoc 描述文件',    desc: '用于分发给指定测试设备（最多100台）' },
  { value: 'IOS_APP_INHOUSE',     label: 'iOS 企业内部描述文件',   desc: '用于企业账号内部分发，无设备数量限制' },
  { value: 'MAC_APP_DEVELOPMENT', label: 'macOS 开发描述文件',     desc: '用于 macOS App 开发调试' },
  { value: 'MAC_APP_STORE',       label: 'macOS App Store 描述文件', desc: '用于提交 Mac App Store 发布' },
  { value: 'MAC_APP_DIRECT',      label: 'macOS 直接分发描述文件', desc: '用于 Mac App Store 外直接分发' },
  { value: 'TVOS_APP_DEVELOPMENT', label: 'tvOS 开发描述文件',     desc: '用于 Apple TV App 开发调试' },
  { value: 'TVOS_APP_STORE',      label: 'tvOS App Store 描述文件', desc: '用于提交 tvOS App Store 发布' },
  { value: 'TVOS_APP_ADHOC',      label: 'tvOS Ad Hoc 描述文件',   desc: '用于 Apple TV 测试分发' },
  { value: 'TVOS_APP_INHOUSE',    label: 'tvOS 企业内部描述文件',  desc: '用于 Apple TV 企业内部分发' },
];

router.get('/types', (req, res) => {
  res.json({ success: true, data: PROFILE_TYPES });
});

router.get('/bundle-ids', async (req, res, next) => {
  try {
    const { account_id } = req.query;
    if (!account_id) return res.status(400).json({ success: false, message: '缺少 account_id' });

    const db = getDb();
    let account;
    try { account = await getDecryptedAccount(account_id); } catch (e) { if (e.status === 404) return res.status(404).json({ success: false, message: '账号不存在' }); throw e; }

    const api = new AppleApiService(account);
    const result = await api.listBundleIds();

    const syncMany = db.transaction(async (txDb) => {
      const upsert = txDb.prepare(`
        INSERT INTO bundle_ids (id, account_id, apple_id, identifier, name, platform)
        VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET identifier=excluded.identifier, name=excluded.name
      `);
      for (const b of (result.data || [])) {
        await upsert.run(b.id, account_id, b.id, b.attributes.identifier, b.attributes.name, b.attributes.platform);
      }
    });

    await syncMany();

    const bundleIds = await db.prepare('SELECT * FROM bundle_ids WHERE account_id = ? ORDER BY created_at DESC').all(account_id);
    res.json({ success: true, data: bundleIds });
  } catch (err) {
    next(err);
  }
});

router.post('/bundle-ids', async (req, res, next) => {
  try {
    const { account_id, identifier, name, platform = 'IOS' } = req.body;
    if (!account_id || !identifier || !name) {
      return res.status(400).json({ success: false, message: '请填写所有必填字段' });
    }
    if (!await checkAccountOwnership(account_id, req.user)) {
      return res.status(403).json({ success: false, message: '无权操作此账号的描述文件' });
    }

    const db = getDb();
    let account;
    try { account = await getDecryptedAccount(account_id); } catch (e) { if (e.status === 404) return res.status(404).json({ success: false, message: '账号不存在' }); throw e; }

    const api = new AppleApiService(account);
    const result = await api.createBundleId(identifier, name, platform);

    const bundleId = result.data;
    await db.prepare('INSERT INTO bundle_ids (id, account_id, apple_id, identifier, name, platform) VALUES (?, ?, ?, ?, ?, ?)')
      .run(bundleId.id, account_id, bundleId.id, bundleId.attributes.identifier, bundleId.attributes.name, bundleId.attributes.platform);

    res.json({ success: true, data: bundleId });
  } catch (err) {
    next(err);
  }
});

router.delete('/bundle-ids/:id', async (req, res, next) => {
  try {
    const db = getDb();
    const bundleId = await db.prepare('SELECT * FROM bundle_ids WHERE id = ?').get(req.params.id);
    if (!bundleId) return res.status(404).json({ success: false, message: 'Bundle ID 不存在' });
    if (!await checkAccountOwnership(bundleId.account_id, req.user)) {
      return res.status(403).json({ success: false, message: '无权操作此账号的描述文件' });
    }

    let account;
    try { account = await getDecryptedAccount(bundleId.account_id); } catch (e) { /* account may not exist */ }
    if (account) {
      const api = new AppleApiService(account);
      await api.deleteBundleId(bundleId.apple_id || bundleId.id);
    }

    await db.prepare('DELETE FROM bundle_ids WHERE id = ?').run(req.params.id);
    res.json({ success: true, message: '删除成功' });
  } catch (err) {
    next(err);
  }
});

router.get('/', async (req, res, next) => {
  try {
    const { account_id } = req.query;
    if (!account_id) return res.status(400).json({ success: false, message: '缺少 account_id' });
    if (!await checkAccountOwnership(account_id, req.user)) {
      return res.status(403).json({ success: false, message: '无权操作此账号的描述文件' });
    }

    const db = getDb();
    let account;
    try { account = await getDecryptedAccount(account_id); } catch (e) { if (e.status === 404) return res.status(404).json({ success: false, message: '账号不存在' }); throw e; }

    const api = new AppleApiService(account);
    let remoteProfiles = [];
    try {
      const result = await api.listProfiles();
      remoteProfiles = result.data || [];
    } catch (e) {
      // API failure - still return local data
    }

    if (remoteProfiles.length > 0) {
      const localIdsRows = await db.prepare('SELECT id FROM profiles WHERE account_id = ?').all(account_id);
      const localIds = new Set(localIdsRows.map(p => p.id));
      const localAppleIdsRows = await db.prepare('SELECT apple_id FROM profiles WHERE account_id = ? AND apple_id IS NOT NULL').all(account_id);
      const localAppleIds = new Set(localAppleIdsRows.map(p => p.apple_id));

      const syncRemote = db.transaction(async (txDb) => {
        const txUpsert = txDb.prepare(`INSERT INTO profiles (id, account_id, apple_id, name, type, profile_content, expires_at)
          VALUES (?, ?, ?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET
          name=excluded.name, type=excluded.type, profile_content=COALESCE(excluded.profile_content, profiles.profile_content), expires_at=excluded.expires_at`);
        for (const p of remoteProfiles) {
          if (!localIds.has(p.id) && !localAppleIds.has(p.id)) {
            const profileContent = p.attributes.profileContent || null;
            let profilePath = null;

            if (profileContent) {
              const profileId = p.id;
              const filename = `${profileId}.mobileprovision`;
              const filePath = path.join(PROFILE_DIR, filename);
              try {
                fs.writeFileSync(filePath, Buffer.from(profileContent, 'base64'));
                profilePath = filename;
              } catch (e) { /* write failed, skip file */ }
            }

            await txUpsert.run(
              p.id, account_id, p.id,
              p.attributes.name || p.attributes.profileType,
              p.attributes.profileType,
              profileContent,
              p.attributes.expirationDate || null
            );

            if (profilePath) {
              await txDb.prepare('UPDATE profiles SET profile_path = ? WHERE id = ?').run(profilePath, p.id);
            }
          }
        }
      });
      await syncRemote();
    }

    const profiles = await db.prepare('SELECT * FROM profiles WHERE account_id = ? ORDER BY created_at DESC').all(account_id);
    res.json({ success: true, data: profiles });
  } catch (err) {
    next(err);
  }
});

router.post('/create', async (req, res, next) => {
  try {
    const { account_id, name, type, bundle_id, certificate_ids, device_ids = [] } = req.body;
    if (!account_id || !name || !type || !bundle_id || !certificate_ids?.length) {
      return res.status(400).json({ success: false, message: '请填写所有必填字段' });
    }
    if (!await checkAccountOwnership(account_id, req.user)) {
      return res.status(403).json({ success: false, message: '无权操作此账号的描述文件' });
    }

    const db = getDb();
    let account;
    try { account = await getDecryptedAccount(account_id); } catch (e) { if (e.status === 404) return res.status(404).json({ success: false, message: '账号不存在' }); throw e; }

    const api = new AppleApiService(account);
    const result = await api.createProfile(name, type, bundle_id, certificate_ids, device_ids);

    const profile = result.data;
    const profileId = uuidv4();
    const profileFilename = `${profileId}.mobileprovision`;
    const profilePath = path.join(PROFILE_DIR, profileFilename);

    if (profile.attributes.profileContent) {
      const content = Buffer.from(profile.attributes.profileContent, 'base64');
      fs.writeFileSync(profilePath, content);
    }

    await db.prepare(`INSERT INTO profiles (id, account_id, apple_id, name, type, bundle_id, profile_content, profile_path, expires_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`).run(
      profileId, account_id, profile.id, name, type, bundle_id,
      profile.attributes.profileContent || null,
      profileFilename,
      profile.attributes.expirationDate || null
    );

    res.json({
      success: true,
      data: {
        id: profileId,
        apple_id: profile.id,
        name,
        type,
        profile_path: profileFilename,
        expires_at: profile.attributes.expirationDate
      }
    });

    sendPushToUser(req.user.id, '描述文件创建完成', `${name} 已创建`, { type: 'task_complete' });
  } catch (err) {
    next(err);
  }
});

router.get('/:id/download', async (req, res, next) => {
  try {
    const db = getDb();
    const profile = await db.prepare('SELECT * FROM profiles WHERE id = ?').get(req.params.id);
    if (!profile) return res.status(404).json({ success: false, message: '描述文件不存在' });
    if (!await checkAccountOwnership(profile.account_id, req.user)) {
      return res.status(403).json({ success: false, message: '无权操作此账号的描述文件' });
    }

    if (!profile.profile_path || typeof profile.profile_path !== 'string') {
      return res.status(400).json({
        success: false,
        message: '该描述文件从 Apple 同步而来，本地尚未保存文件。请到描述文件列表重新下载或通过「一键绑定」生成。'
      });
    }
    const profilePath = path.join(PROFILE_DIR, profile.profile_path);
    if (!fs.existsSync(profilePath)) {
      return res.status(404).json({ success: false, message: '描述文件不存在' });
    }

    res.download(profilePath, `${profile.name || 'profile'}.mobileprovision`);
  } catch (err) {
    next(err);
  }
});

router.get('/:id/detail', async (req, res, next) => {
  try {
    const db = getDb();
    const profile = await db.prepare('SELECT * FROM profiles WHERE id = ?').get(req.params.id);
    if (!profile) return res.status(404).json({ success: false, message: '描述文件不存在' });
    if (!await checkAccountOwnership(profile.account_id, req.user)) {
      return res.status(403).json({ success: false, message: '无权操作此账号的描述文件' });
    }

    let devices = [];
    let parsed = null;

    if (profile.profile_path) {
      const fullPath = path.join(PROFILE_DIR, profile.profile_path);
      parsed = parseProvisioningProfile(fullPath);
    }
    if (!parsed && profile.profile_content) {
      parsed = parseProfileFromBase64(profile.profile_content);
    }

    if (parsed && parsed.devices && parsed.devices.length > 0) {
      const allDevices = await db.prepare(
        'SELECT id, name, udid, platform, status, model, device_class, created_at FROM devices WHERE account_id = ?'
      ).all(profile.account_id);

      const profileUdids = new Set(parsed.devices.map(d => d.toUpperCase().replace(/-/g, '')));
      devices = allDevices.filter(dev => {
        const normalizedUdid = dev.udid ? dev.udid.toUpperCase().replace(/-/g, '') : '';
        return profileUdids.has(normalizedUdid);
      });
    }

    let bundleInfo = null;
    if (profile.bundle_id) {
      bundleInfo = await db.prepare('SELECT id, name, identifier, platform FROM bundle_ids WHERE id = ?').get(profile.bundle_id);
    }

    let certInfo = [];
    const certLinks = await db.prepare(
      'SELECT DISTINCT cert_id FROM device_resources WHERE profile_id = ?'
    ).all(req.params.id);
    if (certLinks.length > 0) {
      for (const cl of certLinks) {
        if (cl.cert_id) {
          const cert = await db.prepare(
            'SELECT id, name, type, expires_at, created_at FROM certificates WHERE id = ?'
          ).get(cl.cert_id);
          if (cert) certInfo.push(cert);
        }
      }
    }

    res.json({
      success: true,
      data: {
        ...profile,
        has_file: !!profile.profile_path,
        devices,
        bundle_info: bundleInfo,
        certificates: certInfo,
      }
    });
  } catch (err) {
    next(err);
  }
});

router.delete('/:id', async (req, res, next) => {
  try {
    const db = getDb();
    const profile = await db.prepare('SELECT * FROM profiles WHERE id = ?').get(req.params.id);
    if (!profile) return res.status(404).json({ success: false, message: '描述文件不存在' });
    if (!await checkAccountOwnership(profile.account_id, req.user)) {
      return res.status(403).json({ success: false, message: '无权操作此账号的描述文件' });
    }

    if (profile.apple_id && profile.account_id) {
      let account;
      try { account = await getDecryptedAccount(profile.account_id); } catch (e) { /* account may not exist */ }
      if (account) {
        try {
          const api = new AppleApiService(account);
          await api.deleteProfile(profile.apple_id);
        } catch (e) { /* may already be deleted */ }
      }
    }

    if (profile.profile_path) {
      const filePath = path.join(PROFILE_DIR, profile.profile_path);
      if (fs.existsSync(filePath)) fs.unlinkSync(filePath);
    }

    await db.prepare('DELETE FROM profiles WHERE id = ?').run(req.params.id);
    res.json({ success: true, message: '删除成功' });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
