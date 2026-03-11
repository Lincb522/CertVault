const express = require('express');
const router = express.Router();
const multer = require('multer');
const forge = require('node-forge');
const fs = require('fs');
const path = require('path');
const os = require('os');
const AdmZip = require('adm-zip');
const { parseProvisioningProfile } = require('../services/profile-parser');
const AppleApiService = require('../services/apple-api');
const { getDecryptedAccount } = require('../services/account-helper');

const upload = multer({
  dest: path.join(os.tmpdir(), 'cert-check'),
  limits: { fileSize: 50 * 1024 * 1024 },
});

function parseP12Buffer(buffer, password = '') {
  const passwords = [password, '', '123456', 'changeit', '1234', 'password'];
  let lastErr = null;

  for (const pwd of passwords) {
    try {
      const p12Der = forge.util.createBuffer(buffer.toString('binary'));
      const p12Asn1 = forge.asn1.fromDer(p12Der);
      const p12 = forge.pkcs12.pkcs12FromAsn1(p12Asn1, false, pwd);

      const certBags = p12.getBags({ bagType: forge.pki.oids.certBag });
      const keyBags = p12.getBags({ bagType: forge.pki.oids.pkcs8ShroudedKeyBag });
      const certs = (certBags[forge.pki.oids.certBag] || []).map(b => b.cert).filter(Boolean);
      const hasPrivateKey = (keyBags[forge.pki.oids.pkcs8ShroudedKeyBag] || []).length > 0;

      if (!certs.length) continue;

      const leaf = certs[0];
      const now = new Date();
      const notBefore = leaf.validity.notBefore;
      const notAfter = leaf.validity.notAfter;
      const isExpired = now > notAfter;
      const isNotYetValid = now < notBefore;
      const daysLeft = Math.ceil((notAfter - now) / (1000 * 60 * 60 * 24));

      const subject = {};
      leaf.subject.attributes.forEach(a => { subject[a.shortName || a.name] = a.value; });
      const issuer = {};
      leaf.issuer.attributes.forEach(a => { issuer[a.shortName || a.name] = a.value; });

      let certType = 'Unknown';
      const cn = subject.CN || '';
      if (cn.includes('Apple Development')) certType = 'iOS Development';
      else if (cn.includes('Apple Distribution') || cn.includes('iPhone Distribution')) certType = 'iOS Distribution';
      else if (cn.includes('Developer ID Application')) certType = 'Developer ID Application';
      else if (cn.includes('Developer ID Installer')) certType = 'Developer ID Installer';
      else if (cn.includes('Apple Push Services') || cn.includes('Push')) certType = 'Push Certificate';
      else if (cn.includes('Mac')) certType = 'macOS Certificate';
      else if (cn.includes('3rd Party Mac')) certType = '3rd Party Mac Developer';

      const serialNumber = leaf.serialNumber;

      const extensions = {};
      (leaf.extensions || []).forEach(ext => {
        if (ext.name === 'basicConstraints') extensions.isCA = ext.cA;
        if (ext.name === 'keyUsage') extensions.keyUsage = ext;
        if (ext.name === 'extKeyUsage') extensions.extKeyUsage = ext;
      });

      return {
        valid: true,
        password_used: pwd,
        has_private_key: hasPrivateKey,
        cert_count: certs.length,
        type: certType,
        subject,
        issuer,
        serial_number: serialNumber,
        not_before: notBefore.toISOString(),
        not_after: notAfter.toISOString(),
        is_expired: isExpired,
        is_not_yet_valid: isNotYetValid,
        days_left: isExpired ? 0 : daysLeft,
        is_ca: extensions.isCA || false,
        status: isExpired ? 'expired' : isNotYetValid ? 'not_yet_valid' : 'valid',
        status_text: isExpired ? '已过期' : isNotYetValid ? '尚未生效' : `有效 (剩余 ${daysLeft} 天)`,
      };
    } catch (err) {
      lastErr = err;
      continue;
    }
  }

  return {
    valid: false,
    error: '无法解析 P12 文件，请检查密码是否正确',
    detail: lastErr?.message || '',
  };
}

