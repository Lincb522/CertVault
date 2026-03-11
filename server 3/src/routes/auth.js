const express = require('express');
const crypto = require('crypto');
const router = express.Router();
const { getDb } = require('../config/database');
const { sendVerifyCode } = require('../config/email');

function hashPassword(password, salt) {
  return crypto.pbkdf2Sync(password, salt, 10000, 64, 'sha512').toString('hex');
}

function generateToken() {
  return crypto.randomBytes(48).toString('hex');
}

function generateCode() {
  return String(Math.floor(100000 + Math.random() * 900000));
}

async function ensureAdminExists() {
  const db = getDb();
  const count = await db.prepare('SELECT COUNT(*) as c FROM users').get();
  if (count.c === 0) {
    const salt = crypto.randomBytes(16).toString('hex');
    const hash = hashPassword('yqq977522', salt);
    await db.prepare('INSERT INTO users (id, username, password, salt, role, email_verified) VALUES (?, ?, ?, ?, ?, 1)')
      .run(crypto.randomUUID(), 'zijiu522', hash, salt, 'superadmin');
    console.log('Super admin created: zijiu522');
  } else {
    const superadmin = await db.prepare("SELECT * FROM users WHERE role = 'superadmin'").get();
    if (!superadmin) {
      const existing = await db.prepare("SELECT * FROM users WHERE username = 'zijiu522'").get();
      if (existing) {
        await db.prepare("UPDATE users SET role = 'superadmin' WHERE id = ?").run(existing.id);
      } else {
        const salt = crypto.randomBytes(16).toString('hex');
        const hash = hashPassword('yqq977522', salt);
        await db.prepare('INSERT INTO users (id, username, password, salt, role, email_verified) VALUES (?, ?, ?, ?, ?, 1)')
          .run(crypto.randomUUID(), 'zijiu522', hash, salt, 'superadmin');
        console.log('Super admin created: zijiu522');
      }
    }
  }
}

router.post('/send-code', async (req, res) => {
  const { email, type } = req.body;
  if (!email) {
    return res.status(400).json({ success: false, message: '请输入邮箱地址' });
  }
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(email)) {
    return res.status(400).json({ success: false, message: '邮箱格式不正确' });
  }

  const codeType = type || 'register';
  const db = getDb();

  if (codeType === 'register') {
    const existing = await db.prepare('SELECT id FROM users WHERE email = ?').get(email);
    if (existing) {
      return res.status(409).json({ success: false, message: '该邮箱已被注册' });
    }
  }

  const recent = await db.prepare(
    "SELECT created_at FROM email_codes WHERE email = ? AND type = ? ORDER BY created_at DESC LIMIT 1"
  ).get(email, codeType);
  if (recent) {
    const elapsed = Date.now() - new Date(recent.created_at).getTime();
    if (elapsed < 60000) {
      return res.status(429).json({ success: false, message: '发送太频繁，请 60 秒后再试' });
    }
  }

  const code = generateCode();
  const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();

  try {
    await sendVerifyCode(email, code);
  } catch (err) {
    console.error('Send email failed:', err.message);
    return res.status(500).json({ success: false, message: err.message || '验证码发送失败' });
  }

  await db.prepare('INSERT INTO email_codes (email, code, type, expires_at) VALUES (?, ?, ?, ?)')
    .run(email, code, codeType, expiresAt);

  res.json({ success: true, message: '验证码已发送到您的邮箱' });
});

router.post('/register', async (req, res) => {
  const { username, password, email, code } = req.body;
  if (!username || !password || !email || !code) {
    return res.status(400).json({ success: false, message: '请填写用户名、密码、邮箱和验证码' });
  }
  if (username.length < 3) {
    return res.status(400).json({ success: false, message: '用户名至少 3 个字符' });
  }
  if (password.length < 6) {
    return res.status(400).json({ success: false, message: '密码至少 6 位' });
  }
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(email)) {
    return res.status(400).json({ success: false, message: '邮箱格式不正确' });
  }

  const db = getDb();

  const codeRecord = await db.prepare(
    "SELECT * FROM email_codes WHERE email = ? AND code = ? AND type = 'register' AND used = 0 AND expires_at::timestamptz > NOW() ORDER BY created_at DESC LIMIT 1"
  ).get(email, code);
  if (!codeRecord) {
    return res.status(400).json({ success: false, message: '验证码无效或已过期' });
  }

  const existingUser = await db.prepare('SELECT id FROM users WHERE username = ?').get(username);
  if (existingUser) {
    return res.status(409).json({ success: false, message: '用户名已存在' });
  }
  const existingEmail = await db.prepare('SELECT id FROM users WHERE email = ?').get(email);
  if (existingEmail) {
    return res.status(409).json({ success: false, message: '该邮箱已被注册' });
  }

  const salt = crypto.randomBytes(16).toString('hex');
  const hash = hashPassword(password, salt);
  const id = crypto.randomUUID();

  await db.prepare('INSERT INTO users (id, username, email, email_verified, password, salt, role) VALUES (?, ?, ?, 1, ?, ?, ?)')
    .run(id, username, email, hash, salt, 'user');

  await db.prepare('UPDATE email_codes SET used = 1 WHERE id = ?').run(codeRecord.id);

  const token = generateToken();
  const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
  await db.prepare('INSERT INTO sessions (token, user_id, expires_at) VALUES (?, ?, ?)')
    .run(token, id, expiresAt);

  res.json({
    success: true,
    message: '注册成功',
    data: { token, username, email, role: 'user', expires_at: expiresAt }
  });
});

