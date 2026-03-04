const { getDb } = require('../config/database');

async function requireAuth(req, res, next) {
  const token = req.headers.authorization?.replace('Bearer ', '') || req.query.token;
  if (!token) {
    return res.status(401).json({ success: false, message: '未登录，请先登录' });
  }

  const db = getDb();
  const session = await db.prepare(
    "SELECT s.user_id, u.username, u.role FROM sessions s JOIN users u ON s.user_id = u.id WHERE s.token = ? AND s.expires_at::timestamptz > NOW()"
  ).get(token);

  if (!session) {
    return res.status(401).json({ success: false, message: '登录已过期，请重新登录' });
  }

  req.user = { id: session.user_id, username: session.username, role: session.role };
  next();
}

module.exports = { requireAuth };
