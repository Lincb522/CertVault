const express = require('express');
const router = express.Router();
const path = require('path');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');
const { getDb } = require('../config/database');
const AppleApiService = require('../services/apple-api');
const CryptoService = require('../services/crypto');
const { getDecryptedAccount } = require('../services/account-helper');
const { sendPushToUser } = require('../services/push-helper');
const CERT_DIR = path.join(__dirname, '../../data/certificates');
if (!fs.existsSync(CERT_DIR)) fs.mkdirSync(CERT_DIR, { recursive: true });

const CERT_TYPES = [
  { value: 'IOS_DEVELOPMENT',            label: 'iOS 开发证书',             desc: '用于真机调试，安装到测试设备上运行 App', category: 'dev' },
  { value: 'IOS_DISTRIBUTION',           label: 'iOS 发布证书',             desc: '用于提交 App Store 或 Ad Hoc/In-House 分发', category: 'dist' },
  { value: 'MAC_APP_DEVELOPMENT',        label: 'macOS 开发证书',           desc: '用于 macOS App 真机调试开发', category: 'dev' },
  { value: 'MAC_APP_DISTRIBUTION',       label: 'macOS 发布证书',           desc: '用于提交 Mac App Store 发布', category: 'dist' },
  { value: 'MAC_INSTALLER_DISTRIBUTION', label: 'macOS 安装包发布证书',     desc: '用于签名 macOS .pkg 安装包', category: 'dist' },
  { value: 'DEVELOPER_ID_KEXT',          label: 'Developer ID (内核扩展)',  desc: '用于签名 macOS 内核扩展 (Kext)', category: 'dist' },
  { value: 'DEVELOPER_ID_APPLICATION',   label: 'Developer ID (应用)',      desc: '用于在 Mac App Store 外分发的 macOS 应用签名', category: 'dist' },
  { value: 'DEVELOPER_ID_INSTALLER',     label: 'Developer ID (安装器)',    desc: '用于签名在 Mac App Store 外分发的 .pkg 安装包', category: 'dist' },
];

const PUSH_GUIDE = {
  methods: [
    {
      id: 'p8_key',
      name: 'APNs Key (.p8) — 推荐方式',
      desc: '使用 App Store Connect API Key 发送推送，一个 Key 可同时用于所有 App',
      pros: ['无需为每个 App 单独配置', '不会过期（无需定期续签）', '同时支持开发和生产环境', '配置最简单'],
      cons: ['无法撤销单个 App 的推送权限'],
      steps: [
        '登录 Apple Developer → Certificates, Identifiers & Profiles → Keys',
        '点击 + 创建新 Key，勾选 "Apple Push Notifications service (APNs)"',
        '下载生成的 .p8 文件（仅能下载一次）',
        '记录 Key ID 和 Team ID',
        '将 .p8 文件配置到你的推送服务端（如 Firebase、OneSignal、自建服务等）',
      ],
      server_config: {
        key_id: 'Key ID（创建 Key 时显示）',
        team_id: 'Team ID（Apple Developer 账号页右上角）',
        bundle_id: 'App 的 Bundle Identifier',
        p8_file: '.p8 私钥文件路径',
        environment: 'development（沙盒）或 production（生产）'
      }
    },
    {
      id: 'p12_cert',
      name: 'APNs 证书 (.p12) — 传统方式',
      desc: '为每个 App 单独创建推送证书，导出为 .p12 文件配置到服务端',
      pros: ['可精确控制每个 App 的推送权限', '兼容旧版推送服务'],
      cons: ['每个证书有效期仅 1 年，需定期续签', '每个 App 需单独配置开发和生产证书', '最多同时保留 2 个有效证书'],
      steps: [
        '确保 Bundle ID 已开启 Push Notifications 权限',
        '在本工具「证书管理」中创建 APNs 证书（选择开发或生产类型）',
        '系统自动生成 CSR → 向 Apple 申请 → 打包为 P12',
        '下载 .p12 文件并配置到推送服务端',
        '设置 P12 密码和推送环境（沙盒/生产）',
      ],
      cert_types: {
        'APPLE_PUSH_SERVICES': '推送证书 (通用 - 同时支持开发和生产)',
        'DEVELOPMENT': '推送开发证书 (仅沙盒环境)',
        'PRODUCTION': '推送生产证书 (仅生产环境)',
      }
    }
  ],
  common_services: [
    { name: 'Firebase Cloud Messaging (FCM)', config: '支持 .p8 Key 和 .p12 证书，推荐使用 .p8', url: 'https://firebase.google.com/docs/cloud-messaging/ios/certs' },
    { name: 'JPush (极光推送)', config: '支持 .p12 证书，在「推送设置」中上传', url: 'https://docs.jiguang.cn/jpush' },
    { name: 'OneSignal', config: '支持 .p8 Key（推荐）和 .p12 证书', url: 'https://documentation.onesignal.com/docs/ios-push-notifications' },
    { name: 'Umeng (友盟)', config: '支持 .p12 证书，需分别上传开发和生产证书', url: 'https://developer.umeng.com/docs/67966/detail/66748' },
    { name: 'AWS SNS', config: '支持 .p12 证书，在 Platform Application 中配置', url: 'https://docs.aws.amazon.com/sns/latest/dg/sns-apns.html' },
    { name: '自建 APNs 服务', config: '使用 HTTP/2 连接 api.push.apple.com，推荐 .p8 Bearer Token 认证', url: 'https://developer.apple.com/documentation/usernotifications' },
  ],
  troubleshooting: [
    { issue: '推送证书创建失败', solution: '确认 Bundle ID 已在 Apple Developer 中开启 Push Notifications 权限' },
    { issue: '开发环境能收到推送，生产环境收不到', solution: '检查是否使用了正确的证书类型（生产 vs 开发），以及 APNs 环境是否匹配' },
    { issue: '证书有效但推送失败', solution: '检查设备 Token 是否有效、推送 Payload 格式是否正确、Bundle ID 是否匹配' },
    { issue: 'Invalid provider token', solution: '检查 .p8 Key ID、Team ID 是否正确，JWT Token 是否过期（最长 1 小时）' },
    { issue: '证书过期', solution: 'APNs 证书有效期 1 年，请及时续签；使用 .p8 Key 可避免过期问题' },
    { issue: 'BadDeviceToken', solution: '确认 Token 是从正确环境获取的（沙盒 Token 不能用于生产环境）' },
  ]
};

