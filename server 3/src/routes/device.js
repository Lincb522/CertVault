const express = require('express');
const router = express.Router();
const path = require('path');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');
const { getDb } = require('../config/database');
const AppleApiService = require('../services/apple-api');
const CryptoService = require('../services/crypto');
const { getDecryptedAccount, checkAccountOwnership } = require('../services/account-helper');
const { parseProvisioningProfile, parseProfileFromBase64 } = require('../services/profile-parser');
const { sendPushToUser } = require('../services/apns-service');

const CERT_DIR = path.join(__dirname, '../../data/certificates');
const PROFILE_DIR = path.join(__dirname, '../../data/profiles');
if (!fs.existsSync(CERT_DIR)) fs.mkdirSync(CERT_DIR, { recursive: true });
if (!fs.existsSync(PROFILE_DIR)) fs.mkdirSync(PROFILE_DIR, { recursive: true });

async function getAccount(accountId) {
  return await getDecryptedAccount(accountId);
}

async function syncDeviceResources(api, db, account_id) {
  let profilesResult;
  try {
    profilesResult = await api.listProfilesWithRelations();
  } catch (e) {
    return;
  }
  const profiles = profilesResult.data || [];
  const included = profilesResult.included || [];

  const certsMap = {};
  const bundlesMap = {};
  const devicesMap = {};
  for (const item of included) {
    if (item.type === 'certificates') {
      certsMap[item.id] = item;
    } else if (item.type === 'bundleIds') {
      bundlesMap[item.id] = item;
    } else if (item.type === 'devices') {
      devicesMap[item.id] = item;
    }
  }

  for (const [bId, b] of Object.entries(bundlesMap)) {
    await db.prepare(`INSERT INTO bundle_ids (id, account_id, apple_id, identifier, name, platform)
      VALUES (?, ?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET identifier=excluded.identifier, name=excluded.name`)
      .run(bId, account_id, bId, b.attributes.identifier, b.attributes.name, b.attributes.platform);
  }

  const deletedCertRows = await db.prepare('SELECT apple_id FROM deleted_apple_certs WHERE account_id = ?').all(account_id);
  const deletedCertIds = new Set(deletedCertRows.map(r => r.apple_id));

  for (const [cId, c] of Object.entries(certsMap)) {
    if (deletedCertIds.has(cId)) continue;
    const existingByApple = await db.prepare(
      'SELECT id FROM certificates WHERE apple_id = ? AND id != ?'
    ).get(cId, cId);
    if (existingByApple) {
      await db.prepare(
        'UPDATE certificates SET name = ?, cert_content = COALESCE(?, cert_content), expires_at = ? WHERE id = ?'
      ).run(c.attributes.name || c.attributes.certificateType, c.attributes.certificateContent || null,
        c.attributes.expirationDate || null, existingByApple.id);
    } else {
      await db.prepare(`INSERT INTO certificates (id, account_id, apple_id, type, name, cert_content, expires_at)
        VALUES (?, ?, ?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET
        name=excluded.name, cert_content=COALESCE(excluded.cert_content, certificates.cert_content), expires_at=excluded.expires_at`)
        .run(cId, account_id, cId, c.attributes.certificateType, c.attributes.name || c.attributes.certificateType,
          c.attributes.certificateContent || null, c.attributes.expirationDate || null);
    }
  }

  for (const p of profiles) {
    const bundleRel = p.relationships?.bundleId?.data;
    const bundleAppleId = bundleRel ? bundleRel.id : null;

    let profilePath = null;
    if (p.attributes.profileContent) {
      const filename = `${p.id}.mobileprovision`;
      const filePath = path.join(PROFILE_DIR, filename);
      if (!fs.existsSync(filePath)) {
        try {
          fs.writeFileSync(filePath, Buffer.from(p.attributes.profileContent, 'base64'));
          profilePath = filename;
        } catch (e) { /* skip */ }
      } else {
        profilePath = filename;
      }
    }

    const existingProfile = await db.prepare(
      'SELECT id FROM profiles WHERE apple_id = ? AND id != ?'
    ).get(p.id, p.id);
    if (existingProfile) {
      await db.prepare(
        `UPDATE profiles SET name = ?, type = ?, bundle_id = COALESCE(?, bundle_id),
         profile_content = COALESCE(?, profile_content),
         profile_path = COALESCE(?, profile_path), expires_at = ? WHERE id = ?`
      ).run(p.attributes.name || p.attributes.profileType,
        p.attributes.profileType, bundleAppleId,
        p.attributes.profileContent || null, profilePath,
        p.attributes.expirationDate || null, existingProfile.id);
    } else {
      await db.prepare(`INSERT INTO profiles (id, account_id, apple_id, name, type, bundle_id, profile_content, profile_path, expires_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET
        name=excluded.name, type=excluded.type, bundle_id=COALESCE(excluded.bundle_id, profiles.bundle_id),
        profile_content=COALESCE(excluded.profile_content, profiles.profile_content),
        profile_path=COALESCE(excluded.profile_path, profiles.profile_path), expires_at=excluded.expires_at`)
        .run(p.id, account_id, p.id, p.attributes.name || p.attributes.profileType,
          p.attributes.profileType, bundleAppleId,
          p.attributes.profileContent || null, profilePath,
          p.attributes.expirationDate || null);
    }
  }

  const localCertsRows = await db.prepare('SELECT id, apple_id FROM certificates WHERE account_id = ?').all(account_id);
  const appleToCertLocal = {};
  for (const c of localCertsRows) {
    if (c.apple_id) appleToCertLocal[c.apple_id] = c.id;
    appleToCertLocal[c.id] = c.id;
  }

  const localProfilesRows = await db.prepare('SELECT id, apple_id FROM profiles WHERE account_id = ?').all(account_id);
  const appleToProfileLocal = {};
  for (const p of localProfilesRows) {
    if (p.apple_id) appleToProfileLocal[p.apple_id] = p.id;
    appleToProfileLocal[p.id] = p.id;
  }

  const existingLinks = await db.prepare(
    'SELECT device_id, profile_id FROM device_resources'
  ).all();
  const existingSet = new Set(existingLinks.map(l => `${l.device_id}:${l.profile_id}`));

  const insertStmt = db.prepare(
    'INSERT INTO device_resources (device_id, udid, cert_id, profile_id, bundle_identifier) VALUES (?, ?, ?, ?, ?)'
  );

  for (const p of profiles) {
    const deviceRels = p.relationships?.devices?.data || [];
    const certRels = p.relationships?.certificates?.data || [];
    const bundleRel = p.relationships?.bundleId?.data;
    if (deviceRels.length === 0) continue;

    const localProfileId = appleToProfileLocal[p.id];
    const bundleIdentifier = bundleRel ? (bundlesMap[bundleRel.id]?.attributes?.identifier || null) : null;
    const localCertId = certRels.length > 0 ? (appleToCertLocal[certRels[0].id] || null) : null;

    for (const dRel of deviceRels) {
      const deviceAppleId = dRel.id;
      const deviceUdid = devicesMap[deviceAppleId]?.attributes?.udid || null;
      const key = `${deviceAppleId}:${localProfileId || p.id}`;
      if (existingSet.has(key)) continue;

      await insertStmt.run(
        deviceAppleId,
        deviceUdid,
        localCertId,
        localProfileId || p.id,
        bundleIdentifier
      );
      existingSet.add(key);
    }
  }
}

