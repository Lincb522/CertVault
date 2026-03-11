require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path');
const { initDatabase } = require('./config/database');
const { requireAuth } = require('./middleware/auth');
const { router: authRoutes, ensureAdminExists } = require('./routes/auth');

const accountRoutes = require('./routes/account');
const deviceRoutes = require('./routes/device');
const certificateRoutes = require('./routes/certificate');
const profileRoutes = require('./routes/profile');
const capabilityRoutes = require('./routes/capability');
const healthcheckRoutes = require('./routes/healthcheck');
const pushRoutes = require('./routes/push');
const pushKeysRoutes = require('./routes/push-keys');
const certCheckRoutes = require('./routes/cert-check');
const appsRoutes = require('./routes/apps');
const testflightRoutes = require('./routes/testflight');
const appstoreRoutes = require('./routes/appstore');

const app = express();
const PORT = process.env.PORT || 3006;

app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

app.use('/uploads', express.static(path.join(__dirname, '../data/uploads')));

const multer = require('multer');
const AdmZip = require('adm-zip');
const plist = require('plist');
const bplist = require('bplist-parser');
const ipaDir = path.join(__dirname, '../data/downloads');
const ipaUpload = multer({ dest: path.join(__dirname, '../data/tmp'), limits: { fileSize: 200 * 1024 * 1024 } });

function parseIpaInfo(filePath) {
  try {
    const zip = new AdmZip(filePath);
    const entries = zip.getEntries();
    const plistEntry = entries.find(e => /^Payload\/[^/]+\.app\/Info\.plist$/.test(e.entryName));
    if (!plistEntry) return null;
    const buf = plistEntry.getData();

    let info;
    if (buf[0] === 0x62 && buf[1] === 0x70 && buf[2] === 0x6C && buf[3] === 0x69) {
      const parsed = bplist.parseBuffer(buf);
      info = parsed && parsed[0] ? parsed[0] : null;
    } else {
      info = plist.parse(buf.toString('utf8'));
    }
    if (!info) return null;

    return {
      app_name: info.CFBundleDisplayName || info.CFBundleName || '',
      bundle_id: info.CFBundleIdentifier || '',
      version: info.CFBundleShortVersionString || '',
      build: String(info.CFBundleVersion || ''),
      min_os: info.MinimumOSVersion || '',
    };
  } catch (err) {
    console.error('parseIpaInfo error:', err.message);
    return null;
  }
}

app.get('/download/ipa', (req, res) => {
  const fs = require('fs');
  const files = fs.existsSync(ipaDir) ? fs.readdirSync(ipaDir).filter(f => f.endsWith('.ipa')).sort() : [];
  if (!files.length) return res.status(404).send('IPA 尚未上传');
  res.download(path.join(ipaDir, files[files.length - 1]));
});

app.get('/download/ipa/:name', (req, res) => {
  const fs = require('fs');
  const name = req.params.name;
  if (!name.endsWith('.ipa') || name.includes('..')) return res.status(400).send('无效文件名');
  const filePath = path.join(ipaDir, name);
  if (!fs.existsSync(filePath)) return res.status(404).send('文件不存在');
  res.download(filePath, name);
});

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', time: new Date().toISOString() });
});

app.get('/api/app/version', (req, res) => {
  const fs = require('fs');
  const versionFile = path.join(__dirname, '../data/app-version.json');
  const defaults = { version: '1.0.0', build: '1', force_update: false, changelog: '' };
  if (fs.existsSync(versionFile)) {
    try {
      const info = JSON.parse(fs.readFileSync(versionFile, 'utf8'));
      return res.json({ success: true, data: { ...defaults, ...info } });
    } catch {}
  }
  const files = fs.existsSync(ipaDir) ? fs.readdirSync(ipaDir).filter(f => f.endsWith('.ipa')).sort() : [];
  const hasIpa = files.length > 0;
  res.json({ success: true, data: { ...defaults, download_url: hasIpa ? '/download/ipa' : null } });
});

const udidRoutes = require('./routes/udid');

app.use('/api/auth', authRoutes);
app.use('/api/udid', udidRoutes);

app.use('/api', requireAuth);

function requireSuperAdmin(req, res, next) {
  if (req.user?.role !== 'superadmin') return res.status(403).json({ success: false, message: '需要超级管理员权限' });
  next();
}

