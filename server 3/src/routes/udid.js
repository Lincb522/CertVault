const express = require('express');
const crypto = require('crypto');
const router = express.Router();
const { signMobileConfig, canSign } = require('../services/mobileconfig-signer');

const pendingUDIDs = new Map();

const APP_NAME = process.env.APP_NAME || 'CertVault';

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

  pendingUDIDs.set(requestId, { status: 'pending', created: Date.now() });

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

      const deviceInfo = {
        status: 'success',
        udid: udidMatch?.[1] || '',
        product: productMatch?.[1] || '',
        version: versionMatch?.[1] || '',
        serial: serialMatch?.[1] || '',
        device_name: nameMatch?.[1] || '',
        imei: imeiMatch?.[1] || '',
        time: new Date().toISOString(),
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

// 生成请求 ID
router.post('/create-request', (req, res) => {
  const requestId = crypto.randomBytes(8).toString('hex');
  pendingUDIDs.set(requestId, { status: 'pending', created: Date.now() });
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

module.exports = router;