router.get('/', async (req, res, next) => {
  try {
    const { account_id } = req.query;
    if (!account_id) return res.status(400).json({ success: false, message: '缺少 account_id' });
    if (!await checkAccountOwnership(account_id, req.user)) {
      return res.status(403).json({ success: false, message: '无权操作此账号的设备' });
    }

    const account = await getAccount(account_id);
    const api = new AppleApiService(account);
    const result = await api.listDevices();

    const db = getDb();

    const syncMany = db.transaction(async (txDb) => {
      const upsert = txDb.prepare(`
        INSERT INTO devices (id, account_id, apple_id, udid, name, platform, status)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET name=excluded.name, status=excluded.status
      `);
      for (const d of (result.data || [])) {
        await upsert.run(
          d.id, account_id, d.id,
          d.attributes.udid, d.attributes.name,
          d.attributes.platform, d.attributes.status
        );
      }
    });

    await syncMany();

    try {
      await syncDeviceResources(api, db, account_id);
    } catch (e) {
      console.error('device_resources sync failed:', e.message);
    }

    const devices = await db.prepare('SELECT * FROM devices WHERE account_id = ? ORDER BY created_at DESC').all(account_id);
    res.json({ success: true, data: devices });
  } catch (err) {
    next(err);
  }
});

router.post('/', async (req, res, next) => {
  try {
    const { account_id, name, udid, platform = 'IOS' } = req.body;
    if (!account_id || !name || !udid) {
      return res.status(400).json({ success: false, message: '请填写所有必填字段' });
    }
    if (!await checkAccountOwnership(account_id, req.user)) {
      return res.status(403).json({ success: false, message: '无权操作此账号的设备' });
    }

    const account = await getAccount(account_id);
    const api = new AppleApiService(account);
    const result = await api.registerDevice(name, udid, platform);

    const db = getDb();
    const device = result.data;
    await db.prepare(`INSERT INTO devices (id, account_id, apple_id, udid, name, platform, status)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET name=excluded.name, udid=excluded.udid, platform=excluded.platform, status=excluded.status`)
      .run(device.id, account_id, device.id, device.attributes.udid, device.attributes.name, device.attributes.platform, device.attributes.status);

    res.json({ success: true, data: device });
  } catch (err) {
    next(err);
  }
});