router.get('/types', (req, res) => {
  res.json({ success: true, data: CERT_TYPES });
});

router.get('/quota', async (req, res, next) => {
  try {
    const { account_id } = req.query;
    if (!account_id) return res.status(400).json({ success: false, message: '缺少 account_id' });

    const account = await getDecryptedAccount(account_id);
    const api = new AppleApiService(account);
    const result = await api.listCertificates();
    const certs = result.data || [];

    const limits = {
      IOS_DEVELOPMENT: 2, IOS_DISTRIBUTION: 3,
      MAC_APP_DEVELOPMENT: 2, MAC_APP_DISTRIBUTION: 3,
      DEVELOPER_ID_APPLICATION: 5, DEVELOPER_ID_INSTALLER: 5,
    };

    const quota = {};
    for (const [type, limit] of Object.entries(limits)) {
      const count = certs.filter(c => c.attributes.certificateType === type).length;
      const typeInfo = CERT_TYPES.find(t => t.value === type);
      quota[type] = { label: typeInfo?.label || type, used: count, limit, available: limit - count };
    }

    res.json({ success: true, data: quota, total_certs: certs.length });
  } catch (err) {
    next(err);
  }
});

router.get('/push-guide', (req, res) => {
  res.json({ success: true, data: PUSH_GUIDE });
});

router.get('/relations', async (req, res, next) => {
  try {
    const { account_id } = req.query;
    if (!account_id) return res.status(400).json({ success: false, message: '缺少 account_id' });

    const account = await getDecryptedAccount(account_id);
    const api = new AppleApiService(account);
    const result = await api.listProfilesWithRelations();

    const included = result.included || [];
    const certsMap = {};
    const devicesMap = {};
    const bundlesMap = {};

    for (const item of included) {
      if (item.type === 'certificates') {
        certsMap[item.id] = { id: item.id, name: item.attributes.name, type: item.attributes.certificateType, expires: item.attributes.expirationDate };
      } else if (item.type === 'devices') {
        devicesMap[item.id] = { id: item.id, name: item.attributes.name, udid: item.attributes.udid, platform: item.attributes.platform, status: item.attributes.status };
      } else if (item.type === 'bundleIds') {
        bundlesMap[item.id] = { id: item.id, name: item.attributes.name, identifier: item.attributes.identifier };
      }
    }

    const profiles = (result.data || []).map(p => {
      const certRels = p.relationships?.certificates?.data || [];
      const deviceRels = p.relationships?.devices?.data || [];
      const bundleRel = p.relationships?.bundleId?.data;

      return {
        id: p.id,
        name: p.attributes.name,
        type: p.attributes.profileType,
        state: p.attributes.profileState,
        expires: p.attributes.expirationDate,
        bundle: bundleRel ? bundlesMap[bundleRel.id] || { id: bundleRel.id } : null,
        certificates: certRels.map(c => certsMap[c.id] || { id: c.id }),
        devices: deviceRels.map(d => devicesMap[d.id] || { id: d.id }),
        device_count: deviceRels.length,
      };
    });

    res.json({ success: true, data: profiles });
  } catch (err) {
    next(err);
  }
});

