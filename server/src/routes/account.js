const express = require('express');
const router = express.Router();
const path = require('path');
const fs = require('fs');
const multer = require('multer');
const { v4: uuidv4 } = require('uuid');
const { getDb } = require('../config/database');
const AppleApiService = require('../services/apple-api');
const { encrypt, decrypt } = require('../services/encryption');
const CryptoService = require('../services/crypto');
const { isPushOrPassCertType } = require('./certificate');
const { parseTesterName, addTesterToBetaGroupAfterConnect } = require('../services/beta-tester-invite');

function checkOwnership(account, user) {
  if (!account) return false;
  if (user.role === 'superadmin') return true;
  return account.user_id === user.id;
}

const P8_DIR = path.join(__dirname, '../../data/p8keys');
if (!fs.existsSync(P8_DIR)) fs.mkdirSync(P8_DIR, { recursive: true });

const upload = multer({
  storage: multer.diskStorage({
    destination: (req, file, cb) => cb(null, P8_DIR),
    filename: (req, file, cb) => cb(null, `${uuidv4()}${path.extname(file.originalname)}`)
  }),
  fileFilter: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    if (ext === '.p8' || ext === '.pem' || ext === '.key') {
      cb(null, true);
    } else {
      cb(new Error('仅支持 .p8 / .pem / .key 格式的密钥文件'));
    }
  },
  limits: { fileSize: 1024 * 100 }
});

function validateP8Content(content) {
  const trimmed = content.trim();
  if (trimmed.includes('-----BEGIN PRIVATE KEY-----') && trimmed.includes('-----END PRIVATE KEY-----')) {
    return { valid: true, type: 'PKCS8' };
  }
  if (trimmed.includes('-----BEGIN EC PRIVATE KEY-----') && trimmed.includes('-----END EC PRIVATE KEY-----')) {
    return { valid: true, type: 'EC' };
  }
  const base64Only = trimmed.replace(/\s/g, '');
  if (/^[A-Za-z0-9+/=]{40,}$/.test(base64Only)) {
    return { valid: true, type: 'RAW_BASE64' };
  }
  return { valid: false, type: null };
}

router.get('/', async (req, res) => {
  const db = getDb();
  const accounts = req.user.role === 'superadmin'
    ? await db.prepare('SELECT id, name, issuer_id, key_id, created_at FROM accounts ORDER BY created_at DESC').all()
    : await db.prepare('SELECT id, name, issuer_id, key_id, created_at FROM accounts WHERE user_id = ? ORDER BY created_at DESC').all(req.user.id);
  res.json({ success: true, data: accounts });
});

