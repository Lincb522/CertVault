<template>
  <div class="auth-page">
    <div class="auth-card">
      <div class="auth-header">
        <div class="auth-logo">
          <img src="../assets/app-icon.png" alt="CertVault" style="width:52px;height:52px;border-radius:22.37%">
        </div>
        <h1>创建账号</h1>
        <p>注册后即可使用 CertVault</p>
      </div>

      <el-form :model="form" @submit.prevent="handleRegister" class="auth-form">
        <el-form-item>
          <el-input v-model="form.username" size="large" placeholder="用户名（至少 3 个字符）" prefix-icon="User" autofocus />
        </el-form-item>
        <el-form-item>
          <el-input v-model="form.email" size="large" placeholder="邮箱地址" prefix-icon="Message" type="email" />
        </el-form-item>
        <el-form-item>
          <div style="display: flex; gap: 8px; width: 100%">
            <el-input v-model="form.code" size="large" placeholder="邮箱验证码" prefix-icon="Key" style="flex: 1" />
            <el-button size="large" @click="handleSendCode" :loading="sendingCode" :disabled="countdown > 0" class="code-btn">
              {{ countdown > 0 ? `${countdown}s` : '获取验证码' }}
            </el-button>
          </div>
        </el-form-item>
        <el-form-item>
          <el-input v-model="form.password" size="large" type="password" placeholder="密码（至少 6 位）" prefix-icon="Lock" show-password />
        </el-form-item>
        <el-form-item>
          <el-input v-model="form.confirmPassword" size="large" type="password" placeholder="确认密码" prefix-icon="Lock" show-password @keyup.enter="handleRegister" />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" size="large" class="auth-btn" @click="handleRegister" :loading="loading">注  册</el-button>
        </el-form-item>
      </el-form>

      <div class="auth-footer">
        已有账号？<router-link to="/login" class="auth-link">去登录</router-link>
      </div>
    </div>
    <div class="auth-copyright">CertVault &copy; {{ new Date().getFullYear() }}</div>
  </div>
</template>

<script setup>
import { ref, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { authApi } from '../api'

const router = useRouter()
const loading = ref(false)
const sendingCode = ref(false)
const countdown = ref(0)
let timer = null
const form = ref({ username: '', email: '', code: '', password: '', confirmPassword: '' })

function startCountdown() {
  countdown.value = 60
  timer = setInterval(() => {
    countdown.value--
    if (countdown.value <= 0) clearInterval(timer)
  }, 1000)
}

async function handleSendCode() {
  if (!form.value.email) return ElMessage.warning('请先输入邮箱地址')
  sendingCode.value = true
  try {
    await authApi.sendCode(form.value.email, 'register')
    ElMessage.success('验证码已发送，请查收邮箱')
    startCountdown()
  } catch {} finally { sendingCode.value = false }
}

async function handleRegister() {
  if (!form.value.username || !form.value.password || !form.value.email || !form.value.code) return ElMessage.warning('请完整填写所有信息')
  if (form.value.password !== form.value.confirmPassword) return ElMessage.warning('两次密码输入不一致')
  loading.value = true
  try {
    const res = await authApi.register({
      username: form.value.username, email: form.value.email, code: form.value.code, password: form.value.password,
    })
    localStorage.setItem('auth_token', res.data.token)
    localStorage.setItem('auth_user', JSON.stringify({ username: res.data.username, email: res.data.email, role: res.data.role }))
    ElMessage.success('注册成功')
    router.push('/')
  } catch {} finally { loading.value = false }
}

onUnmounted(() => { if (timer) clearInterval(timer) })
</script>

<style scoped>
.auth-page {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  background: var(--nask-bg);
  position: relative;
}

.auth-card {
  width: 420px;
  max-width: calc(100vw - 32px);
  background: var(--nask-surface);
  border: 1px solid var(--nask-border);
  border-radius: 24px;
  padding: 40px;
  box-shadow: var(--nask-shadow-lg);
}

.auth-header { text-align: center; margin-bottom: 32px; }
.auth-logo { margin: 0 auto 16px; width: 64px; height: 64px; display: flex; align-items: center; justify-content: center; }
.auth-header h1 { font-size: 24px; font-weight: 700; color: var(--nask-text); }
.auth-header p { color: var(--nask-text-secondary); font-size: 14px; margin-top: 6px; }

.auth-btn {
  width: 100%;
  height: 48px;
  font-size: 15px;
  font-weight: 600;
  letter-spacing: 2px;
  border-radius: var(--nask-radius-pill) !important;
  background: var(--nask-blue) !important;
  border: none !important;
}

.auth-btn:hover { background: #0560cc !important; }

.code-btn { min-width: 110px; border-radius: var(--nask-radius-sm) !important; }

.auth-footer { text-align: center; margin-top: 20px; font-size: 14px; color: var(--nask-text-secondary); }
.auth-link { color: var(--nask-blue); text-decoration: none; font-weight: 600; margin-left: 4px; }
.auth-link:hover { color: var(--nask-orange); }
.auth-copyright { position: absolute; bottom: 24px; color: var(--nask-text-muted); font-size: 12px; }

@media (max-width: 480px) {
  .auth-card { padding: 28px 20px; border-radius: 20px; }
  .code-btn { min-width: 90px; font-size: 13px; }
}
</style>
