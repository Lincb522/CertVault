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

  const time = new Date().toLocaleString('zh-CN', { timeZone: 'Asia/Shanghai' });
  const iconShield = `<svg width="28" height="28" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" stroke="#f8fafc" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><path d="M9 12l2 2 4-4" stroke="#f8fafc" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>`;

  await t.sendMail({
    from: `"${FROM_NAME}" <${FROM_EMAIL}>`,
    to: email,
    subject: `[${FROM_NAME}] 邮箱验证码`,
    html: `
<!DOCTYPE html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#f1f5f9;font-family:-apple-system,BlinkMacSystemFont,'SF Pro Text','Segoe UI',Roboto,Helvetica,Arial,sans-serif">
<div style="max-width:560px;margin:32px auto;background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.06)">

  <div style="background:linear-gradient(135deg,#0f172a 0%,#1e293b 100%);padding:32px 28px 28px;text-align:center">
    <div style="display:inline-block;width:56px;height:56px;background:rgba(255,255,255,0.1);border-radius:16px;margin-bottom:16px;padding:14px;box-sizing:border-box">
      ${iconShield}
    </div>
    <h1 style="margin:0;color:#f8fafc;font-size:20px;font-weight:700;letter-spacing:-0.3px">邮箱验证</h1>
    <p style="margin:8px 0 0;color:#94a3b8;font-size:13px">${time}</p>
  </div>

  <div style="padding:28px">
    <p style="color:#475569;font-size:14px;line-height:1.6;margin:0 0 20px">您正在进行邮箱验证操作，请使用以下验证码完成验证：</p>

    <div style="background:linear-gradient(135deg,#eff6ff,#f0fdf4);border:1px solid #e2e8f0;border-radius:12px;padding:24px;text-align:center;margin:0 0 20px">
      <div style="font-size:36px;font-weight:800;letter-spacing:10px;color:#0f172a;font-family:'SF Mono','Fira Code',Consolas,monospace">${code}</div>
    </div>

    <div style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:8px;padding:12px 16px;font-size:12px;color:#64748b;line-height:1.6">
      <span style="display:inline-block;width:6px;height:6px;background:#f59e0b;border-radius:50%;margin-right:8px;vertical-align:middle"></span>验证码 10 分钟内有效<br>
      <span style="display:inline-block;width:6px;height:6px;background:#ef4444;border-radius:50%;margin-right:8px;vertical-align:middle"></span>如非您本人操作，请忽略此邮件
    </div>
  </div>

</div>
<div style="text-align:center;padding:0 0 32px;font-size:11px;color:#94a3b8">
  Sent by ${FROM_NAME} &middot; Security Service
</div>
</body></html>`,
  });
}

function resetTransporter() {
  transporter = null;
}

module.exports = { sendVerifyCode, getTransporter, resetTransporter };