router.get('/:id', async (req, res, next) => {
  try {
    const db = getDb();
    const accountRow = await db.prepare('SELECT id, name, issuer_id, key_id, created_at FROM accounts WHERE id = ?').get(req.params.id);
    if (!accountRow) return res.status(404).json({ success: false, message: '账号不存在' });

    const fullAccount = await db.prepare('SELECT * FROM accounts WHERE id = ?').get(req.params.id);
    if (!checkOwnership(fullAccount, req.user)) return res.status(403).json({ success: false, message: '无权操作此账号' });
    const decryptedAccount = { ...fullAccount, private_key: decrypt(fullAccount.private_key) };

    let remoteSynced = false;
    try {
      const api = new AppleApiService(decryptedAccount);

      const [remoteCerts, remoteDevices, remoteBundles, remoteProfiles] = await Promise.all([
        api.listCertificates().catch(() => ({ data: [] })),
        api.listDevices().catch(() => ({ data: [] })),
        api.listBundleIds().catch(() => ({ data: [] })),
        api.listProfiles().catch(() => ({ data: [] })),
      ]);

      const upsertDevice = db.prepare(`INSERT INTO devices (id, account_id, apple_id, udid, name, platform, status)
        VALUES (?, ?, ?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET name=excluded.name, status=excluded.status`);
      const upsertBundle = db.prepare(`INSERT INTO bundle_ids (id, account_id, apple_id, identifier, name, platform)
        VALUES (?, ?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET identifier=excluded.identifier, name=excluded.name`);
      const upsertCert = db.prepare(`INSERT INTO certificates (id, account_id, apple_id, type, name, cert_content, expires_at)
        VALUES (?, ?, ?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET name=excluded.name, cert_content=COALESCE(excluded.cert_content, certificates.cert_content), expires_at=excluded.expires_at`);
      const upsertProfile = db.prepare(`INSERT INTO profiles (id, account_id, apple_id, name, type, profile_content, profile_path, expires_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET name=excluded.name, profile_content=COALESCE(excluded.profile_content, profiles.profile_content), profile_path=COALESCE(excluded.profile_path, profiles.profile_path), expires_at=excluded.expires_at`);

      const PROFILE_DIR = path.join(__dirname, '../../data/profiles');
      if (!fs.existsSync(PROFILE_DIR)) fs.mkdirSync(PROFILE_DIR, { recursive: true });

      const syncAll = db.transaction(async (txDb) => {
        const txUpsertDevice = txDb.prepare(`INSERT INTO devices (id, account_id, apple_id, udid, name, platform, status)
          VALUES (?, ?, ?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET name=excluded.name, status=excluded.status`);
        const txUpsertBundle = txDb.prepare(`INSERT INTO bundle_ids (id, account_id, apple_id, identifier, name, platform)
          VALUES (?, ?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET identifier=excluded.identifier, name=excluded.name`);
        const txUpsertCert = txDb.prepare(`INSERT INTO certificates (id, account_id, apple_id, type, name, cert_content, expires_at)
          VALUES (?, ?, ?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET name=excluded.name, cert_content=COALESCE(excluded.cert_content, certificates.cert_content), expires_at=excluded.expires_at`);
        const txUpsertProfile = txDb.prepare(`INSERT INTO profiles (id, account_id, apple_id, name, type, profile_content, profile_path, expires_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET name=excluded.name, profile_content=COALESCE(excluded.profile_content, profiles.profile_content), profile_path=COALESCE(excluded.profile_path, profiles.profile_path), expires_at=excluded.expires_at`);

        for (const d of (remoteDevices.data || [])) {
          await txUpsertDevice.run(d.id, req.params.id, d.id, d.attributes.udid, d.attributes.name, d.attributes.platform, d.attributes.status);
        }
        for (const b of (remoteBundles.data || [])) {
          await txUpsertBundle.run(b.id, req.params.id, b.id, b.attributes.identifier, b.attributes.name, b.attributes.platform);
        }
        for (const c of (remoteCerts.data || [])) {
          if (isPushOrPassCertType(c.attributes?.certificateType)) continue;
          await txUpsertCert.run(c.id, req.params.id, c.id, c.attributes.certificateType, c.attributes.name || c.attributes.certificateType, c.attributes.certificateContent || null, c.attributes.expirationDate);
        }
        for (const p of (remoteProfiles.data || [])) {
          let profilePath = null;
          if (p.attributes.profileContent) {
            const filename = `${p.id}.mobileprovision`;
            fs.writeFileSync(path.join(PROFILE_DIR, filename), Buffer.from(p.attributes.profileContent, 'base64'));
            profilePath = filename;
          }
          await txUpsertProfile.run(p.id, req.params.id, p.id, p.attributes.name, p.attributes.profileType, p.attributes.profileContent || null, profilePath, p.attributes.expirationDate);
        }
      });
      await syncAll();

      const CERT_DIR = path.join(__dirname, '../../data/certificates');
      if (!fs.existsSync(CERT_DIR)) fs.mkdirSync(CERT_DIR, { recursive: true });
      const certsNeedP12 = await db.prepare(
        `SELECT * FROM certificates WHERE account_id = ? AND private_key IS NOT NULL AND cert_content IS NOT NULL AND (p12_path IS NULL OR p12_path = '')`
      ).all(req.params.id);
      for (const c of certsNeedP12) {
        try {
          const certPem = c.cert_content.includes('BEGIN CERTIFICATE')
            ? c.cert_content
            : CryptoService.derToPem(c.cert_content);
          const password = c.password || '123456';
          const p12Buffer = CryptoService.createP12(c.private_key, certPem, password, c.name || 'Apple Certificate');
          const p12Filename = `${c.id}.p12`;
          fs.writeFileSync(path.join(CERT_DIR, p12Filename), p12Buffer);
          await db.prepare('UPDATE certificates SET p12_path = ?, password = ? WHERE id = ?').run(p12Filename, password, c.id);
        } catch (e) { /* skip if conversion fails */ }
      }

      remoteSynced = true;
    } catch (e) {
      // API failure doesn't block returning local data
    }

    const allCerts = await db.prepare('SELECT id, name, type, expires_at, is_self_signed, created_at FROM certificates WHERE account_id = ? ORDER BY created_at DESC').all(req.params.id);
    const certs = allCerts.filter(c => !isPushOrPassCertType(c.type));
    const devices = await db.prepare('SELECT id, name, udid, platform, status, created_at FROM devices WHERE account_id = ? ORDER BY created_at DESC').all(req.params.id);
    const bundleIds = await db.prepare('SELECT id, identifier, name, platform, created_at FROM bundle_ids WHERE account_id = ? ORDER BY created_at DESC').all(req.params.id);
    const profiles = await db.prepare('SELECT id, name, type, expires_at, created_at FROM profiles WHERE account_id = ? ORDER BY created_at DESC').all(req.params.id);

    const now = new Date();
    const expiredCerts = certs.filter(c => c.expires_at && new Date(c.expires_at) < now).length;
    const expiredProfiles = profiles.filter(p => p.expires_at && new Date(p.expires_at) < now).length;
    const activeDevices = devices.filter(d => d.status === 'ENABLED').length;

    res.json({
      success: true,
      data: {
        ...accountRow,
        remote_synced: remoteSynced,
        stats: {
          certificates: certs.length,
          expired_certificates: expiredCerts,
          devices: devices.length,
          active_devices: activeDevices,
          bundle_ids: bundleIds.length,
          profiles: profiles.length,
          expired_profiles: expiredProfiles,
        },
        certificates: certs,
        devices,
        bundle_ids: bundleIds,
        profiles,
      }
    });
  } catch (err) {
    next(err);
  }
});