router.get('/', async (req, res, next) => {
  try {
    const { account_id } = req.query;
    const db = getDb();

    if (account_id) {
      const account = await getDecryptedAccount(account_id);

      const api = new AppleApiService(account);
      let remoteCerts = [];
      let apiFetchOk = false;
      try {
        const result = await api.listCertificates();
        remoteCerts = result.data || [];
        apiFetchOk = true;
        console.log(`[Cert Sync] Apple API returned ${remoteCerts.length} certificates for account ${account_id}`);
      } catch (e) {
        console.log(`[Cert Sync] Apple API failed for account ${account_id}: ${e.message}`);
      }

      if (apiFetchOk) {
        const remoteAppleIds = new Set(remoteCerts.map(c => c.id));
        const localCertsRows = await db.prepare('SELECT id, apple_id, p12_path FROM certificates WHERE account_id = ?').all(account_id);
        const localIds = new Set(localCertsRows.map(c => c.id));
        const localAppleIds = new Set(localCertsRows.filter(c => c.apple_id).map(c => c.apple_id));

        const syncRemote = db.transaction(async (txDb) => {
          const txUpsert = txDb.prepare(`INSERT INTO certificates (id, user_id, account_id, apple_id, type, name, cert_content, expires_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET
            name=excluded.name, cert_content=COALESCE(excluded.cert_content, certificates.cert_content), expires_at=excluded.expires_at`);
          for (const c of remoteCerts) {
            if (localAppleIds.has(c.id)) {
              await txDb.prepare(
                'UPDATE certificates SET name = ?, cert_content = COALESCE(?, cert_content), expires_at = ? WHERE apple_id = ? AND account_id = ?'
              ).run(c.attributes.name || c.attributes.certificateType, c.attributes.certificateContent || null,
                c.attributes.expirationDate, c.id, account_id);
            } else if (!localIds.has(c.id)) {
              await txUpsert.run(c.id, req.user.id, account_id, c.id, c.attributes.certificateType,
                c.attributes.name || c.attributes.certificateType,
                c.attributes.certificateContent || null, c.attributes.expirationDate);
            }
          }
        });
        await syncRemote();

        // Apple 端已不存在的证书，清理本地记录（保留有 P12 文件的）
        const staleCerts = localCertsRows.filter(c => c.apple_id && !c.p12_path && !remoteAppleIds.has(c.apple_id));
        for (const stale of staleCerts) {
          await db.prepare('DELETE FROM certificates WHERE id = ?').run(stale.id);
        }
        if (staleCerts.length > 0) {
          console.log(`[Cert Sync] Cleaned ${staleCerts.length} stale certificates not found in Apple`);
        }
      }

      const allCerts = await db.prepare('SELECT * FROM certificates WHERE account_id = ? ORDER BY created_at DESC').all(account_id);
      const seen = new Map();
      const dedupedCerts = [];
      for (const c of allCerts) {
        const key = c.apple_id || c.id;
        if (seen.has(key)) {
          const prev = seen.get(key);
          if (!prev.p12_path && c.p12_path) {
            dedupedCerts[dedupedCerts.indexOf(prev)] = c;
            seen.set(key, c);
          }
          continue;
        }
        seen.set(key, c);
        dedupedCerts.push(c);
      }
      console.log(`[Cert Sync] Returning ${dedupedCerts.length} certificates (${allCerts.length} before dedup)`);
      res.json({
        success: true,
        data: dedupedCerts,
      });
    } else {
      let rawCerts;
      if (req.user.role === 'superadmin') {
        rawCerts = await db.prepare('SELECT * FROM certificates ORDER BY created_at DESC').all();
      } else {
        rawCerts = await db.prepare('SELECT * FROM certificates WHERE user_id = ? ORDER BY created_at DESC').all(req.user.id);
      }
      const seen2 = new Map();
      const certs = [];
      for (const c of rawCerts) {
        const key = c.apple_id || c.id;
        if (seen2.has(key)) {
          const prev = seen2.get(key);
          if (!prev.p12_path && c.p12_path) {
            certs[certs.indexOf(prev)] = c;
            seen2.set(key, c);
          }
          continue;
        }
        seen2.set(key, c);
        certs.push(c);
      }
      res.json({ success: true, data: certs });
    }
  } catch (err) {
    next(err);
  }
});

