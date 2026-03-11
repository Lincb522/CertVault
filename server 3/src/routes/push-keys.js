const express = require('express');
const router = express.Router();
const path = require('path');
const fs = require('fs');
const multer = require('multer');
const { v4: uuidv4 } = require('uuid');
const { getDb } = require('../config/database');
const { encrypt, decrypt } = require('../services/encryption');

const P8_DIR = path.join(__dirname, '../../data/p8keys');
if (!fs.existsSync(P8_DIR)) fs.mkdirSync(P8_DIR, { recursive: true });

const upload = multer({
  storage: multer.diskStorage({
    destination: (req, file, cb) => cb(null, P8_DIR),
    filename: (req, file, cb) => cb(null, `push_${uuidv4()}${path.extname(file.originalname)}`)
  }),
  fileFilter: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    if (['.p8', '.pem', '.key'].includes(ext)) cb(null, true);
    else cb(new Error('仅支持 .p8 / .pem / .key 格式'));
  },
  limits: { fileSize: 1024 * 100 }
});

function normalizeKey(content) {
  let k = content.trim();
  if (!k.includes('-----BEGIN')) {
    k = `-----BEGIN PRIVATE KEY-----\n${k}\n-----END PRIVATE KEY-----`;
  }
  return k;
}

function guessKeyId(filename) {
  const match = filename.match(/AuthKey_(\w+)\.p8/i);
  return match ? match[1] : '';
}

router.get('/', async (req, res) => {
  const db = getDb();
  const keys = req.user.role === 'superadmin'
    ? await db.prepare('SELECT id, name, key_id, team_id, bundle_ids, created_at FROM push_keys ORDER BY created_at DESC').all()
    : await db.prepare('SELECT id, name, key_id, team_id, bundle_ids, created_at FROM push_keys WHERE user_id = ? ORDER BY created_at DESC').all(req.user.id);
  res.json({ success: true, data: keys });
});

router.post('/', upload.single('file'), async (req, res) => {
  let { name, key_id, team_id, private_key, bundle_ids } = req.body;

  if (req.file) {
    private_key = fs.readFileSync(req.file.path, 'utf-8');
    if (!key_id) key_id = guessKeyId(req.file.originalname);
  }

  if (!name || !key_id || !team_id || !private_key) {
    return res.status(400).json({ success: false, message: '请填写名称、Key ID、Team ID 并提供 .p8 密钥' });
  }

  private_key = normalizeKey(private_key);

  const db = getDb();
  const id = uuidv4();
  await db.prepare('INSERT INTO push_keys (id, user_id, name, key_id, team_id, private_key, bundle_ids) VALUES (?, ?, ?, ?, ?, ?, ?)')
    .run(id, req.user.id, name, key_id.trim(), team_id.trim(), encrypt(private_key), bundle_ids || '');

  res.json({ success: true, data: { id, name, key_id, team_id }, message: '推送密钥导入成功' });
});

router.put('/:id', async (req, res) => {
  const { name, key_id, team_id, private_key, bundle_ids } = req.body;
  const db = getDb();
  const existing = await db.prepare('SELECT * FROM push_keys WHERE id = ?').get(req.params.id);
  if (!existing) return res.status(404).json({ success: false, message: '推送密钥不存在' });
  if (existing.user_id && existing.user_id !== req.user.id && req.user.role !== 'superadmin') {
    return res.status(403).json({ success: false, message: '无权操作此推送密钥' });
  }

  await db.prepare('UPDATE push_keys SET name = ?, key_id = ?, team_id = ?, private_key = ?, bundle_ids = ? WHERE id = ?')
    .run(
      name || existing.name,
      key_id || existing.key_id,
      team_id || existing.team_id,
      private_key ? encrypt(normalizeKey(private_key)) : existing.private_key,
      bundle_ids !== undefined ? bundle_ids : existing.bundle_ids,
      req.params.id
    );

  res.json({ success: true, message: '更新成功' });
});

router.delete('/:id', async (req, res) => {
  const db = getDb();
  const existing = await db.prepare('SELECT * FROM push_keys WHERE id = ?').get(req.params.id);
  if (!existing) return res.status(404).json({ success: false, message: '推送密钥不存在' });
  if (existing.user_id && existing.user_id !== req.user.id && req.user.role !== 'superadmin') {
    return res.status(403).json({ success: false, message: '无权操作此推送密钥' });
  }
  await db.prepare('DELETE FROM push_keys WHERE id = ?').run(req.params.id);
  res.json({ success: true, message: '删除成功' });
});

router.get('/:id/download', async (req, res) => {
  const db = getDb();
  const key = await db.prepare('SELECT * FROM push_keys WHERE id = ?').get(req.params.id);
  if (!key) return res.status(404).json({ success: false, message: '推送密钥不存在' });
  if (key.user_id && key.user_id !== req.user.id && req.user.role !== 'superadmin') {
    return res.status(403).json({ success: false, message: '无权操作此推送密钥' });
  }

  const filename = `APNsKey_${key.key_id}.p8`;
  res.setHeader('Content-Type', 'application/octet-stream');
  res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
  res.send(decrypt(key.private_key));
});

module.exports = router;