router.post('/login', async (req, res) => {
  const { username, password } = req.body;
  if (!username || !password) {
    return res.status(400).json({ success: false, message: '请输入用户名和密码' });
  }

  const db = getDb();
  const user = await db.prepare('SELECT * FROM users WHERE username = ? OR email = ?').get(username, username);
  if (!user) {
    return res.status(401).json({ success: false, message: '用户名或密码错误' });
  }

  const hash = hashPassword(password, user.salt);
  if (hash !== user.password) {
    return res.status(401).json({ success: false, message: '用户名或密码错误' });
  }

  const token = generateToken();
  const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();

  await db.prepare('INSERT INTO sessions (token, user_id, expires_at) VALUES (?, ?, ?)')
    .run(token, user.id, expiresAt);

  res.json({
    success: true,
    data: {
      token,
      username: user.username,
      email: user.email,
      role: user.role,
      expires_at: expiresAt,
    }
  });
});

router.post('/logout', async (req, res) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (token) {
    const db = getDb();
    await db.prepare('DELETE FROM sessions WHERE token = ?').run(token);
  }
  res.json({ success: true, message: '已退出登录' });
});

router.get('/me', async (req, res) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ success: false, message: '未登录' });

  const db = getDb();
  const session = await db.prepare(
    "SELECT s.*, u.username, u.email, u.email_verified, u.role FROM sessions s JOIN users u ON s.user_id = u.id WHERE s.token = ? AND s.expires_at::timestamptz > NOW()"
  ).get(token);

  if (!session) return res.status(401).json({ success: false, message: '登录已过期' });

  res.json({
    success: true,
    data: { username: session.username, email: session.email, email_verified: session.email_verified, role: session.role }
  });
});

router.post('/change-password', async (req, res) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ success: false, message: '未登录' });

  const { old_password, new_password } = req.body;
  if (!old_password || !new_password) {
    return res.status(400).json({ success: false, message: '请填写旧密码和新密码' });
  }
  if (new_password.length < 6) {
    return res.status(400).json({ success: false, message: '新密码至少 6 位' });
  }

  const db = getDb();
  const session = await db.prepare(
    "SELECT s.user_id FROM sessions s WHERE s.token = ? AND s.expires_at::timestamptz > NOW()"
  ).get(token);
  if (!session) return res.status(401).json({ success: false, message: '登录已过期' });

  const user = await db.prepare('SELECT * FROM users WHERE id = ?').get(session.user_id);
  const oldHash = hashPassword(old_password, user.salt);
  if (oldHash !== user.password) {
    return res.status(400).json({ success: false, message: '旧密码错误' });
  }

  const newSalt = crypto.randomBytes(16).toString('hex');
  const newHash = hashPassword(new_password, newSalt);
  await db.prepare('UPDATE users SET password = ?, salt = ? WHERE id = ?').run(newHash, newSalt, user.id);
  await db.prepare('DELETE FROM sessions WHERE user_id = ? AND token != ?').run(user.id, token);

  res.json({ success: true, message: '密码修改成功' });
});

async function requireSuperAdmin(req, res, next) {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ success: false, message: '未登录' });

  const db = getDb();
  const session = await db.prepare(
    "SELECT u.id, u.username, u.role FROM sessions s JOIN users u ON s.user_id = u.id WHERE s.token = ? AND s.expires_at::timestamptz > NOW()"
  ).get(token);

  if (!session) return res.status(401).json({ success: false, message: '登录已过期' });
  if (session.role !== 'superadmin') {
    return res.status(403).json({ success: false, message: '权限不足，仅超级管理员可操作' });
  }

  req.superadmin = session;
  next();
}

router.get('/smtp-config', requireSuperAdmin, (req, res) => {
  res.json({
    success: true,
    data: {
      host: process.env.SMTP_HOST || '',
      port: process.env.SMTP_PORT || '465',
      secure: process.env.SMTP_SECURE || 'true',
      user: process.env.SMTP_USER || '',
      from_name: process.env.SMTP_FROM_NAME || 'CertManager',
      configured: !!(process.env.SMTP_USER && process.env.SMTP_PASS),
    }
  });
});