router.post('/create', async (req, res, next) => {
  try {
    const { account_id, type = 'IOS_DEVELOPMENT', name, password = '123456', revoke_and_recreate } = req.body;
    if (!account_id) return res.status(400).json({ success: false, message: '缺少 account_id' });

    const account = await getDecryptedAccount(account_id);
    const db = getDb();
    const api = new AppleApiService(account);

    const { privateKeyPem } = CryptoService.generateKeyPair();
    const csrPem = CryptoService.createCSR(privateKeyPem);

    let certData;
    try {
      const result = await api.createCertificate(csrPem, type);
      certData = result.data;
    } catch (createErr) {
      const msg = createErr.message || '';
      const isQuotaFull = msg.includes('already have') || msg.includes('pending certificate') || msg.includes('maximum number');

      if (!isQuotaFull) throw createErr;

      if (revoke_and_recreate) {
        const listResult = await api.listCertificates({ 'filter[certificateType]': type });
        const existing = (listResult.data || []);
        if (existing.length === 0) throw createErr;
        const oldest = existing[existing.length - 1];
        await api.revokeCertificate(oldest.id);
        await db.prepare('DELETE FROM certificates WHERE apple_id = ?').run(oldest.id);

        const retryResult = await api.createCertificate(csrPem, type);
        certData = retryResult.data;
      } else {
        const listResult = await api.listCertificates({ 'filter[certificateType]': type });
        const existing = (listResult.data || []);
        const typeLabel = CERT_TYPES.find(t => t.value === type)?.label || type;
        return res.status(409).json({
          success: false,
          message: `${typeLabel} 数量已达上限（当前 ${existing.length} 个）。你可以选择「撤销旧证书并重新创建」，或在证书列表中手动撤销不需要的证书后重试。`,
          existing_count: existing.length,
          existing_certs: existing.map(c => ({
            id: c.id,
            name: c.attributes.name,
            type: c.attributes.certificateType,
            expires: c.attributes.expirationDate,
          })),
          can_revoke_recreate: true,
        });
      }
    }

    const certPem = CryptoService.derToPem(certData.attributes.certificateContent);
    const certId = uuidv4();
    const p12Buffer = CryptoService.createP12(privateKeyPem, certPem, password, name || type);
    const p12Filename = `${certId}.p12`;
    fs.writeFileSync(path.join(CERT_DIR, p12Filename), p12Buffer);

    const certInfo = CryptoService.parseCertInfo(certPem);

    await db.prepare(`INSERT INTO certificates (id, user_id, account_id, apple_id, type, name, csr_content, private_key, cert_content, p12_path, password, expires_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`).run(
      certId, req.user.id, account_id, certData.id, type,
      name || certInfo.subject.CN || type,
      csrPem, privateKeyPem, certPem, p12Filename, password,
      certInfo.notAfter
    );

    res.json({
      success: true,
      message: '证书创建成功，P12 已生成',
      data: {
        id: certId,
        apple_id: certData.id,
        type,
        name: name || certInfo.subject.CN || type,
        expires_at: certInfo.notAfter,
        p12_path: p12Filename,
      }
    });

    sendPushToUser(req.user.id, '证书创建完成', `${name || certInfo.subject.CN || type} 已创建`, { type: 'task_complete' });
  } catch (err) {
    next(err);
  }
});

