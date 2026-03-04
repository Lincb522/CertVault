const { getDb } = require('../config/database');
const { decrypt } = require('./encryption');

async function getDecryptedAccount(accountId) {
  const db = getDb();
  const account = await db.prepare('SELECT * FROM accounts WHERE id = ?').get(accountId);
  if (!account) {
    const err = new Error('账号不存在');
    err.status = 404;
    throw err;
  }
  account.private_key = decrypt(account.private_key);
  return account;
}

async function checkAccountOwnership(accountId, user) {
  const db = getDb();
  const account = await db.prepare('SELECT user_id FROM accounts WHERE id = ?').get(accountId);
  if (!account) return false;
  if (user.role === 'superadmin') return true;
  return account.user_id === user.id;
}

module.exports = { getDecryptedAccount, checkAccountOwnership };
