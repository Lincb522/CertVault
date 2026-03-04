const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const KEY_FILE = path.join(__dirname, '../../data/.encryption_key');
const ALGORITHM = 'aes-256-gcm';

function getEncryptionKey() {
  if (!fs.existsSync(path.dirname(KEY_FILE))) {
    fs.mkdirSync(path.dirname(KEY_FILE), { recursive: true });
  }

  if (fs.existsSync(KEY_FILE)) {
    return Buffer.from(fs.readFileSync(KEY_FILE, 'utf-8').trim(), 'hex');
  }

  const key = crypto.randomBytes(32);
  fs.writeFileSync(KEY_FILE, key.toString('hex'), { mode: 0o600 });
  console.log('Encryption key generated at', KEY_FILE);
  return key;
}

const MASTER_KEY = getEncryptionKey();

function encrypt(plaintext) {
  if (!plaintext) return plaintext;

  const iv = crypto.randomBytes(16);
  const cipher = crypto.createCipheriv(ALGORITHM, MASTER_KEY, iv);

  let encrypted = cipher.update(plaintext, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  const tag = cipher.getAuthTag().toString('hex');

  return `enc:${iv.toString('hex')}:${tag}:${encrypted}`;
}

function decrypt(ciphertext) {
  if (!ciphertext) return ciphertext;

  if (!ciphertext.startsWith('enc:')) {
    return ciphertext;
  }

  const parts = ciphertext.split(':');
  if (parts.length !== 4) return ciphertext;

  const iv = Buffer.from(parts[1], 'hex');
  const tag = Buffer.from(parts[2], 'hex');
  const encrypted = parts[3];

  const decipher = crypto.createDecipheriv(ALGORITHM, MASTER_KEY, iv);
  decipher.setAuthTag(tag);

  let decrypted = decipher.update(encrypted, 'hex', 'utf8');
  decrypted += decipher.final('utf8');
  return decrypted;
}

function isEncrypted(value) {
  return value?.startsWith('enc:');
}

module.exports = { encrypt, decrypt, isEncrypted };