app.post('/api/ipa/upload', requireSuperAdmin, ipaUpload.single('ipa'), (req, res) => {
  const fs = require('fs');
  if (!req.file) return res.status(400).json({ success: false, message: '请上传 IPA 文件' });

  const ipaInfo = parseIpaInfo(req.file.path);
  const base = path.basename(req.file.originalname, '.ipa');
  const ver = ipaInfo?.version || '';
  const build = ipaInfo?.build || '';
  const now = new Date();
  const ts = `${now.getFullYear()}${String(now.getMonth()+1).padStart(2,'0')}${String(now.getDate()).padStart(2,'0')}_${String(now.getHours()).padStart(2,'0')}${String(now.getMinutes()).padStart(2,'0')}`;
  const fileName = ver ? `${base}_v${ver}_b${build}_${ts}.ipa` : `${base}_${ts}.ipa`;

  if (!fs.existsSync(ipaDir)) fs.mkdirSync(ipaDir, { recursive: true });
  const destPath = path.join(ipaDir, fileName);
  fs.renameSync(req.file.path, destPath);

  const stats = fs.statSync(destPath);
  res.json({
    success: true,
    message: 'IPA 上传成功',
    data: {
      name: fileName,
      size: stats.size,
      updated_at: new Date().toISOString(),
      ipa_info: ipaInfo
    }
  });
});

app.get('/api/ipa/list', requireSuperAdmin, (req, res) => {
  const fs = require('fs');
  if (!fs.existsSync(ipaDir)) return res.json({ success: true, data: [] });
  const files = fs.readdirSync(ipaDir).filter(f => f.endsWith('.ipa')).map(name => {
    const filePath = path.join(ipaDir, name);
    const stats = fs.statSync(filePath);
    const ipaInfo = parseIpaInfo(filePath);
    return { name, size: stats.size, updated_at: stats.mtime.toISOString(), ipa_info: ipaInfo };
  });
  files.sort((a, b) => new Date(b.updated_at) - new Date(a.updated_at));
  res.json({ success: true, data: files });
});

const versionsFile = path.join(__dirname, '../data/app-versions.json');
const currentVersionFile = path.join(__dirname, '../data/app-version.json');

function loadVersions() {
  const fs = require('fs');
  if (!fs.existsSync(versionsFile)) return [];
  try { return JSON.parse(fs.readFileSync(versionsFile, 'utf8')); } catch { return []; }
}

function saveVersions(list) {
  const fs = require('fs');
  fs.mkdirSync(path.dirname(versionsFile), { recursive: true });
  fs.writeFileSync(versionsFile, JSON.stringify(list, null, 2));
}

function setCurrentVersion(entry) {
  const fs = require('fs');
  fs.mkdirSync(path.dirname(currentVersionFile), { recursive: true });
  fs.writeFileSync(currentVersionFile, JSON.stringify(entry, null, 2));
}

app.get('/api/app/versions', requireSuperAdmin, (req, res) => {
  const list = loadVersions();
  res.json({ success: true, data: list });
});

app.post('/api/app/versions', requireSuperAdmin, (req, res) => {
  const fs = require('fs');
  const { version, build, changelog, force_update, ipa_file } = req.body;
  if (!version) return res.status(400).json({ success: false, message: '版本号不能为空' });
  if (!ipa_file) return res.status(400).json({ success: false, message: '请选择 IPA 文件' });
  const ipaPath = path.join(ipaDir, ipa_file);
  if (!fs.existsSync(ipaPath)) return res.status(400).json({ success: false, message: '所选 IPA 文件不存在' });

  const id = Date.now().toString(36);
  const entry = {
    id, version, build: build || '1', changelog: changelog || '',
    force_update: !!force_update, ipa_file,
    download_url: `/download/ipa/${encodeURIComponent(ipa_file)}`,
    created_at: new Date().toISOString(), is_current: true
  };

  const list = loadVersions();
  list.forEach(v => v.is_current = false);
  list.unshift(entry);
  saveVersions(list);
  setCurrentVersion(entry);

  res.json({ success: true, message: '版本已发布', data: entry });
});

app.put('/api/app/versions/:id/current', requireSuperAdmin, (req, res) => {
  const list = loadVersions();
  const target = list.find(v => v.id === req.params.id);
  if (!target) return res.status(404).json({ success: false, message: '版本不存在' });

  list.forEach(v => v.is_current = false);
  target.is_current = true;
  saveVersions(list);
  setCurrentVersion(target);

  res.json({ success: true, message: '已设为当前版本', data: target });
});