router.post('/batch', async (req, res, next) => {
  try {
    const { account_id, devices } = req.body;
    if (!account_id || !devices?.length) {
      return res.status(400).json({ success: false, message: '请提供设备列表' });
    }
    if (!await checkAccountOwnership(account_id, req.user)) {
      return res.status(403).json({ success: false, message: '无权操作此账号的设备' });
    }

    const account = await getAccount(account_id);
    const api = new AppleApiService(account);

    const results = [];
    const errors = [];

    for (const d of devices) {
      try {
        const result = await api.registerDevice(d.name, d.udid, d.platform || 'IOS');
        const device = result.data;
        const db = getDb();
        await db.prepare(`INSERT INTO devices (id, account_id, apple_id, udid, name, platform, status)
          VALUES (?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(id) DO UPDATE SET name=excluded.name, udid=excluded.udid, platform=excluded.platform, status=excluded.status`)
          .run(device.id, account_id, device.id, device.attributes.udid, device.attributes.name, device.attributes.platform, device.attributes.status);
        results.push({ udid: d.udid, success: true });
      } catch (err) {
        errors.push({ udid: d.udid, success: false, message: err.message });
      }
    }

    res.json({ success: true, data: { results, errors } });
  } catch (err) {
    next(err);
  }
});

router.patch('/:deviceId/status', async (req, res, next) => {
  try {
    const db = getDb();
    const { status } = req.body;
    if (!['ENABLED', 'DISABLED'].includes(status)) {
      return res.status(400).json({ success: false, message: '无效的状态，仅支持 ENABLED 或 DISABLED' });
    }
    const device = await db.prepare('SELECT * FROM devices WHERE id = ? OR apple_id = ?').get(req.params.deviceId, req.params.deviceId);
    if (!device) return res.status(404).json({ success: false, message: '设备不存在' });
    if (device.account_id && !await checkAccountOwnership(device.account_id, req.user)) {
      return res.status(403).json({ success: false, message: '无权操作此账号的设备' });
    }

    if (device.account_id && device.apple_id) {
      try {
        const account = await getDecryptedAccount(device.account_id);
        const api = new AppleApiService(account);
        await api.request('PATCH', `/devices/${device.apple_id}`, {
          data: { type: 'devices', id: device.apple_id, attributes: { status } }
        });
      } catch (e) {
        return res.status(500).json({ success: false, message: `Apple API 操作失败: ${e.message}` });
      }
    }

    await db.prepare('UPDATE devices SET status = ? WHERE id = ?').run(status, device.id);
    const updated = await db.prepare('SELECT * FROM devices WHERE id = ?').get(device.id);
    res.json({ success: true, data: updated, message: status === 'ENABLED' ? '设备已启用' : '设备已禁用' });
  } catch (err) {
    next(err);
  }
});

router.patch('/:deviceId/status', async (req, res, next) => {
  try {
    const db = getDb();
    const { status } = req.body;
    if (!['ENABLED', 'DISABLED'].includes(status)) {
      return res.status(400).json({ success: false, message: 'status 必须为 ENABLED 或 DISABLED' });
    }
    const device = await db.prepare('SELECT * FROM devices WHERE id = ? OR apple_id = ?').get(req.params.deviceId, req.params.deviceId);
    if (!device) return res.status(404).json({ success: false, message: '设备不存在' });
    if (device.account_id && !await checkAccountOwnership(device.account_id, req.user)) {
      return res.status(403).json({ success: false, message: '无权操作此账号的设备' });
    }

    if (device.account_id && device.apple_id) {
      try {
        const account = await getDecryptedAccount(device.account_id);
        const api = new AppleApiService(account);
        await api.request('PATCH', `/devices/${device.apple_id}`, {
          data: { type: 'devices', id: device.apple_id, attributes: { status } }
        });
      } catch (e) {
        return res.status(500).json({ success: false, message: `Apple API 操作失败: ${e.message}` });
      }
    }

    await db.prepare('UPDATE devices SET status = ? WHERE id = ?').run(status, device.id);
    const updated = await db.prepare('SELECT * FROM devices WHERE id = ?').get(device.id);
    res.json({ success: true, message: status === 'ENABLED' ? '设备已启用' : '设备已禁用', data: updated });
  } catch (err) {
    next(err);
  }
});

