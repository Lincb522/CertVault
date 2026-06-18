const express = require('express');
const crypto = require('crypto');
const path = require('path');
const fs = require('fs');
const { execFile } = require('child_process');
const { v4: uuidv4 } = require('uuid');
const router = express.Router();
const { signMobileConfig, canSign } = require('../services/mobileconfig-signer');
const { getDb } = require('../config/database');
const AppleApiService = require('../services/apple-api');
const CryptoService = require('../services/crypto');
const { getDecryptedAccount } = require('../services/account-helper');

const CERT_DIR = path.join(__dirname, '../../data/certificates');
const PROFILE_DIR = path.join(__dirname, '../../data/profiles');
const SIGNED_IPA_DIR = path.join(__dirname, '../../data/signed_ipa');
const ESIGN_IPA_PATH = path.join(__dirname, '../../data/downloads/esign.ipa');
if (!fs.existsSync(SIGNED_IPA_DIR)) fs.mkdirSync(SIGNED_IPA_DIR, { recursive: true });

const pendingUDIDs = new Map();

const APP_NAME = process.env.APP_NAME || 'CertVault';

function resolveAuthToken(req) {
  return req.headers.authorization?.replace('Bearer ', '') || req.query.token;
}

async function resolveUser(token) {
  if (!token) return null;
  const db = getDb();
  const session = await db.prepare(
    "SELECT s.user_id, u.username, u.role FROM sessions s JOIN users u ON s.user_id = u.id WHERE s.token = ? AND s.expires_at::timestamptz > NOW()"
  ).get(token);
  return session ? { id: session.user_id, username: session.username, role: session.role } : null;
}

function generateMobileConfig(callbackUrl, requestId) {
  const uuid1 = crypto.randomUUID().toUpperCase();

  return `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>PayloadContent</key>
  <dict>
    <key>URL</key>
    <string>${callbackUrl}/api/udid/callback/${requestId}</string>
    <key>DeviceAttributes</key>
    <array>
      <string>UDID</string>
      <string>IMEI</string>
      <string>ICCID</string>
      <string>VERSION</string>
      <string>PRODUCT</string>
      <string>DEVICE_NAME</string>
      <string>MAC_ADDRESS_EN0</string>
      <string>SERIAL</string>
    </array>
  </dict>
  <key>PayloadOrganization</key>
  <string>${APP_NAME}</string>
  <key>PayloadDisplayName</key>
  <string>${APP_NAME} - 获取设备 UDID</string>
  <key>PayloadVersion</key>
  <integer>1</integer>
  <key>PayloadUUID</key>
  <string>${uuid1}</string>
  <key>PayloadIdentifier</key>
  <string>com.certvault.udid.${requestId}</string>
  <key>PayloadDescription</key>
  <string>此描述文件由 ${APP_NAME} 生成，仅用于获取设备 UDID，安装后会自动删除，不会修改任何设置。</string>
  <key>PayloadType</key>
  <string>Profile Service</string>
  <key>PayloadRemovalDisallowed</key>
  <false/>
</dict>
</plist>`;
}

// 生成 .mobileconfig 描述文件供 iPhone 安装
router.get('/enroll/:requestId', (req, res) => {
  const { requestId } = req.params;
  const defaultHost = process.env.SERVER_URL || `https://${req.get('host')}`;
  const host = req.query.host || defaultHost;

  const configXml = generateMobileConfig(host, requestId);

  const existing = pendingUDIDs.get(requestId);
  pendingUDIDs.set(requestId, {
    status: 'pending',
    created: Date.now(),
    account_id: existing?.account_id || null,
    auth_token: existing?.auth_token || null,
  });

  for (const [key, val] of pendingUDIDs) {
    if (Date.now() - val.created > 10 * 60 * 1000) pendingUDIDs.delete(key);
  }

  const signed = signMobileConfig(configXml);

  res.setHeader('Content-Type', 'application/x-apple-aspen-config');
  res.setHeader('Content-Disposition', `attachment; filename="udid_${requestId}.mobileconfig"`);
  res.send(signed);
});

