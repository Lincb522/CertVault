const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.PG_HOST || '127.0.0.1',
  port: parseInt(process.env.PG_PORT || '5432'),
  database: process.env.PG_DATABASE || 'CertManager',
  user: process.env.PG_USER || 'CertManager',
  password: process.env.PG_PASSWORD || 'Yqq977522.',
  max: 10,
});

function convertPlaceholders(sql) {
  let idx = 0;
  return sql.replace(/\?/g, () => `$${++idx}`);
}

function wrapStatement(sql) {
  const pgSql = convertPlaceholders(sql);
  return {
    async get(...params) {
      const flat = params.length === 1 && Array.isArray(params[0]) ? params[0] : params;
      const { rows } = await pool.query(pgSql, flat);
      return rows[0] || null;
    },
    async all(...params) {
      const flat = params.length === 1 && Array.isArray(params[0]) ? params[0] : params;
      const { rows } = await pool.query(pgSql, flat);
      return rows;
    },
    async run(...params) {
      const flat = params.length === 1 && Array.isArray(params[0]) ? params[0] : params;
      const result = await pool.query(pgSql, flat);
      return { changes: result.rowCount };
    }
  };
}

let db;

function getDb() {
  if (!db) throw new Error('Database not initialized. Call initDatabase() first.');
  return db;
}

function createDbProxy() {
  return {
    prepare(sql) {
      return wrapStatement(sql);
    },
    async exec(sql) {
      await pool.query(sql);
    },
    transaction(fn) {
      return async (...args) => {
        const client = await pool.connect();
        try {
          await client.query('BEGIN');
          const txDb = {
            prepare(sql) {
              const pgSql = convertPlaceholders(sql);
              return {
                async get(...params) {
                  const flat = params.length === 1 && Array.isArray(params[0]) ? params[0] : params;
                  const { rows } = await client.query(pgSql, flat);
                  return rows[0] || null;
                },
                async all(...params) {
                  const flat = params.length === 1 && Array.isArray(params[0]) ? params[0] : params;
                  const { rows } = await client.query(pgSql, flat);
                  return rows;
                },
                async run(...params) {
                  const flat = params.length === 1 && Array.isArray(params[0]) ? params[0] : params;
                  const result = await client.query(pgSql, flat);
                  return { changes: result.rowCount };
                }
              };
            },
            async exec(sql) {
              await client.query(sql);
            }
          };
          const result = await fn(txDb, ...args);
          await client.query('COMMIT');
          return result;
        } catch (e) {
          await client.query('ROLLBACK');
          throw e;
        } finally {
          client.release();
        }
      };
    }
  };
}

async function initDatabase() {
  db = createDbProxy();

  await pool.query(`
    CREATE TABLE IF NOT EXISTS accounts (
      id TEXT PRIMARY KEY,
      user_id TEXT,
      name TEXT NOT NULL,
      issuer_id TEXT NOT NULL,
      key_id TEXT NOT NULL,
      private_key TEXT NOT NULL,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS certificates (
      id TEXT PRIMARY KEY,
      user_id TEXT,
      account_id TEXT,
      apple_id TEXT,
      type TEXT NOT NULL,
      name TEXT NOT NULL,
      csr_content TEXT,
      private_key TEXT,
      cert_content TEXT,
      p12_path TEXT,
      password TEXT,
      is_self_signed INTEGER DEFAULT 0,
      expires_at TEXT,
      created_at TIMESTAMPTZ DEFAULT NOW(),
      FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE SET NULL
    );

    CREATE TABLE IF NOT EXISTS devices (
      id TEXT PRIMARY KEY,
      account_id TEXT NOT NULL,
      apple_id TEXT,
      udid TEXT NOT NULL,
      name TEXT NOT NULL,
      platform TEXT DEFAULT 'IOS',
      status TEXT DEFAULT 'ENABLED',
      model TEXT,
      created_at TIMESTAMPTZ DEFAULT NOW(),
      FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS bundle_ids (
      id TEXT PRIMARY KEY,
      account_id TEXT NOT NULL,
      apple_id TEXT,
      identifier TEXT NOT NULL,
      name TEXT NOT NULL,
      platform TEXT DEFAULT 'IOS',
      created_at TIMESTAMPTZ DEFAULT NOW(),
      FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS profiles (
      id TEXT PRIMARY KEY,
      account_id TEXT NOT NULL,
      apple_id TEXT,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      bundle_id TEXT,
      profile_content TEXT,
      profile_path TEXT,
      expires_at TEXT,
      created_at TIMESTAMPTZ DEFAULT NOW(),
      FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      username TEXT NOT NULL UNIQUE,
      email TEXT UNIQUE,
      email_verified INTEGER DEFAULT 0,
      password TEXT NOT NULL,
      salt TEXT NOT NULL,
      role TEXT DEFAULT 'user',
      created_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS email_codes (
      id SERIAL PRIMARY KEY,
      email TEXT NOT NULL,
      code TEXT NOT NULL,
      type TEXT DEFAULT 'register',
      expires_at TEXT NOT NULL,
      used INTEGER DEFAULT 0,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS sessions (
      token TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      expires_at TEXT NOT NULL,
      created_at TIMESTAMPTZ DEFAULT NOW(),
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS device_resources (
      id SERIAL PRIMARY KEY,
      device_id TEXT NOT NULL,
      cert_id TEXT,
      profile_id TEXT,
      bundle_identifier TEXT,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS push_keys (
      id TEXT PRIMARY KEY,
      user_id TEXT,
      name TEXT NOT NULL,
      key_id TEXT NOT NULL,
      team_id TEXT NOT NULL,
      private_key TEXT NOT NULL,
      bundle_ids TEXT,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS push_devices (
      id SERIAL PRIMARY KEY,
      user_id TEXT NOT NULL,
      device_token TEXT NOT NULL,
      platform TEXT DEFAULT 'ios',
      created_at TIMESTAMPTZ DEFAULT NOW(),
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    );
    CREATE UNIQUE INDEX IF NOT EXISTS idx_push_devices_token ON push_devices(device_token);
  `);

  console.log('Database initialized (PostgreSQL)');

  // Migration: add user_id columns if missing
  const migrations = [
    "ALTER TABLE accounts ADD COLUMN IF NOT EXISTS user_id TEXT",
    "ALTER TABLE certificates ADD COLUMN IF NOT EXISTS user_id TEXT",
    "ALTER TABLE push_keys ADD COLUMN IF NOT EXISTS user_id TEXT",
  ];
  for (const sql of migrations) {
    try { await pool.query(sql); } catch (e) { /* column may already exist */ }
  }
}

module.exports = { getDb, initDatabase };