router.delete('/:deviceId', async (req, res, next) => {
  try {
    const db = getDb();
    const device = await db.prepare('SELECT * FROM devices WHERE id = ? OR apple_id = ?').get(req.params.deviceId, req.params.deviceId);
    if (!device) return res.status(404).json({ success: false, message: '设备不存在' });
    if (device.account_id && !await checkAccountOwnership(device.account_id, req.user)) {
      return res.status(403).json({ success: false, message: '无权操作此账号的设备' });
    }

    if (req.query.keep_apple !== 'true' && device.account_id && device.apple_id) {
      try {
        const account = await getDecryptedAccount(device.account_id);
        const api = new AppleApiService(account);
        await api.request('PATCH', `/devices/${device.apple_id}`, {
          data: { type: 'devices', id: device.apple_id, attributes: { status: 'DISABLED' } }
        });
      } catch (e) {
        console.log(`[Device] Failed to disable on Apple: ${e.message}`);
      }
    }

    await db.prepare('DELETE FROM device_resources WHERE device_id = ? OR udid = ?').run(device.id, device.udid);
    await db.prepare('DELETE FROM devices WHERE id = ?').run(device.id);

    res.json({ success: true, message: '设备已删除' });
  } catch (err) {
    next(err);
  }
});

router.get('/:deviceId/detail', async (req, res, next) => {
  try {
    const db = getDb();
    const device = await db.prepare('SELECT * FROM devices WHERE id = ? OR apple_id = ?').get(req.params.deviceId, req.params.deviceId);
    if (!device) return res.status(404).json({ success: false, message: '设备不存在' });
    const account_id = device.account_id;
    if (account_id && !await checkAccountOwnership(account_id, req.user)) {
      return res.status(403).json({ success: false, message: '无权操作此账号的设备' });
    }

    const deviceId = device.apple_id || device.id;
    const deviceUdid = device.udid;
    const normalizedUdid = deviceUdid ? deviceUdid.toUpperCase().replace(/-/g, '') : '';

    const allProfiles = await db.prepare(
      'SELECT id, name, type, profile_path, profile_content, bundle_id, expires_at, created_at FROM profiles WHERE account_id = ? ORDER BY created_at DESC'
    ).all(device.account_id);

    const profileIdSet = new Set();
    for (const p of allProfiles) {
      let parsed = null;
      if (p.profile_path) {
        const fullPath = path.join(PROFILE_DIR, p.profile_path);
        parsed = parseProvisioningProfile(fullPath);
      }
      if (!parsed && p.profile_content) {
        parsed = parseProfileFromBase64(p.profile_content);
      }
      if (!parsed || !parsed.devices) continue;

      const normalizedDevices = parsed.devices.map(d => d.toUpperCase().replace(/-/g, ''));
      if (normalizedDevices.includes(normalizedUdid)) {
        profileIdSet.add(p.id);
      }
    }

    let matchedProfiles = [];
    if (profileIdSet.size > 0) {
      const pIds = [...profileIdSet];
      const ph = pIds.map((_, i) => `$${i + 1}`).join(',');
      matchedProfiles = await db.prepare(
        `SELECT id, name, type, profile_path, bundle_id, expires_at, created_at FROM profiles WHERE id IN (${ph}) ORDER BY created_at DESC`
      ).all(...pIds);
      matchedProfiles = matchedProfiles.map(p => ({ ...p, has_file: !!p.profile_path }));
    }

    const certIdSet = new Set();
    const links = await db.prepare(
      'SELECT cert_id FROM device_resources WHERE (device_id = ? OR udid = ?) AND cert_id IS NOT NULL'
    ).all(deviceId, deviceUdid);
    links.forEach(l => certIdSet.add(l.cert_id));

    if (certIdSet.size === 0 && matchedProfiles.length > 0) {
      const pIds = matchedProfiles.map(p => p.id);
      const ph = pIds.map((_, i) => `$${i + 1}`).join(',');
      const profileCertLinks = await db.prepare(
        `SELECT DISTINCT cert_id FROM device_resources WHERE profile_id IN (${ph}) AND cert_id IS NOT NULL`
      ).all(...pIds);
      profileCertLinks.forEach(l => certIdSet.add(l.cert_id));
    }

    let rawCerts = [];
    if (certIdSet.size > 0) {
      const cIds = [...certIdSet];
      const ph = cIds.map((_, i) => `$${i + 1}`).join(',');
      rawCerts = await db.prepare(
        `SELECT id, name, type, apple_id, p12_path, password, expires_at, created_at FROM certificates WHERE id IN (${ph}) ORDER BY created_at DESC`
      ).all(...cIds);
    }

    const seenCerts = new Map();
    const certs = [];
    for (const c of rawCerts) {
      const key = c.apple_id || c.id;
      if (seenCerts.has(key)) {
        const prev = seenCerts.get(key);
        if (!prev.p12_path && c.p12_path) {
          certs[certs.indexOf(prev)] = c;
          seenCerts.set(key, c);
        }
        continue;
      }
      seenCerts.set(key, c);
      certs.push(c);
    }

    const seenProfiles = new Map();
    const dedupedProfiles = [];
    for (const p of matchedProfiles) {
      const key = p.apple_id || p.id;
      if (!seenProfiles.has(key)) {
        seenProfiles.set(key, true);
        dedupedProfiles.push(p);
      }
    }

    res.json({
      success: true,
      data: {
        ...device,
        certificates: certs.map(c => ({ ...c, has_p12: !!c.p12_path })),
        profiles: dedupedProfiles,
      }
    });
  } catch (err) {
    next(err);
  }
});

