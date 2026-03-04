<template>
  <div class="auth-page">
    <div class="auth-card">
      <div class="auth-header">
        <div class="auth-logo">
          <el-icon><User /></el-icon>
        </div>
        <h1>创建账号</h1>
        <p>注册后即可使用 CertVault</p>
      </div>

      <el-form :model="form" @submit.prevent="handleRegister" class="auth-form">
        <el-form-item>
          <el-input
            v-model="form.username"
            size="large"
            placeholder="用户名（至少 3 个字符）"
            prefix-icon="User"
            autofocus
          />
        </el-form-item>
        <el-form-item>
          <el-input
            v-model="form.email"
            size="large"
            placeholder="邮箱地址"
            prefix-icon="Message"
            type="email"
          />
        </el-form-item>
        <el-form-item>
          <div style="display: flex; gap: 8px; width: 100%">
            <el-input
              v-model="form.code"
              size="large"
              placeholder="邮箱验证码"
              prefix-icon="Key"
              style="flex: 1"
            />
            <el-button
              size="large"
              @click="handleSendCode"
              :loading="sendingCode"
              :disabled="countdown > 0"
              class="code-btn"
            >
              {{ countdown > 0 ? `${countdown}s` : '获取验证码' }}
            </el-button>
          </div>
        </el-form-item>
        <el-form-item>
          <el-input
            v-model="form.password"
            size="large"
            type="password"
            placeholder="密码（至少 6 位）"
            prefix-icon="Lock"
            show-password
          />
        </el-form-item>
        <el-form-item>
          <el-input
            v-model="form.confirmPassword"
            size="large"
            type="password"
            placeholder="确认密码"
            prefix-icon="Lock"
            show-password
            @keyup.enter="handleRegister"
          />
        </el-form-item>
        <el-form-item>
          <el-button
            type="primary"
            size="large"
            class="auth-btn"
            @click="handleRegister"
            :loading="loading"
          >
            注  册
          </el-button>
        </el-form-item>
      </el-form>

      <div class="auth-footer">
        已有账号？
        <router-link to="/login" class="auth-link">去登录</router-link>
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
  if (!form.value.email) {
    return ElMessage.warning('请先输入邮箱地址')
  }
  sendingCode.value = true
  try {
    await authApi.sendCode(form.value.email, 'register')
    ElMessage.success('验证码已发送，请查收邮箱')
    startCountdown()
  } catch {
    // handled by interceptor
  } finally {
    sendingCode.value = false
  }
}

async function handleRegister() {
  if (!form.value.username || !form.value.password || !form.value.email || !form.value.code) {
    return ElMessage.warning('请完整填写所有信息')
  }
  if (form.value.password !== form.value.confirmPassword) {
    return ElMessage.warning('两次密码输入不一致')
  }

  loading.value = true
  try {
    const res = await authApi.register({
      username: form.value.username,
      email: form.value.email,
      code: form.value.code,
      password: form.value.password,
    })
    localStorage.setItem('auth_token', res.data.token)
    localStorage.setItem('auth_user', JSON.stringify({
      username: res.data.username,
      email: res.data.email,
      role: res.data.role,
    }))
    ElMessage.success('注册成功')
    router.push('/')
  } catch {
    // handled by interceptor
  } finally {
    loading.value = false
  }
}

onUnmounted(() => {
  if (timer) clearInterval(timer)
})
</script>

<style scoped>
.auth-page {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #16172b 0%, #1e2040 30%, #2a2d5a 60%, #16172b 100%);
  position: relative;
  overflow: hidden;
}

.auth-page::before {
  content: '';
  position: absolute;
  width: 600px;
  height: 600px;
  border-radius: 50%;
  background: radial-gradient(circle, rgba(144,106,252,0.12) 0%, transparent 70%);
  top: -200px;
  left: -100px;
}

.auth-page::after {
  content: '';
  position: absolute;
  width: 500px;
  height: 500px;
  border-radius: 50%;
  background: radial-gradient(circle, rgba(64,158,255,0.1) 0%, transparent 70%);
  bottom: -200px;
  right: -100px;
}

.auth-card {
  width: 420px;
  background: rgba(255,255,255,0.95);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  border-radius: 20px;
  padding: 40px;
  box-shadow: 0 20px 60px rgba(0,0,0,0.25), 0 0 0 1px rgba(255,255,255,0.1);
  position: relative;
  z-index: 1;
}

.auth-header {
  text-align: center;
  margin-bottom: 32px;
}

.auth-logo {
  width: 56px;
  height: 56px;
  border-radius: 16px;
  background: linear-gradient(135deg, #906AFC, #409EFF);
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 0 auto 16px;
  font-size: 26px;
  color: #fff;
  box-shadow: 0 8px 24px rgba(144,106,252,0.3);
}

.auth-header h1 {
  font-size: 24px;
  font-weight: 750;
  color: #1a1d2e;
}

.auth-header p {
  color: #6b7280;
  font-size: 14px;
  margin-top: 6px;
}

.auth-form {
  margin-top: 8px;
}

.auth-btn {
  width: 100%;
  height: 46px;
  font-size: 15px;
  font-weight: 600;
  letter-spacing: 2px;
  border-radius: 12px !important;
  background: linear-gradient(135deg, #409EFF, #906AFC) !important;
  border: none !important;
}

.auth-btn:hover {
  background: linear-gradient(135deg, #3a8ee6, #7c5ce7) !important;
  box-shadow: 0 6px 20px rgba(64,158,255,0.35);
}

.code-btn {
  min-width: 110px;
  border-radius: 8px !important;
}

.auth-footer {
  text-align: center;
  margin-top: 20px;
  font-size: 14px;
  color: #6b7280;
}

.auth-link {
  color: #409EFF;
  text-decoration: none;
  font-weight: 550;
  margin-left: 4px;
}

.auth-link:hover {
  color: #906AFC;
}

.auth-copyright {
  position: absolute;
  bottom: 24px;
  color: rgba(255,255,255,0.25);
  font-size: 12px;
  z-index: 1;
}
</style>