router.post('/smtp-config', requireSuperAdmin, (req, res) => {
  const { host, port, secure, user, pass, from_name } = req.body;
  if (host !== undefined) process.env.SMTP_HOST = host;
  if (port !== undefined) process.env.SMTP_PORT = String(port);
  if (secure !== undefined) process.env.SMTP_SECURE = String(secure);
  if (user !== undefined) process.env.SMTP_USER = user;
  if (pass !== undefined && pass !== '') process.env.SMTP_PASS = pass;
  if (from_name !== undefined) process.env.SMTP_FROM_NAME = from_name;

  const { getTransporter } = require('../config/email');
  try {
    require('../config/email').resetTransporter?.();
  } catch {}

  res.json({
    success: true,
    message: 'SMTP 配置已更新（运行时生效，重启后需重新配置或写入 .env）',
    data: {
      host: process.env.SMTP_HOST || '',
      port: process.env.SMTP_PORT || '465',
      secure: process.env.SMTP_SECURE || 'true',
      user: process.env.SMTP_USER || '',
      from_name: process.env.SMTP_FROM_NAME || 'CertManager',
      configured: !!(process.env.SMTP_USER && process.env.SMTP_PASS),
    }
  });
});

router.post('/smtp-test', requireSuperAdmin, async (req, res) => {
  const { to } = req.body;
  if (!to) return res.status(400).json({ success: false, message: '请填写收件邮箱' });

  const nodemailer = require('nodemailer');
  const config = {
    host: process.env.SMTP_HOST || 'smtp.qq.com',
    port: parseInt(process.env.SMTP_PORT || '465'),
    secure: (process.env.SMTP_SECURE || 'true') === 'true',
    auth: { user: process.env.SMTP_USER || '', pass: process.env.SMTP_PASS || '' },
  };

  if (!config.auth.user || !config.auth.pass) {
    return res.status(400).json({ success: false, message: 'SMTP 未配置，请先保存配置' });
  }

  try {
    const transporter = nodemailer.createTransport(config);
    await transporter.verify();
    await transporter.sendMail({
      from: `"${process.env.SMTP_FROM_NAME || 'CertManager'}" <${config.auth.user}>`,
      to,
      subject: '【CertVault】SMTP 测试邮件',
      html: '<div style="padding:20px;font-family:sans-serif"><h2>SMTP 配置测试成功</h2><p>如果您收到了这封邮件，说明 SMTP 配置正确。</p></div>',
    });
    res.json({ success: true, message: '测试邮件已发送' });
  } catch (err) {
    res.status(500).json({ success: false, message: `发送失败: ${err.message}` });
  }
});

router.get('/users', requireSuperAdmin, async (req, res) => {
  const db = getDb();
  const users = await db.prepare('SELECT id, username, email, email_verified, role, created_at FROM users ORDER BY created_at DESC').all();
  res.json({ success: true, data: users });
});

router.put('/users/:id/role', requireSuperAdmin, async (req, res) => {
  const { role } = req.body;
  if (!['user', 'superadmin'].includes(role)) {
    return res.status(400).json({ success: false, message: '无效角色，可选: user, superadmin' });
  }

  const db = getDb();
  const user = await db.prepare('SELECT * FROM users WHERE id = ?').get(req.params.id);
  if (!user) return res.status(404).json({ success: false, message: '用户不存在' });

  if (user.role === 'superadmin' && role !== 'superadmin') {
    const superCount = (await db.prepare("SELECT COUNT(*) as c FROM users WHERE role = 'superadmin'").get()).c;
    if (superCount <= 1) {
      return res.status(400).json({ success: false, message: '至少保留一个超级管理员' });
    }
  }

  await db.prepare('UPDATE users SET role = ? WHERE id = ?').run(role, req.params.id);
  res.json({ success: true, message: '角色修改成功' });
});

router.delete('/users/:id', requireSuperAdmin, async (req, res) => {
  const db = getDb();
  const user = await db.prepare('SELECT * FROM users WHERE id = ?').get(req.params.id);
  if (!user) return res.status(404).json({ success: false, message: '用户不存在' });

  if (user.id === req.superadmin.id) {
    return res.status(400).json({ success: false, message: '不能删除自己' });
  }

  if (user.role === 'superadmin') {
    const superCount = (await db.prepare("SELECT COUNT(*) as c FROM users WHERE role = 'superadmin'").get()).c;
    if (superCount <= 1) {
      return res.status(400).json({ success: false, message: '至少保留一个超级管理员' });
    }
  }

  await db.prepare('DELETE FROM sessions WHERE user_id = ?').run(req.params.id);
  await db.prepare('DELETE FROM users WHERE id = ?').run(req.params.id);
  res.json({ success: true, message: '用户已删除' });
});

router.post('/users/:id/reset-password', requireSuperAdmin, async (req, res) => {
  const { new_password } = req.body;
  if (!new_password || new_password.length < 6) {
    return res.status(400).json({ success: false, message: '新密码至少 6 位' });
  }

  const db = getDb();
  const user = await db.prepare('SELECT * FROM users WHERE id = ?').get(req.params.id);
  if (!user) return res.status(404).json({ success: false, message: '用户不存在' });

  const newSalt = crypto.randomBytes(16).toString('hex');
  const newHash = hashPassword(new_password, newSalt);
  await db.prepare('UPDATE users SET password = ?, salt = ? WHERE id = ?').run(newHash, newSalt, req.params.id);
  await db.prepare('DELETE FROM sessions WHERE user_id = ?').run(req.params.id);

  res.json({ success: true, message: '密码重置成功' });
});

module.exports = { router, ensureAdminExists };