router.post('/auto-bindall', async (req, res, next) => {
  try {
    let {
      account_id,
      name: deviceName,
      udid,
      platform = 'IOS',
      bundle_identifier,
      bundle_name,
      cert_type = 'IOS_DEVELOPMENT',
      profile_type = 'IOS_APP_DEVELOPMENT',
      password = '123456',
    } = req.body;

    if (!bundle_identifier) {
      const rand = Math.floor(1000 + Math.random() * 9000);
      bundle_identifier = `zj-${rand}.zijiu522.cn`;
    }

    if (!account_id || !deviceName || !udid) {
      return res.status(400).json({
        success: false,
        message: '请填写账号、设备名称和 UDID'
      });
    }
    if (!await checkAccountOwnership(account_id, req.user)) {
      return res.status(403).json({ success: false, message: '无权操作此账号的设备' });
    }

    const account = await getAccount(account_id);
    const api = new AppleApiService(account);
    const db = getDb();
    const steps = [];

    let deviceAppleId;
    try {
      const devResult = await api.registerDevice(deviceName, udid, platform);
      const device = devResult.data;
      deviceAppleId = device.id;
      await db.prepare(`INSERT INTO devices (id, account_id, apple_id, udid, name, platform, status)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET name=excluded.name, udid=excluded.udid, platform=excluded.platform, status=excluded.status`)
        .run(device.id, account_id, device.id, device.attributes.udid, device.attributes.name, device.attributes.platform, device.attributes.status);
      steps.push({ step: 'register_device', status: 'success', message: '设备注册成功' });
    } catch (err) {
      if (err.message?.includes('already exists') || err.message?.includes('ENTITY_ERROR.ATTRIBUTE.INVALID.DUPLICATE')) {
        const allDevices = await api.listDevices({ 'filter[udid]': udid });
        const found = allDevices.data?.find(d => d.attributes.udid === udid);
        if (found) {
          deviceAppleId = found.id;
          steps.push({ step: 'register_device', status: 'skipped', message: '设备已存在，复用' });
        } else {
          throw err;
        }
      } else {
        throw err;
      }
    }

    let certAppleId;
    let certLocalId;
    const existingCert = await db.prepare(
      'SELECT * FROM certificates WHERE account_id = ? AND type = ? AND is_self_signed = 0 ORDER BY created_at DESC LIMIT 1'
    ).get(account_id, cert_type);

    if (existingCert && existingCert.apple_id) {
      certAppleId = existingCert.apple_id;
      certLocalId = existingCert.id;
      steps.push({ step: 'create_certificate', status: 'skipped', message: `复用已有证书: ${existingCert.name}` });
    } else {
      const { privateKeyPem } = CryptoService.generateKeyPair();
      const csrPem = CryptoService.createCSR(privateKeyPem, { commonName: 'Apple Development' });
      const certResult = await api.createCertificate(csrPem, cert_type);
      const certData = certResult.data;
      certAppleId = certData.id;

      const certPem = CryptoService.derToPem(certData.attributes.certificateContent);
      const p12Buffer = CryptoService.createP12(privateKeyPem, certPem, password, cert_type);
      certLocalId = uuidv4();
      const p12Filename = `${certLocalId}.p12`;
      fs.writeFileSync(path.join(CERT_DIR, p12Filename), p12Buffer);

      const certInfo = CryptoService.parseCertInfo(certPem);
      await db.prepare(`INSERT INTO certificates (id, user_id, account_id, apple_id, type, name, csr_content, private_key, cert_content, p12_path, password, expires_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`).run(
        certLocalId, req.user.id, account_id, certData.id, cert_type,
        certInfo.subject.CN || cert_type,
        csrPem, privateKeyPem, certPem, p12Filename, password,
        certInfo.notAfter
      );
      steps.push({ step: 'create_certificate', status: 'success', message: '证书创建成功，P12 已生成' });
    }

    let bundleAppleId;
    const bName = bundle_name || bundle_identifier.split('.')[0] || 'App';
    try {
      const bundleList = await api.listBundleIds({ 'filter[identifier]': bundle_identifier });
      const found = bundleList.data?.find(b => b.attributes.identifier === bundle_identifier);
      if (found) {
        bundleAppleId = found.id;
        await db.prepare(`INSERT INTO bundle_ids (id, account_id, apple_id, identifier, name, platform)
          VALUES (?, ?, ?, ?, ?, ?)
          ON CONFLICT(id) DO UPDATE SET identifier=excluded.identifier, name=excluded.name`)
          .run(found.id, account_id, found.id, found.attributes.identifier, found.attributes.name, found.attributes.platform);
        steps.push({ step: 'create_bundle_id', status: 'skipped', message: `Bundle ID 已存在: ${bundle_identifier}` });
      } else {
        const bundleResult = await api.createBundleId(bundle_identifier, bName, platform === 'MAC_OS' ? 'MAC_OS' : 'IOS');
        const bundleId = bundleResult.data;
        bundleAppleId = bundleId.id;
        await db.prepare('INSERT INTO bundle_ids (id, account_id, apple_id, identifier, name, platform) VALUES (?, ?, ?, ?, ?, ?)')
          .run(bundleId.id, account_id, bundleId.id, bundleId.attributes.identifier, bundleId.attributes.name, bundleId.attributes.platform);
        steps.push({ step: 'create_bundle_id', status: 'success', message: `Bundle ID 创建成功: ${bundle_identifier}` });
      }
    } catch (err) {
      if (err.message?.includes('already exists') || err.message?.includes('ENTITY_ERROR')) {
        const bundleList = await api.listBundleIds();
        const found = bundleList.data?.find(b => b.attributes.identifier === bundle_identifier);
        if (found) {
          bundleAppleId = found.id;
          steps.push({ step: 'create_bundle_id', status: 'skipped', message: `Bundle ID 已存在` });
        } else {
          throw err;
        }
      } else {
        throw err;
      }
    }

    // Enable all capabilities on the Bundle ID
    const ALL_CAPABILITY_TYPES = [
      'PUSH_NOTIFICATIONS', 'APPLE_ID_AUTH', 'IN_APP_PURCHASE',
      'APP_GROUPS', 'ASSOCIATED_DOMAINS', 'ICLOUD',
      'APPLE_PAY', 'WALLET', 'GAME_CENTER',
      'HEALTHKIT', 'HOMEKIT', 'SIRIKIT',
      'NFC_TAG_READING', 'MAPS', 'NETWORK_EXTENSIONS',
      'PERSONAL_VPN', 'ACCESS_WIFI_INFORMATION', 'HOT_SPOT',
      'MULTIPATH', 'DATA_PROTECTION', 'AUTOFILL_CREDENTIAL_PROVIDER',
      'CLASSKIT', 'FONT_INSTALLATION',
      'COREMEDIA_HLS_LOW_LATENCY',
    ];
    const capResults = [];
    for (const capType of ALL_CAPABILITY_TYPES) {
      try {
        await api.enableCapability(bundleAppleId, capType, []);
        capResults.push({ type: capType, success: true });
      } catch (e) {
        capResults.push({ type: capType, success: false, message: e.message });
      }
    }
    const enabledCount = capResults.filter(r => r.success).length;
    steps.push({ step: 'enable_capabilities', status: 'success', message: `已启用 ${enabledCount}/${ALL_CAPABILITY_TYPES.length} 项权限` });

    const profileName = `${bName}_${cert_type.includes('DISTRIBUTION') ? 'Dist' : 'Dev'}_${new Date().toISOString().slice(0, 10)}`;
    const profileResult = await api.createProfile(
      profileName, profile_type, bundleAppleId, [certAppleId], [deviceAppleId]
    );

    const profile = profileResult.data;
    const profileLocalId = uuidv4();
    const profileFilename = `${profileLocalId}.mobileprovision`;
    const profilePath = path.join(PROFILE_DIR, profileFilename);

    if (profile.attributes.profileContent) {
      fs.writeFileSync(profilePath, Buffer.from(profile.attributes.profileContent, 'base64'));
    }

    await db.prepare(`INSERT INTO profiles (id, account_id, apple_id, name, type, bundle_id, profile_content, profile_path, expires_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`).run(
      profileLocalId, account_id, profile.id, profileName, profile_type, bundleAppleId,
      profile.attributes.profileContent || null, profileFilename,
      profile.attributes.expirationDate || null
    );
    steps.push({ step: 'create_profile', status: 'success', message: `描述文件创建成功: ${profileName}` });

    await db.prepare('INSERT INTO device_resources (device_id, udid, cert_id, profile_id, bundle_identifier) VALUES (?, ?, ?, ?, ?)')
      .run(deviceAppleId, udid, certLocalId, profileLocalId, bundle_identifier);

    res.json({
      success: true,
      message: '一键绑定完成',
      data: {
        steps,
        device: { id: deviceAppleId, apple_id: deviceAppleId, name: deviceName, udid, platform, status: 'ENABLED', account_id },
        certificate: { id: certLocalId, apple_id: certAppleId, type: cert_type, password },
        bundle_id: { id: bundleAppleId || bundle_identifier, apple_id: bundleAppleId, identifier: bundle_identifier },
        profile: {
          id: profileLocalId,
          apple_id: profile.id,
          name: profileName,
          type: profile_type,
          profile_path: profileFilename,
          expires_at: profile.attributes.expirationDate
        }
      }
    });

    sendPushToUser(req.user.id, '一键绑定完成', `设备 ${deviceName} 绑定成功`, { type: 'task_complete' });
  } catch (err) {
    next(err);
  }
});