router.post('/self-sign', async (req, res, next) => {
  try {
    const { name, password = '123456', ca_cert, ca_private_key, subject = {} } = req.body;

    let certResult;
    let caInfo = null;

    if (ca_cert && ca_private_key) {
      certResult = CryptoService.issueCertificate(ca_private_key, ca_cert, subject);
      caInfo = CryptoService.parseCertInfo(ca_cert);
    } else {
      const ca = CryptoService.generateCA(subject);
      certResult = CryptoService.issueCertificate(ca.privateKey, ca.cert, subject);
      caInfo = CryptoService.parseCertInfo(ca.cert);
      certResult.caCert = ca.cert;
      certResult.caPrivateKey = ca.privateKey;
    }

    const p12Buffer = CryptoService.createP12(certResult.privateKey, certResult.cert, password, name || 'Self-Signed');
    const certId = uuidv4();
    const p12Filename = `${certId}.p12`;
    const p12Path = path.join(CERT_DIR, p12Filename);
    fs.writeFileSync(p12Path, p12Buffer);

    const certInfo = CryptoService.parseCertInfo(certResult.cert);

    const db = getDb();
    await db.prepare(`INSERT INTO certificates (id, user_id, type, name, private_key, cert_content, p12_path, password, is_self_signed, expires_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?)`).run(
      certId, req.user.id, 'SELF_SIGNED',
      name || 'Self-Signed Certificate',
      certResult.privateKey, certResult.cert, p12Filename, password,
      certInfo.notAfter
    );

    res.json({
      success: true,
      data: {
        id: certId,
        type: 'SELF_SIGNED',
        name: name || 'Self-Signed Certificate',
        expires_at: certInfo.notAfter,
        p12_path: p12Filename,
        cert_info: certInfo,
        ca_info: caInfo,
        ca_cert: certResult.caCert || undefined,
        ca_private_key: certResult.caPrivateKey || undefined
      }
    });
  } catch (err) {
    next(err);
  }
});

router.post('/generate-ca', (req, res, next) => {
  try {
    const { commonName, organization, country, years } = req.body;
    const ca = CryptoService.generateCA({ commonName, organization, country, years });
    const info = CryptoService.parseCertInfo(ca.cert);
    res.json({ success: true, data: { ...ca, info } });
  } catch (err) {
    next(err);
  }
});

router.get('/:id/detail', async (req, res) => {
  const db = getDb();
  const cert = await db.prepare('SELECT * FROM certificates WHERE id = ?').get(req.params.id);
  if (!cert) return res.status(404).json({ success: false, message: '证书不存在' });
  if (cert.user_id && cert.user_id !== req.user.id && req.user.role !== 'superadmin') {
    return res.status(403).json({ success: false, message: '无权操作此证书' });
  }

  let certInfo = null;
  if (cert.cert_content) {
    try {
      certInfo = CryptoService.parseCertInfo(
        cert.cert_content.includes('BEGIN CERTIFICATE')
          ? cert.cert_content
          : CryptoService.derToPem(cert.cert_content)
      );
    } catch {}
  }

  const account = cert.account_id
    ? await db.prepare('SELECT id, name, key_id FROM accounts WHERE id = ?').get(cert.account_id)
    : null;

  res.json({
    success: true,
    data: {
      id: cert.id,
      apple_id: cert.apple_id,
      name: cert.name,
      type: cert.type,
      is_self_signed: !!cert.is_self_signed,
      has_p12: !!cert.p12_path,
      has_private_key: !!cert.private_key,
      has_cert_content: !!cert.cert_content,
      password: cert.password || null,
      expires_at: cert.expires_at,
      created_at: cert.created_at,
      cert_info: certInfo,
      account: account ? { id: account.id, name: account.name, key_id: account.key_id } : null,
    }
  });
});

router.get('/:id/download-cer', async (req, res) => {
  const db = getDb();
  const cert = await db.prepare('SELECT * FROM certificates WHERE id = ?').get(req.params.id);
  if (!cert) return res.status(404).json({ success: false, message: '证书不存在' });
  if (cert.user_id && cert.user_id !== req.user.id && req.user.role !== 'superadmin') {
    return res.status(403).json({ success: false, message: '无权操作此证书' });
  }

  if (!cert.cert_content) {
    return res.status(400).json({ success: false, message: '该证书没有证书内容可下载' });
  }

  let derBuffer;
  if (cert.cert_content.includes('BEGIN CERTIFICATE')) {
    const forge = require('node-forge');
    const certObj = forge.pki.certificateFromPem(cert.cert_content);
    const asn1 = forge.pki.certificateToAsn1(certObj);
    const derBytes = forge.asn1.toDer(asn1).getBytes();
    derBuffer = Buffer.from(derBytes, 'binary');
  } else {
    derBuffer = Buffer.from(cert.cert_content, 'base64');
  }

  const filename = `${cert.name || 'certificate'}.cer`;
  res.setHeader('Content-Type', 'application/x-x509-ca-cert');
  res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
  res.send(derBuffer);
});

