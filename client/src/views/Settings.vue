<template>
  <div>
    <div class="page-header">
      <h1>系统设置</h1>
      <p>管理邮箱服务、系统参数等配置</p>
    </div>

    <!-- SMTP 邮箱配置 -->
    <div class="content-card">
      <div class="card-header">
        <h3>
          <el-icon size="18" style="vertical-align: middle; margin-right: 6px"><Message /></el-icon>
          邮箱服务 (SMTP)
        </h3>
        <el-tag v-if="smtp.configured" type="success" effect="plain" size="small">已配置</el-tag>
        <el-tag v-else type="danger" effect="plain" size="small">未配置</el-tag>
      </div>

      <el-form
        :model="smtp"
        label-width="100px"
        style="max-width: 560px; margin-top: 16px"
        v-loading="loading"
      >
        <el-form-item label="SMTP 服务器">
          <el-input v-model="smtp.host" placeholder="如 smtp.qq.com / smtp.gmail.com">
            <template #prepend>
              <el-select v-model="smtpPreset" placeholder="快捷" style="width: 100px" @change="applyPreset">
                <el-option label="QQ 邮箱" value="qq" />
                <el-option label="163 邮箱" value="163" />
                <el-option label="Gmail" value="gmail" />
                <el-option label="Outlook" value="outlook" />
                <el-option label="阿里企业" value="aliwork" />
                <el-option label="自定义" value="" />
              </el-select>
            </template>
          </el-input>
        </el-form-item>

        <el-form-item label="端口">
          <el-input-number v-model.number="smtp.port" :min="1" :max="65535" style="width: 140px" />
          <el-checkbox v-model="smtp.secure" label="SSL/TLS" style="margin-left: 16px" true-value="true" false-value="false" />
        </el-form-item>

        <el-form-item label="账号">
          <el-input v-model="smtp.user" placeholder="发件邮箱地址" />
        </el-form-item>

        <el-form-item label="密码/授权码">
          <el-input v-model="smtp.pass" type="password" show-password placeholder="SMTP 密码或授权码（留空不修改）" />
        </el-form-item>

        <el-form-item label="发件人名称">
          <el-input v-model="smtp.from_name" placeholder="CertManager" />
        </el-form-item>

        <el-form-item>
          <el-button type="primary" @click="saveSmtp" :loading="saving">
            <el-icon><Check /></el-icon> 保存配置
          </el-button>
        </el-form-item>
      </el-form>

      <el-divider />

      <div style="max-width: 560px">
        <h4 style="margin: 0 0 12px; font-size: 14px; font-weight: 600">发送测试</h4>
        <div style="display: flex; gap: 8px">
          <el-input v-model="testEmail" placeholder="输入收件邮箱地址" style="flex: 1" />
          <el-button @click="sendTest" :loading="testing" :disabled="!smtp.configured && !justSaved">
            <el-icon><Promotion /></el-icon> 发送测试
          </el-button>
        </div>
      </div>
    </div>

    <!-- 推送服务配置 -->
    <div class="content-card">
      <div class="card-header">
        <h3>
          <el-icon size="18" style="vertical-align: middle; margin-right: 6px"><Bell /></el-icon>
          推送服务 (APNs)
        </h3>
        <el-tag :type="apns.sandbox ? 'warning' : 'success'" effect="plain" size="small">
          {{ apns.sandbox ? 'Sandbox' : 'Production' }}
        </el-tag>
      </div>

      <el-form label-width="110px" style="max-width: 600px; margin-top: 16px">
        <el-form-item label="推送环境">
          <el-radio-group v-model="apns.sandbox" @change="saveApns">
            <el-radio :value="true">Sandbox (开发)</el-radio>
            <el-radio :value="false">Production (生产)</el-radio>
          </el-radio-group>
          <div class="form-tip">Sandbox 用于开发测试，Production 用于正式上架的 App</div>
        </el-form-item>

        <el-form-item label="认证方式">
          <el-radio-group v-model="apns.authType" @change="saveApns">
            <el-radio value="p8">.p8 Key（Token）</el-radio>
            <el-radio value="p12">.p12 证书（Certificate）</el-radio>
          </el-radio-group>
        </el-form-item>
      </el-form>

      <el-divider />

      <!-- .p8 Key 说明 -->
      <div v-if="apns.authType === 'p8'" class="auth-mode-card">
        <div class="auth-mode-header p8">
          <span class="auth-mode-badge">.p8</span>
          <div>
            <h4>Token-Based Authentication</h4>
            <span>推荐方式，Team 级别通用</span>
          </div>
        </div>
        <div class="auth-mode-body">
          <div class="auth-mode-features">
            <div class="auth-feature">
              <el-icon color="#10B981"><CircleCheck /></el-icon>
              <span>一个 Key 通用所有 App，无需绑定 Bundle ID</span>
            </div>
            <div class="auth-feature">
              <el-icon color="#10B981"><CircleCheck /></el-icon>
              <span>不会过期（除非手动吊销）</span>
            </div>
            <div class="auth-feature">
              <el-icon color="#10B981"><CircleCheck /></el-icon>
              <span>Apple 官方推荐的新一代认证方式</span>
            </div>
          </div>
          <div class="auth-mode-steps">
            <p><strong>使用流程：</strong></p>
            <ol>
              <li>在「账号管理」中导入 .p8 Key（Apple Developer 后台需勾选 APNs 权限）</li>
              <li>或在「推送密钥」中单独管理推送专用的 .p8 Key</li>
              <li>前往「推送测试」→ 选择密钥 → 输入 Device Token 和 Bundle ID → 发送</li>
            </ol>
          </div>
        </div>
      </div>

      <!-- .p12 证书说明 -->
      <div v-else class="auth-mode-card">
        <div class="auth-mode-header p12">
          <span class="auth-mode-badge">.p12</span>
          <div>
            <h4>Certificate-Based Authentication</h4>
            <span>传统方式，绑定到具体 App</span>
          </div>
        </div>
        <div class="auth-mode-body">
          <div class="auth-mode-features">
            <div class="auth-feature">
              <el-icon color="#F59E0B"><WarningFilled /></el-icon>
              <span>每个 App 需要单独的推送证书（绑定 Bundle ID）</span>
            </div>
            <div class="auth-feature">
              <el-icon color="#F59E0B"><WarningFilled /></el-icon>
              <span>证书有效期 1 年，到期需要重新生成</span>
            </div>
            <div class="auth-feature">
              <el-icon color="#10B981"><CircleCheck /></el-icon>
              <span>兼容老旧系统和第三方推送服务</span>
            </div>
          </div>
          <div class="auth-mode-steps">
            <p><strong>使用流程：</strong></p>
            <ol>
              <li>在「证书管理」创建推送证书（Apple Push Notification service SSL）</li>
              <li>推送证书会绑定到指定的 Bundle ID</li>
              <li>前往「推送测试」→ 选择推送证书 → 输入 Device Token → 发送</li>
            </ol>
          </div>
        </div>
      </div>
    </div>

    <!-- 系统信息 -->
    <div class="content-card">
      <div class="card-header">
        <h3>
          <el-icon size="18" style="vertical-align: middle; margin-right: 6px"><InfoFilled /></el-icon>
          系统信息
        </h3>
      </div>
      <div style="margin-top: 12px">
        <el-descriptions :column="1" border size="small">
          <el-descriptions-item label="版本">CertVault v1.0.0</el-descriptions-item>
          <el-descriptions-item label="运行环境">Node.js</el-descriptions-item>
          <el-descriptions-item label="数据库">PostgreSQL</el-descriptions-item>
          <el-descriptions-item label="邮件服务">{{ smtp.configured ? `${smtp.host}:${smtp.port}` : '未配置' }}</el-descriptions-item>
          <el-descriptions-item label="推送环境">{{ apns.sandbox ? 'Sandbox (开发)' : 'Production (生产)' }}</el-descriptions-item>
          <el-descriptions-item label="推送认证">{{ apns.authType === 'p8' ? '.p8 Key (Token-Based)，Team 级别通用' : '.p12 证书 (Certificate-Based)，绑定具体 App' }}</el-descriptions-item>
        </el-descriptions>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { settingsApi } from '../api'