router.get('/:deviceId/resources', async (req, res) => {
  const db = getDb();
  const device = await db.prepare('SELECT * FROM devices WHERE id = ? OR apple_id = ?').get(req.params.deviceId, req.params.deviceId);
  if (!device) return res.status(404).json({ success: false, message: '设备不存在' });

  if (!await checkAccountOwnership(device.account_id, req.user)) {
    return res.status(403).json({ success: false, message: '无权操作此账号的设备' });
  }

  const deviceId = device.apple_id || device.id;
  const deviceUdid = device.udid;

  const links = await db.prepare(
    'SELECT * FROM device_resources WHERE device_id = ? OR udid = ? ORDER BY created_at DESC'
  ).all(deviceId, deviceUdid);

  let certs = [];
  let profiles = [];

  if (links.length > 0) {
    const certIds = [...new Set(links.map(l => l.cert_id).filter(Boolean))];
    const profileIds = [...new Set(links.map(l => l.profile_id).filter(Boolean))];

    if (certIds.length) {
      const placeholders = certIds.map((_, i) => `$${i + 1}`).join(',');
      certs = await db.prepare(
        `SELECT id, name, type, p12_path, password, expires_at, created_at FROM certificates WHERE id IN (${placeholders}) ORDER BY created_at DESC`
      ).all(...certIds);
    }
    if (profileIds.length) {
      const placeholders = profileIds.map((_, i) => `$${i + 1}`).join(',');
      profiles = await db.prepare(
        `SELECT id, name, type, profile_path, expires_at, created_at FROM profiles WHERE id IN (${placeholders}) ORDER BY created_at DESC`
      ).all(...profileIds);
    }
  }

  const bundleIds = [...new Set(links.map(l => l.bundle_identifier).filter(Boolean))];

  res.json({
    success: true,
    data: {
      device: { id: device.id, name: device.name, udid: device.udid, platform: device.platform },
      has_bindlinks: links.length > 0,
      bundle_ids: bundleIds,
      certificates: certs.map(c => ({ ...c, has_p12: !!c.p12_path })),
      profiles: profiles.map(p => ({ ...p, has_file: !!p.profile_path })),
    }
  });
});