router.get('/:id/download', async (req, res, next) => {
  try {
    const db = getDb();
    let cert = await db.prepare('SELECT * FROM certificates WHERE id = ?').get(req.params.id);
    if (!cert) return res.status(404).json({ success: false, message: '证书不存在' });
    if (cert.user_id && cert.user_id !== req.user.id && req.user.role !== 'superadmin') {
      return res.status(403).json({ success: false, message: '无权操作此证书' });
    }

    if (cert.p12_path) {
      const p12Path = path.join(CERT_DIR, cert.p12_path);
      if (fs.existsSync(p12Path)) {
        return res.download(p12Path, `${cert.name || 'certificate'}.p12`);
      }
    }

    let privateKey = cert.private_key;
    let certContent = cert.cert_content;

    if (!privateKey && cert.apple_id) {
      const localCert = await db.prepare(
        'SELECT private_key, cert_content FROM certificates WHERE apple_id = ? AND private_key IS NOT NULL'
      ).get(cert.apple_id);
      if (localCert) {
        privateKey = localCert.private_key;
        if (!certContent) certContent = localCert.cert_content;
      }
    }

    if (privateKey && certContent) {
      const certPem = certContent.includes('BEGIN CERTIFICATE')
        ? certContent
        : CryptoService.derToPem(certContent);
      const password = cert.password || '123456';
      const p12Buffer = CryptoService.createP12(privateKey, certPem, password, cert.name || 'Apple Certificate');

      const p12Filename = `${cert.id}.p12`;
      fs.writeFileSync(path.join(CERT_DIR, p12Filename), p12Buffer);
      await db.prepare('UPDATE certificates SET p12_path = ?, password = ? WHERE id = ?')
        .run(p12Filename, password, cert.id);

      return res.download(path.join(CERT_DIR, p12Filename), `${cert.name || 'certificate'}.p12`);
    }

    if (certContent) {
      const forge = require('node-forge');
      let derBuffer;
      if (certContent.includes('BEGIN CERTIFICATE')) {
        const certObj = forge.pki.certificateFromPem(certContent);
        const asn1 = forge.pki.certificateToAsn1(certObj);
        derBuffer = Buffer.from(forge.asn1.toDer(asn1).getBytes(), 'binary');
      } else {
        derBuffer = Buffer.from(certContent, 'base64');
      }
      const filename = `${cert.name || 'certificate'}.cer`;
      res.setHeader('Content-Type', 'application/x-x509-ca-cert');
      res.setHeader('Content-Disposition', `attachment; filename="${encodeURIComponent(filename)}"`);
      return res.send(derBuffer);
    }

    return res.status(400).json({
      success: false,
      message: '该证书没有可下载的内容'
    });
  } catch (err) {
    next(err);
  }
});

router.delete('/:id', async (req, res, next) => {
  try {
    const db = getDb();
    const cert = await db.prepare('SELECT * FROM certificates WHERE id = ?').get(req.params.id);
    if (!cert) return res.status(404).json({ success: false, message: '证书不存在' });
    if (cert.user_id && cert.user_id !== req.user.id && req.user.role !== 'superadmin') {
      return res.status(403).json({ success: false, message: '无权操作此证书' });
    }

    if (cert.apple_id && cert.account_id) {
      try {
        const account = await getDecryptedAccount(cert.account_id);
        const api = new AppleApiService(account);
        await api.revokeCertificate(cert.apple_id);
      } catch (e) {
        // may fail if already revoked
      }
      await db.prepare(
        'INSERT INTO deleted_apple_certs (apple_id, account_id) VALUES (?, ?) ON CONFLICT DO NOTHING'
      ).run(cert.apple_id, cert.account_id);
    }

    if (cert.p12_path) {
      const p12Path = path.join(CERT_DIR, cert.p12_path);
      if (fs.existsSync(p12Path)) fs.unlinkSync(p12Path);
    }

    await db.prepare('DELETE FROM certificates WHERE id = ?').run(req.params.id);
    res.json({ success: true, message: '证书已删除' });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