const PRESETS = {
  qq: { host: 'smtp.qq.com', port: 465, secure: 'true' },
  '163': { host: 'smtp.163.com', port: 465, secure: 'true' },
  gmail: { host: 'smtp.gmail.com', port: 587, secure: 'false' },
  outlook: { host: 'smtp.office365.com', port: 587, secure: 'false' },
  aliwork: { host: 'smtp.qiye.aliyun.com', port: 465, secure: 'true' },
}

const loading = ref(false)
const saving = ref(false)
const testing = ref(false)
const justSaved = ref(false)
const smtpPreset = ref('')
const testEmail = ref('')

const smtp = ref({
  host: '',
  port: 465,
  secure: 'true',
  user: '',
  pass: '',
  from_name: 'CertManager',
  configured: false,
})

const apns = ref({
  sandbox: (localStorage.getItem('apns_sandbox') ?? 'true') === 'true',
  authType: localStorage.getItem('apns_auth_type') || 'p8',
})

function applyPreset(key) {
  if (key && PRESETS[key]) {
    Object.assign(smtp.value, PRESETS[key])
  }
}

async function loadSmtp() {
  loading.value = true
  try {
    const res = await settingsApi.getSmtp()
    const d = res.data || res
    smtp.value.host = d.host || ''
    smtp.value.port = parseInt(d.port) || 465
    smtp.value.secure = d.secure || 'true'
    smtp.value.user = d.user || ''
    smtp.value.from_name = d.from_name || 'CertManager'
    smtp.value.configured = d.configured || false
    smtp.value.pass = ''
  } finally {
    loading.value = false
  }
}