app.delete('/api/app/versions/:id', requireSuperAdmin, (req, res) => {
  let list = loadVersions();
  const target = list.find(v => v.id === req.params.id);
  if (!target) return res.status(404).json({ success: false, message: '版本不存在' });
  if (target.is_current) return res.status(400).json({ success: false, message: '不能删除当前发布版本' });

  list = list.filter(v => v.id !== req.params.id);
  saveVersions(list);

  res.json({ success: true, message: '已删除' });
});

app.delete('/api/ipa/:name', requireSuperAdmin, (req, res) => {
  const fs = require('fs');
  const name = req.params.name;
  if (!name.endsWith('.ipa') || name.includes('..')) return res.status(400).json({ success: false, message: '无效文件名' });
  const filePath = path.join(ipaDir, name);
  if (!fs.existsSync(filePath)) return res.status(404).json({ success: false, message: '文件不存在' });
  fs.unlinkSync(filePath);
  res.json({ success: true, message: '已删除' });
});

app.get('/api/dashboard', async (req, res) => {
  const { getDb } = require('./config/database');
  const db = getDb();
  const userId = req.user.id;
  const isSuperAdmin = req.user.role === 'superadmin';

  let accountFilter, certFilter, deviceFilter, profileFilter, bundleFilter, certP12Filter;
  if (isSuperAdmin) {
    accountFilter = db.prepare('SELECT COUNT(*) as count FROM accounts');
    deviceFilter = db.prepare("SELECT COUNT(*) as count FROM devices WHERE UPPER(status) IN ('ENABLED','DISABLED')");
    certFilter = db.prepare('SELECT COUNT(*) as count FROM certificates');
    certP12Filter = db.prepare("SELECT COUNT(*) as count FROM certificates WHERE p12_path IS NOT NULL AND p12_path != ''");
    profileFilter = db.prepare('SELECT COUNT(*) as count FROM profiles');
    bundleFilter = db.prepare('SELECT COUNT(*) as count FROM bundle_ids');
  } else {
    accountFilter = db.prepare('SELECT COUNT(*) as count FROM accounts WHERE user_id = ?');
    deviceFilter = db.prepare("SELECT COUNT(*) as count FROM devices WHERE UPPER(status) IN ('ENABLED','DISABLED') AND account_id IN (SELECT id FROM accounts WHERE user_id = ?)");
    certFilter = db.prepare('SELECT COUNT(*) as count FROM certificates WHERE user_id = ?');
    certP12Filter = db.prepare("SELECT COUNT(*) as count FROM certificates WHERE user_id = ? AND p12_path IS NOT NULL AND p12_path != ''");
    profileFilter = db.prepare('SELECT COUNT(*) as count FROM profiles WHERE account_id IN (SELECT id FROM accounts WHERE user_id = ?)');
    bundleFilter = db.prepare('SELECT COUNT(*) as count FROM bundle_ids WHERE account_id IN (SELECT id FROM accounts WHERE user_id = ?)');
  }

  const args = isSuperAdmin ? [] : [userId];
  const accounts = parseInt((await accountFilter.get(...args)).count, 10) || 0;
  const devices = parseInt((await deviceFilter.get(...args)).count, 10) || 0;
  const certificates = parseInt((await certFilter.get(...args)).count, 10) || 0;
  const certsWithP12 = parseInt((await certP12Filter.get(...args)).count, 10) || 0;
  const profiles = parseInt((await profileFilter.get(...args)).count, 10) || 0;
  const bundleIds = parseInt((await bundleFilter.get(...args)).count, 10) || 0;

  const recentCerts = isSuperAdmin
    ? await db.prepare('SELECT id, name, type, expires_at, created_at FROM certificates ORDER BY created_at DESC LIMIT 5').all()
    : await db.prepare('SELECT id, name, type, expires_at, created_at FROM certificates WHERE user_id = ? ORDER BY created_at DESC LIMIT 5').all(userId);
  const recentDevices = isSuperAdmin
    ? await db.prepare('SELECT id, name, udid, platform, created_at FROM devices ORDER BY created_at DESC LIMIT 5').all()
    : await db.prepare('SELECT id, name, udid, platform, created_at FROM devices WHERE account_id IN (SELECT id FROM accounts WHERE user_id = ?) ORDER BY created_at DESC LIMIT 5').all(userId);

  res.json({
    success: true,
    data: {
      stats: { accounts, devices, certificates, certs_with_p12: certsWithP12, profiles, bundle_ids: bundleIds },
      recent_certificates: recentCerts,
      recent_devices: recentDevices,
    }
  });
});

