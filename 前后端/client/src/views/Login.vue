<template>
  <div class="auth-page">
    <div class="auth-card">
      <div class="auth-header">
        <div class="auth-logo">
          <img src="../assets/app-icon.png" alt="CertVault" style="width:52px;height:52px;border-radius:22.37%">
        </div>
        <h1>CertVault</h1>
        <p>Apple 开发者证书管理工具</p>
      </div>

      <el-form :model="form" @submit.prevent="handleLogin" class="auth-form">
        <el-form-item>
          <el-input v-model="form.username" size="large" placeholder="用户名 / 邮箱" prefix-icon="User" autofocus />
        </el-form-item>
        <el-form-item>
          <el-input v-model="form.password" size="large" type="password" placeholder="密码" prefix-icon="Lock" show-password @keyup.enter="handleLogin" />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" size="large" class="auth-btn" @click="handleLogin" :loading="loading">登  录</el-button>
        </el-form-item>
      </el-form>

      <div class="auth-footer">
        还没有账号？<router-link to="/register" class="auth-link">立即注册</router-link>
      </div>
    </div>
    <div class="auth-copyright">CertVault &copy; {{ new Date().getFullYear() }}</div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { authApi } from '../api'

const router = useRouter()
const loading = ref(false)
const form = ref({ username: '', password: '' })

async function handleLogin() {
  if (!form.value.username || !form.value.password) return ElMessage.warning('请输入用户名和密码')
  loading.value = true
  try {
    const res = await authApi.login(form.value)
    localStorage.setItem('auth_token', res.data.token)
    localStorage.setItem('auth_user', JSON.stringify({ username: res.data.username, email: res.data.email, role: res.data.role }))
    ElMessage.success('登录成功')
    router.push('/')
  } catch {} finally { loading.value = false }
}
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
  padding: 44px 40px 36px;
  box-shadow: var(--nask-shadow-lg);
}

.auth-header {
  text-align: center;
  margin-bottom: 36px;
}

.auth-logo {
  margin: 0 auto 16px;
  width: 64px;
  height: 64px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.auth-header h1 {
  font-size: 26px;
  font-weight: 700;
  color: var(--nask-text);
}

.auth-header p {
  color: var(--nask-text-secondary);
  font-size: 14px;
  margin-top: 6px;
}

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

.auth-btn:hover {
  background: #0560cc !important;
  box-shadow: 0 6px 20px rgba(6,109,230,0.25);
}

.auth-footer {
  text-align: center;
  margin-top: 20px;
  font-size: 14px;
  color: var(--nask-text-secondary);
}

.auth-link {
  color: var(--nask-blue);
  text-decoration: none;
  font-weight: 600;
  margin-left: 4px;
}

.auth-link:hover { color: var(--nask-orange); }

.auth-copyright {
  position: absolute;
  bottom: 24px;
  color: var(--nask-text-muted);
  font-size: 12px;
}

@media (max-width: 480px) {
  .auth-card { padding: 32px 24px 28px; border-radius: 20px; }
}
</style>