// Apple 回调：设备安装描述文件后，系统会 POST 设备信息到这里
router.post('/callback/:requestId', (req, res) => {
  const { requestId } = req.params;

  let body = '';
  req.on('data', chunk => { body += chunk; });
  req.on('end', () => {
    try {
      const udidMatch = body.match(/<key>UDID<\/key>\s*<string>([^<]+)<\/string>/);
      const productMatch = body.match(/<key>PRODUCT<\/key>\s*<string>([^<]+)<\/string>/);
      const versionMatch = body.match(/<key>VERSION<\/key>\s*<string>([^<]+)<\/string>/);
      const serialMatch = body.match(/<key>SERIAL<\/key>\s*<string>([^<]+)<\/string>/);
      const nameMatch = body.match(/<key>DEVICE_NAME<\/key>\s*<string>([^<]+)<\/string>/);
      const imeiMatch = body.match(/<key>IMEI<\/key>\s*<string>([^<]+)<\/string>/);

      const prev = pendingUDIDs.get(requestId) || {};
      const deviceInfo = {
        status: 'success',
        udid: udidMatch?.[1] || '',
        product: productMatch?.[1] || '',
        version: versionMatch?.[1] || '',
        serial: serialMatch?.[1] || '',
        device_name: nameMatch?.[1] || '',
        imei: imeiMatch?.[1] || '',
        time: new Date().toISOString(),
        account_id: prev.account_id || null,
        auth_token: prev.auth_token || null,
      };

      pendingUDIDs.set(requestId, deviceInfo);

      const redirectUrl = `/udid-result?id=${requestId}`;
      res.writeHead(301, { Location: redirectUrl });
      res.end();
    } catch (e) {
      pendingUDIDs.set(requestId, { status: 'error', message: e.message });
      res.status(400).send('解析失败');
    }
  });
});

// 查询 UDID 获取结果
router.get('/result/:requestId', (req, res) => {
  const data = pendingUDIDs.get(req.params.requestId);
  if (!data) {
    return res.json({ success: false, message: '未找到记录或已过期' });
  }
  res.json({ success: true, data });
});

// 生成请求 ID（可携带 account_id 和 auth token，绑定到特定账号）
router.post('/create-request', async (req, res) => {
  const requestId = crypto.randomBytes(8).toString('hex');
  const { account_id } = req.body || {};
  const token = req.headers.authorization?.replace('Bearer ', '') || req.query.token || null;

  const entry = { status: 'pending', created: Date.now(), account_id: account_id || null, auth_token: token || null };

  if (token && account_id) {
    const user = await resolveUser(token);
    if (user) entry.account_name = (await getDb().prepare('SELECT name FROM accounts WHERE id = ?').get(account_id))?.name || null;
  }

  pendingUDIDs.set(requestId, entry);
  res.json({ success: true, data: { request_id: requestId } });
});

router.get('/sign-status', (req, res) => {
  res.json({
    success: true,
    data: {
      signing_enabled: canSign(),
      ssl_cert: process.env.SSL_CERT_PATH || '(未配置)',
      ssl_key: process.env.SSL_KEY_PATH ? '已配置' : '(未配置)',
    }
  });
});

// ===================== UDID 一键绑定接口 =====================

