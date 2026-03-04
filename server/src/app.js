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

const app = express();
const PORT = process.env.PORT || 3006;

app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

app.use('/uploads', express.static(path.join(__dirname, '../data/uploads')));

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', time: new Date().toISOString() });
});

const udidRoutes = require('./routes/udid');

app.use('/api/auth', authRoutes);
app.use('/api/udid', udidRoutes);

app.use('/api', requireAuth);

app.get('/api/dashboard', async (req, res) => {
  const { getDb } = require('./config/database');
  const db = getDb();
  const userId = req.user.id;
  const isSuperAdmin = req.user.role === 'superadmin';

  let accountFilter, certFilter, deviceFilter, profileFilter, bundleFilter, certP12Filter;
  if (isSuperAdmin) {
    accountFilter = db.prepare('SELECT COUNT(*) as count FROM accounts');
    deviceFilter = db.prepare('SELECT COUNT(*) as count FROM devices');
    certFilter = db.prepare('SELECT COUNT(*) as count FROM certificates');
    certP12Filter = db.prepare("SELECT COUNT(*) as count FROM certificates WHERE p12_path IS NOT NULL AND p12_path != ''");
    profileFilter = db.prepare('SELECT COUNT(*) as count FROM profiles');
    bundleFilter = db.prepare('SELECT COUNT(*) as count FROM bundle_ids');
  } else {
    accountFilter = db.prepare('SELECT COUNT(*) as count FROM accounts WHERE user_id = ?');
    deviceFilter = db.prepare('SELECT COUNT(*) as count FROM devices WHERE account_id IN (SELECT id FROM accounts WHERE user_id = ?)');
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

const clientDist = path.join(__dirname, '../client');
const fs = require('fs');
if (fs.existsSync(clientDist)) {
  app.use(express.static(clientDist));
  app.get('*', (req, res, next) => {
    if (req.path.startsWith('/api/')) return next();
    res.sendFile(path.join(clientDist, 'index.html'));
  });
}

app.use((err, req, res, next) => {
  console.error('Server Error:', err);
  res.status(err.status || 500).json({
    success: false,
    message: err.message || '服务器内部错误'
  });
});

initDatabase().then(async () => {
  await ensureAdminExists();

  app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
  });
}).catch(err => {
  console.error('Failed to init database:', err);
  process.exit(1);
});