router.post('/', async (req, res) => {
  const { name, issuer_id, key_id, private_key } = req.body;
  if (!name || !issuer_id || !key_id || !private_key) {
    return res.status(400).json({ success: false, message: '请填写所有必填字段' });
  }

  const db = getDb();

  const existing = await db.prepare(
    'SELECT id, name FROM accounts WHERE issuer_id = ? AND key_id = ?'
  ).get(issuer_id, key_id);
  if (existing) {
    return res.status(409).json({
      success: false,
      message: `该账号已存在（${existing.name}），同一 Issuer ID + Key ID 不可重复添加`
    });
  }

  const id = uuidv4();
  await db.prepare('INSERT INTO accounts (id, user_id, name, issuer_id, key_id, private_key) VALUES (?, ?, ?, ?, ?, ?)')
    .run(id, req.user.id, name, issuer_id, key_id, encrypt(private_key));

  res.json({ success: true, data: { id, name, issuer_id, key_id } });
});

router.put('/:id', async (req, res) => {
  const { name, issuer_id, key_id, private_key } = req.body;
  const db = getDb();

  const existing = await db.prepare('SELECT * FROM accounts WHERE id = ?').get(req.params.id);
  if (!existing) return res.status(404).json({ success: false, message: '账号不存在' });
  if (!checkOwnership(existing, req.user)) return res.status(403).json({ success: false, message: '无权操作此账号' });

  await db.prepare('UPDATE accounts SET name = ?, issuer_id = ?, key_id = ?, private_key = ? WHERE id = ?')
    .run(
      name || existing.name,
      issuer_id || existing.issuer_id,
      key_id || existing.key_id,
      private_key ? encrypt(private_key) : existing.private_key,
      req.params.id
    );

  res.json({ success: true, message: '更新成功' });
});

router.delete('/:id', async (req, res) => {
  const db = getDb();
  const existing = await db.prepare('SELECT * FROM accounts WHERE id = ?').get(req.params.id);
  if (!existing) return res.status(404).json({ success: false, message: '账号不存在' });
  if (!checkOwnership(existing, req.user)) return res.status(403).json({ success: false, message: '无权操作此账号' });
  await db.prepare('DELETE FROM accounts WHERE id = ?').run(req.params.id);
  res.json({ success: true, message: '删除成功' });
});

router.get('/:id/download-p8', async (req, res) => {
  const db = getDb();
  const account = await db.prepare('SELECT * FROM accounts WHERE id = ?').get(req.params.id);
  if (!account) return res.status(404).json({ success: false, message: '账号不存在' });
  if (!checkOwnership(account, req.user)) return res.status(403).json({ success: false, message: '无权操作此账号' });

  const filename = `AuthKey_${account.key_id}.p8`;
  res.setHeader('Content-Type', 'application/octet-stream');
  res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
  res.send(decrypt(account.private_key));
});

