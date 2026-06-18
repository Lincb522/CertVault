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
      udid TEXT,
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

    CREATE TABLE IF NOT EXISTS deleted_apple_certs (
      apple_id TEXT NOT NULL,
      account_id TEXT NOT NULL,
      deleted_at TIMESTAMPTZ DEFAULT NOW(),
      PRIMARY KEY (apple_id, account_id)
    );

    CREATE TABLE IF NOT EXISTS push_settings (
      key TEXT PRIMARY KEY,
      value TEXT,
      updated_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS push_history (
      id SERIAL PRIMARY KEY,
      user_id TEXT,
      type TEXT NOT NULL DEFAULT 'single',
      title TEXT NOT NULL,
      body TEXT,
      bundle_id TEXT,
      sandbox BOOLEAN DEFAULT false,
      device_token TEXT,
      apns_id TEXT,
      target_count INTEGER DEFAULT 1,
      success_count INTEGER DEFAULT 0,
      failed_count INTEGER DEFAULT 0,
      unregistered_count INTEGER DEFAULT 0,
      errors JSONB,
      status TEXT DEFAULT 'success',
      duration_ms INTEGER,
      created_at TIMESTAMPTZ DEFAULT NOW(),
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
    );
  `);

  console.log('Database initialized (PostgreSQL)');

  // Migration: add user_id columns if missing
  const migrations = [
    "ALTER TABLE accounts ADD COLUMN IF NOT EXISTS user_id TEXT",
    "ALTER TABLE certificates ADD COLUMN IF NOT EXISTS user_id TEXT",
    "ALTER TABLE push_keys ADD COLUMN IF NOT EXISTS user_id TEXT",
    "ALTER TABLE device_resources ADD COLUMN IF NOT EXISTS udid TEXT",
    "ALTER TABLE push_devices ADD COLUMN IF NOT EXISTS sandbox BOOLEAN DEFAULT false",
    "ALTER TABLE push_devices ADD COLUMN IF NOT EXISTS label TEXT",
    "ALTER TABLE push_devices ADD COLUMN IF NOT EXISTS remark TEXT",
    "ALTER TABLE push_devices ADD COLUMN IF NOT EXISTS device_name TEXT",
    "ALTER TABLE push_devices ADD COLUMN IF NOT EXISTS model TEXT",
    "ALTER TABLE push_devices ADD COLUMN IF NOT EXISTS os_version TEXT",
    "ALTER TABLE push_devices ADD COLUMN IF NOT EXISTS app_version TEXT",
  ];

  // Device registration history table
  await pool.query(`
    CREATE TABLE IF NOT EXISTS device_register_history (
      id SERIAL PRIMARY KEY,
      device_token TEXT NOT NULL,
      user_id TEXT,
      username TEXT,
      action TEXT DEFAULT 'register',
      platform TEXT DEFAULT 'ios',
      sandbox BOOLEAN DEFAULT false,
      label TEXT,
      remark TEXT,
      device_name TEXT,
      model TEXT,
      os_version TEXT,
      app_version TEXT,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS idx_drh_token ON device_register_history(device_token);
    CREATE INDEX IF NOT EXISTS idx_drh_created ON device_register_history(created_at DESC);
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS tf_share_links (
      id TEXT PRIMARY KEY,
      slug TEXT NOT NULL UNIQUE,
      account_id TEXT NOT NULL,
      group_id TEXT NOT NULL,
      user_id TEXT,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS idx_tf_share_account ON tf_share_links(account_id);
  `);

  // Scheduled pushes table
  await pool.query(`
    CREATE TABLE IF NOT EXISTS scheduled_pushes (
      id SERIAL PRIMARY KEY,
      user_id TEXT,
      type TEXT NOT NULL DEFAULT 'single',
      title TEXT NOT NULL,
      body TEXT,
      bundle_id TEXT,
      sandbox BOOLEAN DEFAULT false,
      device_token TEXT,
      push_key_id TEXT,
      custom_data JSONB,
      scheduled_at TIMESTAMPTZ NOT NULL,
      status TEXT DEFAULT 'pending',
      result JSONB,
      created_at TIMESTAMPTZ DEFAULT NOW(),
      executed_at TIMESTAMPTZ,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
    )
  `);
  for (const sql of migrations) {
    try { await pool.query(sql); } catch (e) { /* column may already exist */ }
  }

  const defaultSettings = {
    push_enabled: 'true',
    default_push_key_id: '',
    default_bundle_id: '',
    default_sandbox: 'false',
    apns_expiration: '0',
    apns_priority: '10',
    max_concurrency: '10',
    auto_cleanup_enabled: 'false',
    history_retention_days: '30',
    tf_auto_push_enabled: 'false',
    tf_auto_push_title: '🎉 新测试版本 {version}',
    tf_auto_push_body: '新版本已分发到测试组，请前往 TestFlight 更新。\n{whats_new}',
  };
  for (const [key, value] of Object.entries(defaultSettings)) {
    await pool.query(
      `INSERT INTO push_settings (key, value) VALUES ($1, $2) ON CONFLICT (key) DO NOTHING`,
      [key, value]
    );
  }
}

module.exports = { getDb, initDatabase };
