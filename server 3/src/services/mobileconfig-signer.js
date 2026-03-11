const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');

const SSL_DIR = path.join(__dirname, '../../data/ssl');
const SSL_CERT = process.env.SSL_CERT_PATH || path.join(SSL_DIR, 'fullchain.pem');
const SSL_KEY = process.env.SSL_KEY_PATH || path.join(SSL_DIR, 'privkey.key');
const SSL_CHAIN = process.env.SSL_CHAIN_PATH || path.join(SSL_DIR, 'chain.pem');

function canSign() {
  return SSL_CERT && SSL_KEY && fs.existsSync(SSL_CERT) && fs.existsSync(SSL_KEY);
}

function signMobileConfig(xmlContent) {
  if (!canSign()) {
    return Buffer.from(xmlContent, 'utf-8');
  }

  const tmpDir = os.tmpdir();
  const inputPath = path.join(tmpDir, `mobileconfig_${Date.now()}.xml`);
  const outputPath = path.join(tmpDir, `mobileconfig_${Date.now()}.signed`);

  try {
    fs.writeFileSync(inputPath, xmlContent, 'utf-8');

    let cmd = `openssl smime -sign -signer "${SSL_CERT}" -inkey "${SSL_KEY}"`;
    if (SSL_CHAIN && fs.existsSync(SSL_CHAIN)) {
      cmd += ` -certfile "${SSL_CHAIN}"`;
    }
    cmd += ` -nodetach -outform der -in "${inputPath}" -out "${outputPath}"`;

    execSync(cmd, { stdio: 'pipe' });

    const signed = fs.readFileSync(outputPath);
    return signed;
  } catch (err) {
    console.warn('[MobileConfig] Signing failed, returning unsigned:', err.message);
    return Buffer.from(xmlContent, 'utf-8');
  } finally {
    try { fs.unlinkSync(inputPath); } catch (_) {}
    try { fs.unlinkSync(outputPath); } catch (_) {}
  }
}

module.exports = { signMobileConfig, canSign };