function parseProfileBuffer(buffer) {
  const str = buffer.toString('latin1');
  const xmlStart = str.indexOf('<?xml');
  const xmlEnd = str.indexOf('</plist>');
  if (xmlStart === -1 || xmlEnd === -1) {
    return { valid: false, error: '无法解析描述文件' };
  }

  const plistXml = str.substring(xmlStart, xmlEnd + '</plist>'.length);

  function extractStr(xml, key) {
    const regex = new RegExp(`<key>${key}</key>\\s*(?:<string>([^<]*)</string>|<date>([^<]*)</date>)`);
    const m = xml.match(regex);
    return m ? (m[1] || m[2] || null) : null;
  }

  function extractArr(xml, key) {
    const regex = new RegExp(`<key>${key}</key>\\s*<array>([\\s\\S]*?)</array>`);
    const m = xml.match(regex);
    if (!m) return [];
    const items = [];
    const itemRegex = /<string>([^<]*)<\/string>/g;
    let match;
    while ((match = itemRegex.exec(m[1])) !== null) items.push(match[1]);
    return items;
  }

  function extractBool(xml, key) {
    const regex = new RegExp(`<key>${key}</key>\\s*(<true/>|<false/>)`);
    const m = xml.match(regex);
    return m ? m[1] === '<true/>' : null;
  }

  const name = extractStr(plistXml, 'Name');
  const teamName = extractStr(plistXml, 'TeamName');
  const appIdName = extractStr(plistXml, 'AppIDName');
  const creationDate = extractStr(plistXml, 'CreationDate');
  const expirationDate = extractStr(plistXml, 'ExpirationDate');
  const uuid = extractStr(plistXml, 'UUID');
  const teamId = (extractArr(plistXml, 'TeamIdentifier') || [])[0] || null;
  const devices = extractArr(plistXml, 'ProvisionedDevices');
  const getTaskAllow = extractBool(plistXml, 'get-task-allow');
  const provAllDevices = extractBool(plistXml, 'ProvisionsAllDevices');

  const appIdStr = extractStr(plistXml, 'application-identifier');
  let bundleId = null;
  if (appIdStr) {
    const parts = appIdStr.split('.');
    bundleId = parts.length > 1 ? parts.slice(1).join('.') : appIdStr;
  }

  let profileType = 'Unknown';
  if (provAllDevices) {
    profileType = 'Enterprise (In-House)';
  } else if (devices.length > 0) {
    profileType = getTaskAllow ? 'Development' : 'Ad Hoc';
  } else {
    profileType = 'App Store';
  }

  const now = new Date();
  const expDate = expirationDate ? new Date(expirationDate) : null;
  const isExpired = expDate ? now > expDate : false;
  const daysLeft = expDate ? Math.ceil((expDate - now) / (1000 * 60 * 60 * 24)) : null;

  return {
    valid: true,
    name,
    team_name: teamName,
    team_id: teamId,
    app_id_name: appIdName,
    bundle_id: bundleId,
    uuid,
    type: profileType,
    creation_date: creationDate,
    expiration_date: expirationDate,
    is_expired: isExpired,
    days_left: isExpired ? 0 : daysLeft,
    device_count: devices.length,
    devices: devices.slice(0, 100),
    provisions_all_devices: provAllDevices || false,
    status: isExpired ? 'expired' : 'valid',
    status_text: isExpired ? '已过期' : `有效 (剩余 ${daysLeft} 天)`,
  };
}