async function saveSmtp() {
  if (!smtp.value.host || !smtp.value.user) {
    return ElMessage.warning('请填写 SMTP 服务器和账号')
  }
  saving.value = true
  try {
    await settingsApi.saveSmtp({
      host: smtp.value.host,
      port: smtp.value.port,
      secure: smtp.value.secure,
      user: smtp.value.user,
      pass: smtp.value.pass,
      from_name: smtp.value.from_name,
    })
    ElMessage.success('SMTP 配置已保存')
    smtp.value.configured = true
    justSaved.value = true
  } finally {
    saving.value = false
  }
}

async function sendTest() {
  if (!testEmail.value) return ElMessage.warning('请输入收件邮箱')
  testing.value = true
  try {
    await settingsApi.testSmtp(testEmail.value)
    ElMessage.success('测试邮件已发送，请检查收件箱')
  } finally {
    testing.value = false
  }
}

function saveApns() {
  localStorage.setItem('apns_sandbox', String(apns.value.sandbox))
  localStorage.setItem('apns_auth_type', apns.value.authType)
  ElMessage.success('推送配置已保存')
}

onMounted(loadSmtp)
</script>

<style scoped>
.el-divider {
  margin: 24px 0;
}
.form-tip {
  font-size: 12px;
  color: var(--nask-text-muted);
  margin-top: 4px;
  line-height: 1.4;
}

.auth-mode-card {
  max-width: 600px;
  border-radius: 12px;
  border: 1px solid var(--nask-border);
  overflow: hidden;
}

.auth-mode-header {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 16px 20px;
}

.auth-mode-header.p8 {
  background: linear-gradient(135deg, rgba(16, 185, 129, 0.08), rgba(5, 150, 105, 0.04));
}

.auth-mode-header.p12 {
  background: linear-gradient(135deg, rgba(245, 158, 11, 0.08), rgba(217, 119, 6, 0.04));
}

.auth-mode-badge {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 44px;
  height: 44px;
  border-radius: 10px;
  font-size: 13px;
  font-weight: 700;
  flex-shrink: 0;
  font-family: 'SF Mono', Monaco, Menlo, monospace;
}

.p8 .auth-mode-badge {
  background: rgba(16, 185, 129, 0.15);
  color: #059669;
}

.p12 .auth-mode-badge {
  background: rgba(245, 158, 11, 0.15);
  color: #D97706;
}

.auth-mode-header h4 {
  margin: 0 0 2px;
  font-size: 14px;
  font-weight: 700;
  color: var(--nask-text);
}

.auth-mode-header span {
  font-size: 12px;
  color: var(--nask-text-secondary);
}

.auth-mode-body {
  padding: 16px 20px 20px;
}

.auth-mode-features {
  display: flex;
  flex-direction: column;
  gap: 8px;
  margin-bottom: 16px;
}

.auth-feature {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 13px;
  color: var(--nask-text);
}

.auth-mode-steps {
  font-size: 13px;
  color: var(--nask-text-secondary);
  line-height: 1.8;
}

.auth-mode-steps p {
  margin: 0 0 6px;
  color: var(--nask-text);
}

.auth-mode-steps ol {
  padding-left: 18px;
  margin: 0;
}
</style>