router.post('/:id/test', async (req, res) => {
  try {
    const db = getDb();
    const account = await db.prepare('SELECT * FROM accounts WHERE id = ?').get(req.params.id);
    if (!account) return res.status(404).json({ success: false, message: '账号不存在' });
    if (!checkOwnership(account, req.user)) return res.status(403).json({ success: false, message: '无权操作此账号' });

    account.private_key = decrypt(account.private_key);
    const keyPreview = account.private_key
      ? `${account.private_key.substring(0, 30)}... (${account.private_key.length} 字符)`
      : '空';

    const api = new AppleApiService(account);
    const result = await api.listCertificates({ 'limit': 1 });
    const certCount = result.data?.length || 0;

    const email = (req.body?.email || '').trim();
    const groupId = (req.body?.group_id || req.body?.beta_group_id || '').trim();
    let testflightInvite = null;

    if (email || groupId) {
      if (!email || !groupId) {
        return res.status(400).json({
          success: false,
          message: '同时填写邮箱与测试组 ID 时才会在连接成功后自动加入测试组；请补全或留空两项',
        });
      }
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
        return res.status(400).json({ success: false, message: '邮箱格式不正确' });
      }
      const { firstName, lastName } = parseTesterName(req.body);
      testflightInvite = await addTesterToBetaGroupAfterConnect(api, {
        email,
        groupId,
        firstName,
        lastName,
      });
    }

    res.json({
      success: true,
      message: 'API 连接成功',
      data: {
        issuer_id: account.issuer_id,
        key_id: account.key_id,
        key_preview: keyPreview,
        certificates_found: certCount,
        testflight_invite: testflightInvite,
      }
    });
  } catch (err) {
    res.status(err.status || 500).json({
      success: false,
      message: err.message || '连接失败',
      data: {
        issuer_id: req.body?.issuer_id || '(从数据库读取)',
        tips: [
          '确认 Issuer ID 正确（App Store Connect → 用户和访问 → 集成 → 页面顶部）',
          '确认 Key ID 正确（API Key 列表中显示）',
          '确认 .p8 文件内容完整（以 -----BEGIN PRIVATE KEY----- 开头）',
          '确认 API Key 未被撤销',
          '确认 API Key 拥有 Admin 或 Developer 权限',
        ]
      }
    });
  }
});

router.post('/upload-p8', upload.single('file'), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ success: false, message: '请上传 .p8 密钥文件' });
  }

  const filePath = req.file.path;
  const content = fs.readFileSync(filePath, 'utf-8');
  const validation = validateP8Content(content);

  if (!validation.valid) {
    fs.unlinkSync(filePath);
    return res.status(400).json({ success: false, message: '无效的私钥文件，请确认文件内容是否正确' });
  }

  let normalizedContent = content.trim();
  if (validation.type === 'RAW_BASE64') {
    normalizedContent = `-----BEGIN PRIVATE KEY-----\n${normalizedContent}\n-----END PRIVATE KEY-----`;
  }

  const keyIdMatch = req.file.originalname.match(/AuthKey[_-]?(\w{8,12})\.p8/i)
    || req.file.originalname.match(/^(\w{8,12})\.p8$/i);
  const guessedKeyId = keyIdMatch ? keyIdMatch[1] : '';

  res.json({
    success: true,
    data: {
      filename: req.file.originalname,
      key_type: validation.type,
      content: normalizedContent,
      stored_path: req.file.filename,
      guessed_key_id: guessedKeyId,
    }
  });
});

router.post('/validate-p8', (req, res) => {
  const { content } = req.body;
  if (!content) {
    return res.status(400).json({ success: false, message: '缺少内容' });
  }
  const validation = validateP8Content(content);
  res.json({ success: true, data: validation });
});

router.post('/import-p8', upload.single('file'), async (req, res) => {
  const { name, issuer_id, key_id } = req.body;

  let privateKeyContent;

  if (req.file) {
    privateKeyContent = fs.readFileSync(req.file.path, 'utf-8').trim();
  } else if (req.body.private_key) {
    privateKeyContent = req.body.private_key.trim();
  }

  if (!name || !issuer_id || !key_id || !privateKeyContent) {
    if (req.file) fs.unlinkSync(req.file.path);
    return res.status(400).json({ success: false, message: '请填写所有必填字段并提供 .p8 密钥' });
  }

  const validation = validateP8Content(privateKeyContent);
  if (!validation.valid) {
    if (req.file) fs.unlinkSync(req.file.path);
    return res.status(400).json({ success: false, message: '无效的私钥内容' });
  }

  if (validation.type === 'RAW_BASE64') {
    privateKeyContent = `-----BEGIN PRIVATE KEY-----\n${privateKeyContent}\n-----END PRIVATE KEY-----`;
  }

  const db = getDb();

  const existing = await db.prepare(
    'SELECT id, name FROM accounts WHERE issuer_id = ? AND key_id = ?'
  ).get(issuer_id, key_id);
  if (existing) {
    if (req.file) fs.unlinkSync(req.file.path);
    return res.status(409).json({
      success: false,
      message: `该账号已存在（${existing.name}），同一 Issuer ID + Key ID 不可重复添加`
    });
  }

  const id = uuidv4();
  await db.prepare('INSERT INTO accounts (id, user_id, name, issuer_id, key_id, private_key) VALUES (?, ?, ?, ?, ?, ?)')
    .run(id, req.user.id, name, issuer_id, key_id, encrypt(privateKeyContent));

  res.json({
    success: true,
    data: { id, name, issuer_id, key_id },
    message: '账号导入成功'
  });
});

module.exports = router;