router.get('/:deviceId/download-bundle', async (req, res) => {
  const { cert_id, profile_id } = req.query;
  const db = getDb();

  const device = await db.prepare('SELECT * FROM devices WHERE id = ? OR apple_id = ?').get(req.params.deviceId, req.params.deviceId);
  if (!device) return res.status(404).json({ success: false, message: '设备不存在' });

  if (!await checkAccountOwnership(device.account_id, req.user)) {
    return res.status(403).json({ success: false, message: '无权操作此账号的设备' });
  }

  const archiver = require('archiver');
  const archive = archiver('zip', { zlib: { level: 9 } });

  const safeName = device.name.replace(/[^a-zA-Z0-9\u4e00-\u9fa5_-]/g, '_');
  const folderName = `${safeName}_${device.udid}`;
  const zipName = `${safeName}_${device.udid}.zip`;

  res.setHeader('Content-Type', 'application/zip');
  res.setHeader('Content-Disposition', `attachment; filename="${zipName}"`);
  archive.pipe(res);

  let passwordTxt = '';
  passwordTxt += `========================================\n`;
  passwordTxt += `  设备证书包\n`;
  passwordTxt += `========================================\n\n`;
  passwordTxt += `设备名称: ${device.name}\n`;
  passwordTxt += `UDID: ${device.udid}\n`;
  passwordTxt += `平台: ${device.platform}\n`;
  passwordTxt += `导出时间: ${new Date().toLocaleString('zh-CN')}\n\n`;

  const deviceUdid = device.udid;
  const deviceAppleId = device.apple_id || device.id;

  let certIds = cert_id ? [cert_id] : [];
  let profileIds = profile_id ? [profile_id] : [];

  if (!cert_id && !profile_id) {
    const allProfiles = await db.prepare(
      'SELECT id, profile_path, profile_content FROM profiles WHERE account_id = ?'
    ).all(device.account_id);

    for (const p of allProfiles) {
      let parsed = null;
      if (p.profile_path) {
        const fullPath = path.join(PROFILE_DIR, p.profile_path);
        parsed = parseProvisioningProfile(fullPath);
      }
      if (!parsed && p.profile_content) {
        parsed = parseProfileFromBase64(p.profile_content);
      }
      if (!parsed || !parsed.devices) continue;
      const normalizedDevices = parsed.devices.map(d => d.toUpperCase().replace(/-/g, ''));
      const normalizedUdid = deviceUdid ? deviceUdid.toUpperCase().replace(/-/g, '') : '';
      if (normalizedDevices.includes(normalizedUdid)) {
        profileIds.push(p.id);
      }
    }
  }

  if (profile_id && !cert_id) {
    const links = await db.prepare(
      'SELECT cert_id FROM device_resources WHERE profile_id = ? AND cert_id IS NOT NULL'
    ).all(profile_id);
    if (links.length > 0) {
      certIds = [...new Set(links.map(l => l.cert_id))];
    }
  }

  if (certIds.length === 0 && profileIds.length > 0) {
    for (const pid of profileIds) {
      const links = await db.prepare(
        'SELECT cert_id FROM device_resources WHERE profile_id = ? AND cert_id IS NOT NULL'
      ).all(pid);
      links.forEach(l => { if (l.cert_id) certIds.push(l.cert_id); });
    }
    certIds = [...new Set(certIds)];
  }

  passwordTxt += `----------------------------------------\n`;
  passwordTxt += `  证书信息\n`;
  passwordTxt += `----------------------------------------\n\n`;

  async function collectCerts(ids) {
    const results = [];
    for (const cid of ids) {
      const cert = await db.prepare('SELECT * FROM certificates WHERE id = ?').get(cid);
      if (cert && cert.p12_path && fs.existsSync(path.join(CERT_DIR, cert.p12_path))) {
        results.push(cert);
      }
    }
    return results;
  }

  async function collectProfiles(ids) {
    const results = [];
    for (const pid of ids) {
      const profile = await db.prepare('SELECT * FROM profiles WHERE id = ?').get(pid);
      if (profile && profile.profile_path && fs.existsSync(path.join(PROFILE_DIR, profile.profile_path))) {
        results.push(profile);
      }
    }
    return results;
  }

  let certs = certIds.length > 0 ? await collectCerts(certIds) : [];
  if (certs.length === 0 && !cert_id) {
    const allCerts = (await db.prepare('SELECT * FROM certificates WHERE account_id = ? AND p12_path IS NOT NULL ORDER BY created_at DESC').all(device.account_id))
      .filter(c => c.p12_path && fs.existsSync(path.join(CERT_DIR, c.p12_path)));
    if (allCerts.length > 0) certs = [allCerts[0]];
  }

  let profiles = profileIds.length > 0 ? await collectProfiles(profileIds) : [];
  if (profiles.length === 0 && !profile_id) {
    const allProfiles = (await db.prepare('SELECT * FROM profiles WHERE account_id = ? AND profile_path IS NOT NULL ORDER BY created_at DESC').all(device.account_id))
      .filter(p => p.profile_path && fs.existsSync(path.join(PROFILE_DIR, p.profile_path)));
    if (allProfiles.length > 0) profiles = [allProfiles[0]];
  }

  certs.forEach((cert, i) => {
    const suffix = certs.length > 1 ? `_${i + 1}` : '';
    const fileName = `${safeName}${suffix}.p12`;
    archive.file(path.join(CERT_DIR, cert.p12_path), { name: `${folderName}/${fileName}` });
    passwordTxt += `文件: ${fileName}\n`;
    passwordTxt += `证书名称: ${cert.name}\n`;
    passwordTxt += `证书类型: ${cert.type}\n`;
    passwordTxt += `P12 密码: ${cert.password || '123456'}\n`;
    passwordTxt += `过期时间: ${cert.expires_at || '未知'}\n\n`;
  });
  if (certs.length === 0) passwordTxt += `(无证书文件)\n\n`;

  passwordTxt += `----------------------------------------\n`;
  passwordTxt += `  描述文件信息\n`;
  passwordTxt += `----------------------------------------\n\n`;

  profiles.forEach((profile, i) => {
    const suffix = profiles.length > 1 ? `_${i + 1}` : '';
    const fileName = `${safeName}${suffix}.mobileprovision`;
    archive.file(path.join(PROFILE_DIR, profile.profile_path), { name: `${folderName}/${fileName}` });
    passwordTxt += `文件: ${fileName}\n`;
    passwordTxt += `描述文件名称: ${profile.name}\n`;
    passwordTxt += `描述文件类型: ${profile.type}\n`;
    passwordTxt += `过期时间: ${profile.expires_at || '未知'}\n\n`;
  });
  if (profiles.length === 0) passwordTxt += `(无描述文件)\n\n`;

  passwordTxt += `========================================\n`;
  passwordTxt += `  共 ${certs.length} 个证书, ${profiles.length} 个描述文件\n`;
  passwordTxt += `========================================\n`;

  archive.append(passwordTxt, { name: `${folderName}/密码.txt` });
  archive.finalize();
});

module.exports = router;
