const nodemailer = require('nodemailer');

const EMAIL_CONFIG = {
  host: process.env.SMTP_HOST || 'smtp.qq.com',
  port: parseInt(process.env.SMTP_PORT || '465'),
  secure: (process.env.SMTP_SECURE || 'true') === 'true',
  auth: {
    user: process.env.SMTP_USER || '',
    pass: process.env.SMTP_PASS || '',
  },
};

const FROM_NAME = process.env.SMTP_FROM_NAME || 'CertManager';
const FROM_EMAIL = process.env.SMTP_USER || '';

let transporter = null;

function getTransporter() {
  if (!transporter) {
    if (!EMAIL_CONFIG.auth.user || !EMAIL_CONFIG.auth.pass) {
      console.warn('SMTP not configured. Set SMTP_HOST, SMTP_USER, SMTP_PASS env vars.');
      return null;
    }
    transporter = nodemailer.createTransport(EMAIL_CONFIG);
  }
  return transporter;
}

async function sendVerifyCode(email, code) {
  const t = getTransporter();
  if (!t) throw new Error('邮件服务未配置，请联系管理员设置 SMTP');

  await t.sendMail({
    from: `"${FROM_NAME}" <${FROM_EMAIL}>`,
    to: email,
    subject: `【${FROM_NAME}】邮箱验证码`,
    html: `
      <div style="max-width:480px;margin:0 auto;padding:32px;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif">
        <h2 style="color:#1d1e2c;margin:0 0 16px">邮箱验证码</h2>
        <p style="color:#606266;line-height:1.6">您正在进行邮箱验证，验证码为：</p>
        <div style="background:#f4f4f5;border-radius:8px;padding:20px;text-align:center;margin:16px 0">
          <span style="font-size:32px;font-weight:700;letter-spacing:8px;color:#409eff">${code}</span>
        </div>
        <p style="color:#909399;font-size:13px;line-height:1.6">
          验证码 10 分钟内有效。如果不是您本人操作，请忽略此邮件。
        </p>
      </div>
    `,
  });
}

function resetTransporter() {
  transporter = null;
}

module.exports = { sendVerifyCode, getTransporter, resetTransporter };