router.post('/validate', upload.array('files', 10), async (req, res) => {
  try {
    if (!req.files || req.files.length === 0) {
      return res.status(400).json({ success: false, message: '请上传文件' });
    }

    const results = { p12: [], profiles: [], errors: [], remote_verified: false };
    const filesToProcess = [];

    for (const file of req.files) {
      const ext = path.extname(file.originalname).toLowerCase();

      if (ext === '.zip') {
        try {
          const zip = new AdmZip(file.path);
          const entries = zip.getEntries();
          for (const entry of entries) {
            if (entry.isDirectory) continue;
            const entryExt = path.extname(entry.entryName).toLowerCase();
            if (['.p12', '.pfx', '.mobileprovision', '.provisionprofile'].includes(entryExt)) {
              filesToProcess.push({
                name: path.basename(entry.entryName),
                ext: entryExt,
                buffer: entry.getData(),
              });
            }
          }
        } catch (err) {
          results.errors.push({ file: file.originalname, error: 'ZIP 解压失败: ' + err.message });
        }
      } else {
        filesToProcess.push({
          name: file.originalname,
          ext,
          buffer: fs.readFileSync(file.path),
        });
      }
    }

    const password = req.body.password || '';

    for (const f of filesToProcess) {
      try {
        if (f.ext === '.p12' || f.ext === '.pfx') {
          const result = parseP12Buffer(f.buffer, password);
          results.p12.push({ file: f.name, ...result });
        } else if (f.ext === '.mobileprovision' || f.ext === '.provisionprofile') {
          const result = parseProfileBuffer(f.buffer);
          results.profiles.push({ file: f.name, ...result });
        } else {
          results.errors.push({ file: f.name, error: '不支持的文件类型' });
        }
      } catch (err) {
        results.errors.push({ file: f.name, error: err.message });
      }
    }

    // Apple API remote verification
    const accountId = req.body.account_id;
    let appleApi = null;
    let remoteCerts = null;
    let remoteProfiles = null;

    if (accountId) {
      try {
        const account = await getDecryptedAccount(accountId);
        appleApi = new AppleApiService(account);

        const [certRes, profRes] = await Promise.all([
          appleApi.listCertificates().catch(() => null),
          appleApi.listProfiles().catch(() => null),
        ]);

        if (certRes?.data) {
          remoteCerts = certRes.data.map(c => ({
            id: c.id,
            serial: c.attributes?.serialNumber,
            name: c.attributes?.displayName || c.attributes?.name,
            type: c.attributes?.certificateType,
            expiration: c.attributes?.expirationDate,
          }));
        }

        if (profRes?.data) {
          remoteProfiles = profRes.data.map(p => ({
            id: p.id,
            uuid: p.attributes?.uuid,
            name: p.attributes?.name,
            type: p.attributes?.profileType,
            state: p.attributes?.profileState,
            expiration: p.attributes?.expirationDate,
          }));
        }

        results.remote_verified = !!(remoteCerts || remoteProfiles);
      } catch (err) {
        results.remote_error = `Apple API 连接失败: ${err.message}`;
      }
    }

    // Annotate certs with remote status
    if (remoteCerts) {
      for (const cert of results.p12) {
        if (!cert.valid) continue;
        const sn = cert.serial_number;
        const match = remoteCerts.find(rc =>
          rc.serial && sn && rc.serial.toLowerCase() === sn.toLowerCase()
        );
        if (match) {
          cert.apple_status = 'active';
          cert.apple_status_text = '✓ Apple 服务器确认有效';
          cert.apple_id = match.id;
          cert.apple_name = match.name;
        } else {
          cert.apple_status = 'not_found';
          cert.apple_status_text = '✕ Apple 服务器上未找到（可能已被吊销或属于其他账号）';
        }
      }
    }

    // Annotate profiles with remote status
    if (remoteProfiles) {
      for (const prof of results.profiles) {
        if (!prof.valid) continue;
        const match = remoteProfiles.find(rp => rp.uuid === prof.uuid);
        if (match) {
          prof.apple_status = match.state === 'ACTIVE' ? 'active' : 'invalid';
          prof.apple_status_text = match.state === 'ACTIVE'
            ? '✓ Apple 服务器确认有效'
            : `✕ Apple 服务器状态: ${match.state}`;
          prof.apple_id = match.id;
          prof.apple_profile_state = match.state;
        } else {
          prof.apple_status = 'not_found';
          prof.apple_status_text = '✕ Apple 服务器上未找到（可能已被删除或属于其他账号）';
        }
      }
    }

    // Match p12 certs with profiles
    const matches = [];
    for (const cert of results.p12) {
      if (!cert.valid) continue;
      for (const prof of results.profiles) {
        if (!prof.valid) continue;
        const certOk = !cert.is_expired && (!remoteCerts || cert.apple_status === 'active');
        const profOk = !prof.is_expired && (!remoteProfiles || prof.apple_status === 'active');
        const issues = [];
        if (cert.is_expired) issues.push('证书已过期');
        if (prof.is_expired) issues.push('描述文件已过期');
        if (remoteCerts && cert.apple_status !== 'active') issues.push('证书在 Apple 服务器不可用');
        if (remoteProfiles && prof.apple_status !== 'active') issues.push('描述文件在 Apple 服务器不可用');

        matches.push({
          cert_file: cert.file,
          profile_file: prof.file,
          cert_type: cert.type,
          profile_type: prof.type,
          bundle_id: prof.bundle_id,
          cert_expired: cert.is_expired,
          profile_expired: prof.is_expired,
          cert_apple_status: cert.apple_status,
          profile_apple_status: prof.apple_status,
          both_valid: certOk && profOk,
          summary: (certOk && profOk)
            ? `✓ 证书和描述文件均有效${results.remote_verified ? '（已通过 Apple 服务器验证）' : ''}，可用于 ${prof.bundle_id || 'N/A'}`
            : `✕ ${issues.join('，')}`,
        });
      }
    }
    results.matches = matches;

    // Cleanup temp files
    for (const file of req.files) {
      try { fs.unlinkSync(file.path); } catch {}
    }

    const totalFiles = results.p12.length + results.profiles.length;
    const validCount = results.p12.filter(c => c.valid && !c.is_expired).length
      + results.profiles.filter(p => p.valid && !p.is_expired).length;

    res.json({
      success: true,
      message: `检查完成：共 ${totalFiles} 个文件，${validCount} 个有效` +
        (results.remote_verified ? '（含 Apple 服务器验证）' : ''),
      data: results,
    });
  } catch (err) {
    res.status(500).json({ success: false, message: '检查失败: ' + err.message });
  }
});

module.exports = router;