app.use('/api/accounts', accountRoutes);
app.use('/api/devices', deviceRoutes);
app.use('/api/certificates', certificateRoutes);
app.use('/api/profiles', profileRoutes);
app.use('/api/capabilities', capabilityRoutes);
app.use('/api/healthcheck', healthcheckRoutes);
app.use('/api/push', pushRoutes);
app.use('/api/push-keys', pushKeysRoutes);
app.use('/api/cert-check', certCheckRoutes);
app.use('/api/apps', appsRoutes);
app.use('/api/testflight', testflightRoutes);
app.use('/api/appstore', appstoreRoutes);

const fs = require('fs');

const publicDir = path.join(__dirname, '../public');
const clientDist = path.join(__dirname, '../client');

console.log('[路径诊断]');
console.log('  __dirname:', __dirname);
console.log('  publicDir:', publicDir, '存在:', fs.existsSync(publicDir));
console.log('  clientDist:', clientDist, '存在:', fs.existsSync(clientDist));
if (fs.existsSync(publicDir)) {
  console.log('  public/ 文件:', fs.readdirSync(publicDir));
}
if (fs.existsSync(clientDist)) {
  console.log('  client/ 文件:', fs.readdirSync(clientDist));
  const clientIndex = path.join(clientDist, 'index.html');
  if (fs.existsSync(clientIndex)) {
    const content = fs.readFileSync(clientIndex, 'utf8');
    console.log('  client/index.html 大小:', content.length, '包含/admin/:', content.includes('/admin/'));
  }
}

app.use('/admin', express.static(clientDist, { redirect: false, index: false }));
app.get('/admin*', (req, res) => {
  if (req.path.match(/\.(js|css|png|jpg|gif|svg|ico|woff2?|ttf|eot|map)$/)) {
    return res.status(404).send('Not found');
  }
  const indexPath = path.join(clientDist, 'index.html');
  if (fs.existsSync(indexPath)) {
    return res.sendFile(indexPath);
  }
  res.status(500).send('Admin panel not found: ' + indexPath);
});

app.use(express.static(publicDir));

app.use((err, req, res, next) => {
  console.error('Server Error:', err);
  res.status(err.status || 500).json({
    success: false,
    message: err.message || '服务器内部错误'
  });
});

async function deduplicateRecords() {
  const { getDb } = require('./config/database');
  const db = getDb();
  try {
    const dupCerts = await db.prepare(`
      SELECT c1.id AS dup_id FROM certificates c1
      INNER JOIN certificates c2 ON c1.apple_id = c2.apple_id AND c1.account_id = c2.account_id
      WHERE c1.apple_id IS NOT NULL AND c1.id = c1.apple_id AND c2.id != c2.apple_id
    `).all();
    for (const row of dupCerts) {
      await db.prepare('DELETE FROM certificates WHERE id = ?').run(row.dup_id);
    }
    if (dupCerts.length > 0) console.log(`Cleaned ${dupCerts.length} duplicate certificates`);

    const dupProfiles = await db.prepare(`
      SELECT p1.id AS dup_id FROM profiles p1
      INNER JOIN profiles p2 ON p1.apple_id = p2.apple_id AND p1.account_id = p2.account_id
      WHERE p1.apple_id IS NOT NULL AND p1.id = p1.apple_id AND p2.id != p2.apple_id
    `).all();
    for (const row of dupProfiles) {
      await db.prepare('DELETE FROM profiles WHERE id = ?').run(row.dup_id);
    }
    if (dupProfiles.length > 0) console.log(`Cleaned ${dupProfiles.length} duplicate profiles`);
  } catch (e) {
    console.error('Dedup error:', e.message);
  }
}

initDatabase().then(async () => {
  await ensureAdminExists();
  await deduplicateRecords();

  app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
  });
}).catch(err => {
  console.error('Failed to init database:', err);
  process.exit(1);
});