// 登录（供 UDID 详情页使用，返回 token）
router.post('/login', async (req, res) => {
  try {
    const { username, password } = req.body;
    if (!username || !password) return res.status(400).json({ success: false, message: '请输入用户名和密码' });

    const db = getDb();
    const user = await db.prepare('SELECT * FROM users WHERE username = ?').get(username);
    if (!user) return res.status(401).json({ success: false, message: '用户名或密码错误' });

    const cryptoModule = require('crypto');
    const hash = cryptoModule.createHash('sha256').update(password + user.salt).digest('hex');
    if (hash !== user.password) return res.status(401).json({ success: false, message: '用户名或密码错误' });

    const token = cryptoModule.randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + 7 * 24 * 3600 * 1000).toISOString();
    await db.prepare('INSERT INTO sessions (token, user_id, expires_at) VALUES (?, ?, ?)').run(token, user.id, expiresAt);

    res.json({ success: true, data: { token, username: user.username, role: user.role } });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// 获取当前用户的账号列表
router.get('/accounts', async (req, res) => {
  try {
    const user = await resolveUser(resolveAuthToken(req));
    if (!user) return res.status(401).json({ success: false, message: '未登录' });

    const db = getDb();
    let accounts;
    if (user.role === 'superadmin') {
      accounts = await db.prepare('SELECT id, name, issuer_id FROM accounts ORDER BY name').all();
    } else {
      accounts = await db.prepare('SELECT id, name, issuer_id FROM accounts WHERE user_id = ? ORDER BY name').all(user.id);
    }
    res.json({ success: true, data: accounts });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// 查询 UDID 是否已绑定过（有设备+证书+描述文件资源）
router.get('/device-bindinfo', async (req, res) => {
  try {
    const { udid } = req.query;
    if (!udid) return res.status(400).json({ success: false, message: '缺少 udid' });

    const db = getDb();
    const device = await db.prepare('SELECT * FROM devices WHERE udid = ? LIMIT 1').get(udid);
    if (!device) return res.json({ success: true, data: { bound: false } });

    const resources = await db.prepare(
      'SELECT dr.*, c.name as cert_name, c.type as cert_type, c.password as cert_password, c.p12_path, c.expires_at as cert_expires, p.name as profile_name, p.type as profile_type, p.profile_path, p.expires_at as profile_expires FROM device_resources dr LEFT JOIN certificates c ON dr.cert_id = c.id LEFT JOIN profiles p ON dr.profile_id = p.id WHERE dr.udid = ? ORDER BY dr.created_at DESC'
    ).all(udid);

    const validResources = resources.filter(r =>
      r.cert_id && r.profile_id && r.p12_path && r.profile_path &&
      fs.existsSync(path.join(CERT_DIR, r.p12_path)) &&
      fs.existsSync(path.join(PROFILE_DIR, r.profile_path))
    );

    if (validResources.length === 0) {
      return res.json({ success: true, data: { bound: true, has_resources: false, device_name: device.name, account_id: device.account_id } });
    }

    const token = resolveAuthToken(req);
    const user = token ? await resolveUser(token) : null;

    const items = validResources.map(r => {
      const item = {
        cert_id: r.cert_id,
        profile_id: r.profile_id,
        cert_name: r.cert_name,
        cert_type: r.cert_type,
        cert_password: r.cert_password || '123456',
        cert_expires: r.cert_expires,
        profile_name: r.profile_name,
        profile_type: r.profile_type,
        profile_expires: r.profile_expires,
        bundle_identifier: r.bundle_identifier,
      };
      if (user && token) {
        item.download_url = `/api/udid/download-bundle?token=${token}&device_id=${device.id}&cert_id=${r.cert_id}&profile_id=${r.profile_id}`;
      }
      return item;
    });

    res.json({
      success: true,
      data: {
        bound: true,
        has_resources: true,
        device_name: device.name,
        device_id: device.id,
        account_id: device.account_id,
        authenticated: !!user,
        resources: items,
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// 一键绑定设备到 Apple 账号（仅注册设备）
router.post('/bind', async (req, res) => {
  try {
    const user = await resolveUser(resolveAuthToken(req));
    if (!user) return res.status(401).json({ success: false, message: '未登录' });

    const { account_id, udid, name, platform = 'IOS' } = req.body;
    if (!account_id || !udid || !name) {
      return res.status(400).json({ success: false, message: '缺少必要参数 (account_id, udid, name)' });
    }

    const db = getDb();

    if (user.role !== 'superadmin') {
      const acc = await db.prepare('SELECT id FROM accounts WHERE id = ? AND user_id = ?').get(account_id, user.id);
      if (!acc) return res.status(403).json({ success: false, message: '无权操作此账号' });
    }

    const account = await getDecryptedAccount(account_id);
    if (!account) return res.status(404).json({ success: false, message: '账号不存在' });

    const api = new AppleApiService(account);
    const result = await api.registerDevice(name, udid, platform);
    const device = result.data;

    await db.prepare(`INSERT INTO devices (id, account_id, apple_id, udid, name, platform, status)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET name=excluded.name, udid=excluded.udid, platform=excluded.platform, status=excluded.status`)
      .run(device.id, account_id, device.id, device.attributes.udid, device.attributes.name, device.attributes.platform, device.attributes.status);

    res.json({
      success: true,
      message: '设备绑定成功',
      data: {
        device_id: device.id,
        name: device.attributes.name,
        udid: device.attributes.udid,
        platform: device.attributes.platform,
        status: device.attributes.status,
        account_name: account.name
      }
    });
  } catch (err) {
    const msg = err.message || '绑定失败';
    const isAppleErr = msg.includes('ENTITY_ERROR') || msg.includes('already exists') || msg.includes('409');
    res.status(isAppleErr ? 409 : 500).json({
      success: false,
      message: isAppleErr ? '该设备已在此账号下注册' : msg
    });
  }
});

// 一键绑定 + 签名（设备注册 + 证书 + Bundle ID + 描述文件，一条龙）
router.post('/bindall', async (req, res) => {
  try {
    const user = await resolveUser(resolveAuthToken(req));
    if (!user) return res.status(401).json({ success: false, message: '未登录' });

    let {
      account_id,
      udid,
      name: deviceName,
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
      return res.status(400).json({ success: false, message: '请填写账号、设备名称和 UDID' });
    }

    const db = getDb();

    if (user.role !== 'superadmin') {
      const acc = await db.prepare('SELECT id FROM accounts WHERE id = ? AND user_id = ?').get(account_id, user.id);
      if (!acc) return res.status(403).json({ success: false, message: '无权操作此账号' });
    }

    const account = await getDecryptedAccount(account_id);
    if (!account) return res.status(404).json({ success: false, message: '账号不存在' });

    const api = new AppleApiService(account);
    const steps = [];

    // Step 1: Register device
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

    // Step 2: Reuse or create certificate
    let certAppleId, certLocalId, certPassword = password;
    const existingCert = await db.prepare(
      'SELECT * FROM certificates WHERE account_id = ? AND type = ? AND is_self_signed = 0 ORDER BY created_at DESC LIMIT 1'
    ).get(account_id, cert_type);

    if (existingCert && existingCert.apple_id) {
      certAppleId = existingCert.apple_id;
      certLocalId = existingCert.id;
      certPassword = existingCert.password || password;
      steps.push({ step: 'create_certificate', status: 'skipped', message: `复用已有证书: ${existingCert.name}` });
    } else {
      if (!fs.existsSync(CERT_DIR)) fs.mkdirSync(CERT_DIR, { recursive: true });
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
        certLocalId, user.id, account_id, certData.id, cert_type,
        certInfo.subject.CN || cert_type,
        csrPem, privateKeyPem, certPem, p12Filename, password,
        certInfo.notAfter
      );
      steps.push({ step: 'create_certificate', status: 'success', message: '证书创建成功，P12 已生成' });
    }

    // Step 3: Create or reuse Bundle ID
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
          steps.push({ step: 'create_bundle_id', status: 'skipped', message: 'Bundle ID 已存在' });
        } else {
          throw err;
        }
      } else {
        throw err;
      }
    }

    // Step 4: Enable capabilities
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
    let enabledCount = 0;
    for (const capType of ALL_CAPABILITY_TYPES) {
      try {
        await api.enableCapability(bundleAppleId, capType, []);
        enabledCount++;
      } catch (_) {}
    }
    steps.push({ step: 'enable_capabilities', status: 'success', message: `已启用 ${enabledCount}/${ALL_CAPABILITY_TYPES.length} 项权限` });

    // Step 5: Create provisioning profile
    if (!fs.existsSync(PROFILE_DIR)) fs.mkdirSync(PROFILE_DIR, { recursive: true });
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

    // Link device <-> cert <-> profile
    await db.prepare('INSERT INTO device_resources (device_id, udid, cert_id, profile_id, bundle_identifier) VALUES (?, ?, ?, ?, ?)')
      .run(deviceAppleId, udid, certLocalId, profileLocalId, bundle_identifier);

    const downloadUrl = `/api/udid/download-bundle?token=${resolveAuthToken(req)}&device_id=${deviceAppleId}&cert_id=${certLocalId}&profile_id=${profileLocalId}`;

    res.json({
      success: true,
      message: '一键签名绑定完成',
      data: {
        steps,
        device: { id: deviceAppleId, name: deviceName, udid, platform },
        certificate: { id: certLocalId, apple_id: certAppleId, type: cert_type, password: certPassword },
        bundle_id: { apple_id: bundleAppleId, identifier: bundle_identifier },
        profile: { id: profileLocalId, name: profileName, type: profile_type, expires_at: profile.attributes.expirationDate },
        download_url: downloadUrl,
      }
    });
  } catch (err) {
    const msg = err.message || '操作失败';
    res.status(500).json({ success: false, message: msg });
  }
});

// 下载 P12 + 描述文件压缩包
router.get('/download-bundle', async (req, res) => {
  try {
    const user = await resolveUser(resolveAuthToken(req));
    if (!user) return res.status(401).json({ success: false, message: '未登录' });

    const { cert_id, profile_id, device_id } = req.query;
    if (!cert_id || !profile_id) {
      return res.status(400).json({ success: false, message: '缺少 cert_id 或 profile_id' });
    }

    const db = getDb();
    const cert = await db.prepare('SELECT * FROM certificates WHERE id = ?').get(cert_id);
    const profile = await db.prepare('SELECT * FROM profiles WHERE id = ?').get(profile_id);

    if (!cert || !cert.p12_path) return res.status(404).json({ success: false, message: '证书不存在或无 P12 文件' });
    if (!profile || !profile.profile_path) return res.status(404).json({ success: false, message: '描述文件不存在' });

    const certPath = path.join(CERT_DIR, cert.p12_path);
    const profilePath = path.join(PROFILE_DIR, profile.profile_path);

    if (!fs.existsSync(certPath)) return res.status(404).json({ success: false, message: 'P12 文件丢失' });
    if (!fs.existsSync(profilePath)) return res.status(404).json({ success: false, message: '描述文件丢失' });

    const archiver = require('archiver');
    const archive = archiver('zip', { zlib: { level: 9 } });

    const safeName = (cert.name || 'cert').replace(/[^a-zA-Z0-9\u4e00-\u9fa5_-]/g, '_');
    const folderName = `${safeName}_签名包`;
    const zipName = `${safeName}_签名包.zip`;

    res.setHeader('Content-Type', 'application/zip');
    res.setHeader('Content-Disposition', `attachment; filename="${encodeURIComponent(zipName)}"`);
    archive.pipe(res);

    archive.file(certPath, { name: `${folderName}/${safeName}.p12` });
    archive.file(profilePath, { name: `${folderName}/${profile.name || 'profile'}.mobileprovision` });

    let passwordTxt = '';
    passwordTxt += `========================================\n`;
    passwordTxt += `  签名证书包\n`;
    passwordTxt += `========================================\n\n`;
    passwordTxt += `证书名称: ${cert.name}\n`;
    passwordTxt += `证书类型: ${cert.type}\n`;
    passwordTxt += `P12 密码: ${cert.password || '123456'}\n`;
    passwordTxt += `过期时间: ${cert.expires_at || '未知'}\n\n`;
    passwordTxt += `描述文件: ${profile.name}\n`;
    passwordTxt += `描述类型: ${profile.type}\n`;
    passwordTxt += `过期时间: ${profile.expires_at || '未知'}\n\n`;
    passwordTxt += `导出时间: ${new Date().toLocaleString('zh-CN')}\n`;
    passwordTxt += `========================================\n`;

    archive.append(passwordTxt, { name: `${folderName}/密码.txt` });
    archive.finalize();
  } catch (err) {
    if (!res.headersSent) {
      res.status(500).json({ success: false, message: err.message || '下载失败' });
    }
  }
});

// 签名全能签 IPA 并返回 OTA 安装链接
router.post('/sign-esign', async (req, res) => {
  try {
    const user = await resolveUser(resolveAuthToken(req));
    if (!user) return res.status(401).json({ success: false, message: '未登录' });

    const { cert_id, profile_id } = req.body;
    if (!cert_id || !profile_id) {
      return res.status(400).json({ success: false, message: '缺少 cert_id 或 profile_id' });
    }

    if (!fs.existsSync(ESIGN_IPA_PATH)) {
      return res.status(404).json({ success: false, message: '全能签 IPA 文件不存在，请联系管理员上传' });
    }

    const db = getDb();
    const cert = await db.prepare('SELECT * FROM certificates WHERE id = ?').get(cert_id);
    const profile = await db.prepare('SELECT * FROM profiles WHERE id = ?').get(profile_id);

    if (!cert || !cert.p12_path) return res.status(404).json({ success: false, message: '证书不存在' });
    if (!profile || !profile.profile_path) return res.status(404).json({ success: false, message: '描述文件不存在' });

    // 获取实际的 bundle identifier
    let bundleIdentifier = null;
    if (profile.bundle_id) {
      const bundle = await db.prepare('SELECT identifier FROM bundle_ids WHERE id = ? OR apple_id = ?').get(profile.bundle_id, profile.bundle_id);
      if (bundle) bundleIdentifier = bundle.identifier;
    }
    // 从 device_resources 查找
    if (!bundleIdentifier) {
      const dr = await db.prepare('SELECT bundle_identifier FROM device_resources WHERE cert_id = ? AND profile_id = ? LIMIT 1').get(cert_id, profile_id);
      if (dr) bundleIdentifier = dr.bundle_identifier;
    }
    if (!bundleIdentifier) bundleIdentifier = 'com.esign.signed';

    const account_id = cert.account_id;
    const account = await getDecryptedAccount(account_id);
    if (!account) return res.status(404).json({ success: false, message: '关联的开发者账号不存在' });

    // OTA 安装需要 Distribution 证书 + Ad Hoc 描述文件
    let signingCertPath, signingPassword, signingProfilePath;

    const isDev = cert.type === 'IOS_DEVELOPMENT';

    if (isDev) {
      // 复用或创建 Distribution 证书
      let distCert = await db.prepare(
        'SELECT * FROM certificates WHERE account_id = ? AND type = ? AND p12_path IS NOT NULL ORDER BY created_at DESC LIMIT 1'
      ).get(account_id, 'IOS_DISTRIBUTION');

      if (!distCert) {
        const api = new AppleApiService(account);
        if (!fs.existsSync(CERT_DIR)) fs.mkdirSync(CERT_DIR, { recursive: true });
        const { privateKeyPem } = CryptoService.generateKeyPair();
        const csrPem = CryptoService.createCSR(privateKeyPem, { commonName: 'Apple Distribution' });
        const certResult = await api.createCertificate(csrPem, 'IOS_DISTRIBUTION');
        const certData = certResult.data;
        const certPem = CryptoService.derToPem(certData.attributes.certificateContent);
        const distPassword = cert.password || '123456';
        const p12Buffer = CryptoService.createP12(privateKeyPem, certPem, distPassword, 'IOS_DISTRIBUTION');
        const distLocalId = uuidv4();
        const p12Filename = `${distLocalId}.p12`;
        fs.writeFileSync(path.join(CERT_DIR, p12Filename), p12Buffer);
        const certInfo = CryptoService.parseCertInfo(certPem);
        await db.prepare(`INSERT INTO certificates (id, user_id, account_id, apple_id, type, name, csr_content, private_key, cert_content, p12_path, password, expires_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`).run(
          distLocalId, user.id, account_id, certData.id, 'IOS_DISTRIBUTION',
          certInfo.subject.CN || 'iOS Distribution',
          csrPem, privateKeyPem, certPem, p12Filename, distPassword, certInfo.notAfter
        );
        distCert = { id: distLocalId, apple_id: certData.id, p12_path: p12Filename, password: distPassword };
      }

      // 获取设备列表 (从 device_resources 获取绑定的设备)
      const devices = await db.prepare(
        'SELECT DISTINCT d.apple_id FROM device_resources dr JOIN devices d ON dr.device_id = d.id WHERE dr.cert_id = ? OR dr.profile_id = ?'
      ).all(cert_id, profile_id);
      const deviceIds = devices.map(d => d.apple_id).filter(Boolean);

      // 获取 bundle apple_id
      let bundleAppleId = profile.bundle_id;
      if (!bundleAppleId) {
        const b = await db.prepare('SELECT apple_id FROM bundle_ids WHERE identifier = ? LIMIT 1').get(bundleIdentifier);
        if (b) bundleAppleId = b.apple_id;
      }

      // 创建 Ad Hoc 描述文件
      const api = new AppleApiService(account);
      const ahProfileName = `ESign_AdHoc_${new Date().toISOString().slice(0, 10)}_${uuidv4().slice(0, 4)}`;
      const ahResult = await api.createProfile(ahProfileName, 'IOS_APP_ADHOC', bundleAppleId, [distCert.apple_id], deviceIds);
      const ahProfile = ahResult.data;
      const ahLocalId = uuidv4();
      const ahFilename = `${ahLocalId}.mobileprovision`;
      if (ahProfile.attributes.profileContent) {
        if (!fs.existsSync(PROFILE_DIR)) fs.mkdirSync(PROFILE_DIR, { recursive: true });
        fs.writeFileSync(path.join(PROFILE_DIR, ahFilename), Buffer.from(ahProfile.attributes.profileContent, 'base64'));
      }
      await db.prepare(`INSERT INTO profiles (id, account_id, apple_id, name, type, bundle_id, profile_content, profile_path, expires_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`).run(
        ahLocalId, account_id, ahProfile.id, ahProfileName, 'IOS_APP_ADHOC', bundleAppleId,
        ahProfile.attributes.profileContent || null, ahFilename, ahProfile.attributes.expirationDate || null
      );

      signingCertPath = path.join(CERT_DIR, distCert.p12_path);
      signingPassword = distCert.password || '123456';
      signingProfilePath = path.join(PROFILE_DIR, ahFilename);
    } else {
      signingCertPath = path.join(CERT_DIR, cert.p12_path);
      signingPassword = cert.password || '123456';
      signingProfilePath = path.join(PROFILE_DIR, profile.profile_path);
    }

    if (!fs.existsSync(signingCertPath)) return res.status(404).json({ success: false, message: '签名 P12 文件丢失' });
    if (!fs.existsSync(signingProfilePath)) return res.status(404).json({ success: false, message: '签名描述文件丢失' });

    const signId = uuidv4().slice(0, 12);
    const outputPath = path.join(SIGNED_IPA_DIR, `esign_${signId}.ipa`);

    await new Promise((resolve, reject) => {
      execFile('zsign', [
        '-k', signingCertPath,
        '-p', signingPassword,
        '-m', signingProfilePath,
        '-b', bundleIdentifier,
        '-z', '5',
        '-o', outputPath,
        ESIGN_IPA_PATH
      ], { timeout: 120000 }, (err, stdout, stderr) => {
        if (err) return reject(new Error(stderr || err.message));
        resolve(stdout);
      });
    });

    if (!fs.existsSync(outputPath)) {
      return res.status(500).json({ success: false, message: '签名失败，输出文件不存在' });
    }

    // 从签名后的 IPA 中提取真实版本号和 App 名称
    let bundleVersion = '1.0';
    let bundleShortVersion = '1.0';
    let appTitle = '全能签';
    try {
      const { execSync } = require('child_process');
      const plistJson = execSync(
        `unzip -p "${outputPath}" "Payload/*.app/Info.plist" | python3 -c "import plistlib,sys,json;d=plistlib.loads(sys.stdin.buffer.read());print(json.dumps({'v':d.get('CFBundleVersion','1.0'),'sv':d.get('CFBundleShortVersionString','1.0'),'n':d.get('CFBundleDisplayName',d.get('CFBundleName','App'))}))"`,
        { timeout: 10000 }
      ).toString().trim();
      const info = JSON.parse(plistJson);
      bundleVersion = info.v || '1.0';
      bundleShortVersion = info.sv || '1.0';
      appTitle = info.n || '全能签';
    } catch (_) {}

    // 保存签名元数据（manifest 和 IPA 下载使用）
    const metadataPath = path.join(SIGNED_IPA_DIR, `esign_${signId}.json`);
    fs.writeFileSync(metadataPath, JSON.stringify({
      bundle_identifier: bundleIdentifier,
      bundle_version: bundleVersion,
      bundle_short_version: bundleShortVersion,
      app_title: appTitle,
      sign_id: signId,
      cert_id, profile_id,
      created_at: new Date().toISOString(),
    }));

    const serverUrl = process.env.SERVER_URL || `https://${req.get('host')}`;
    const manifestUrl = `${serverUrl}/api/udid/install-manifest/${signId}`;
    const installUrl = `itms-services://?action=download-manifest&url=${encodeURIComponent(manifestUrl)}`;

    res.json({
      success: true,
      message: '全能签签名完成',
      data: { sign_id: signId, install_url: installUrl }
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message || '签名失败' });
  }
});

// OTA 安装 manifest.plist（无需认证，signId 本身是密钥）
router.get('/install-manifest/:signId', (req, res) => {
  try {
    const { signId } = req.params;
    const ipaPath = path.join(SIGNED_IPA_DIR, `esign_${signId}.ipa`);
    if (!fs.existsSync(ipaPath)) return res.status(404).send('IPA not found');

    // 读取签名元数据
    let bundleIdentifier = 'com.esign.signed';
    let bundleVersion = '1.0';
    let appTitle = '全能签';
    const metadataPath = path.join(SIGNED_IPA_DIR, `esign_${signId}.json`);
    if (fs.existsSync(metadataPath)) {
      try {
        const meta = JSON.parse(fs.readFileSync(metadataPath, 'utf8'));
        if (meta.bundle_identifier) bundleIdentifier = meta.bundle_identifier;
        if (meta.bundle_short_version) bundleVersion = meta.bundle_short_version;
        else if (meta.bundle_version) bundleVersion = meta.bundle_version;
        if (meta.app_title) appTitle = meta.app_title;
      } catch (_) {}
    }

    const serverUrl = process.env.SERVER_URL || `https://${req.get('host')}`;
    const ipaUrl = `${serverUrl}/api/udid/signed-ipa/${signId}`;

    const plist = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>items</key>
  <array>
    <dict>
      <key>assets</key>
      <array>
        <dict>
          <key>kind</key>
          <string>software-package</string>
          <key>url</key>
          <string>${ipaUrl}</string>
        </dict>
      </array>
      <key>metadata</key>
      <dict>
        <key>bundle-identifier</key>
        <string>${bundleIdentifier}</string>
        <key>bundle-version</key>
        <string>${bundleVersion}</string>
        <key>kind</key>
        <string>software</string>
        <key>title</key>
        <string>${appTitle}</string>
      </dict>
    </dict>
  </array>
</dict>
</plist>`;

    res.setHeader('Content-Type', 'application/xml');
    res.send(plist);
  } catch (err) {
    res.status(500).send('Error');
  }
});

// 下载签名后的 IPA（无需认证，signId 本身是密钥）
router.get('/signed-ipa/:signId', (req, res) => {
  try {
    const { signId } = req.params;
    if (!/^[a-f0-9-]{8,36}$/.test(signId)) return res.status(400).send('Invalid sign ID');

    const ipaPath = path.join(SIGNED_IPA_DIR, `esign_${signId}.ipa`);
    if (!fs.existsSync(ipaPath)) return res.status(404).json({ success: false, message: 'IPA 不存在或已过期' });

    res.setHeader('Content-Type', 'application/octet-stream');
    res.setHeader('Content-Disposition', `attachment; filename="ESign_signed.ipa"`);
    fs.createReadStream(ipaPath).pipe(res);
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
