<template>
  <div class="auth-page">
    <div class="auth-card">
      <div class="auth-header">
        <div class="auth-logo">
          <el-icon><Key /></el-icon>
        </div>
        <h1>CertVault</h1>
        <p>Apple 开发者证书管理工具</p>
      </div>

      <el-form :model="form" @submit.prevent="handleLogin" class="auth-form">
        <el-form-item>
          <el-input
            v-model="form.username"
            size="large"
            placeholder="用户名 / 邮箱"
            prefix-icon="User"
            autofocus
          />
        </el-form-item>
        <el-form-item>
          <el-input
            v-model="form.password"
            size="large"
            type="password"
            placeholder="密码"
            prefix-icon="Lock"
            show-password
            @keyup.enter="handleLogin"
          />
        </el-form-item>
        <el-form-item>
          <el-button
            type="primary"
            size="large"
            class="auth-btn"
            @click="handleLogin"
            :loading="loading"
          >
            登  录
          </el-button>
        </el-form-item>
      </el-form>

      <div class="auth-footer">
        还没有账号？
        <router-link to="/register" class="auth-link">立即注册</router-link>
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
  if (!form.value.username || !form.value.password) {
    return ElMessage.warning('请输入用户名和密码')
  }

  loading.value = true
  try {
    const res = await authApi.login(form.value)
    localStorage.setItem('auth_token', res.data.token)
    localStorage.setItem('auth_user', JSON.stringify({ username: res.data.username, email: res.data.email, role: res.data.role }))
    ElMessage.success('登录成功')
    router.push('/')
  } catch {
    // handled by interceptor
  } finally {
    loading.value = false
  }
}
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
  background: radial-gradient(circle, rgba(64,158,255,0.12) 0%, transparent 70%);
  top: -200px;
  right: -100px;
}

.auth-page::after {
  content: '';
  position: absolute;
  width: 500px;
  height: 500px;
  border-radius: 50%;
  background: radial-gradient(circle, rgba(144,106,252,0.1) 0%, transparent 70%);
  bottom: -200px;
  left: -100px;
}

.auth-card {
  width: 420px;
  max-width: calc(100vw - 32px);
  background: rgba(255,255,255,0.95);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  border-radius: 20px;
  padding: 44px 40px 36px;
  box-shadow: 0 20px 60px rgba(0,0,0,0.25), 0 0 0 1px rgba(255,255,255,0.1);
  position: relative;
  z-index: 1;
}

.auth-header {
  text-align: center;
  margin-bottom: 36px;
}

.auth-logo {
  width: 60px;
  height: 60px;
  border-radius: 16px;
  background: linear-gradient(135deg, #409EFF, #906AFC);
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 0 auto 16px;
  font-size: 28px;
  color: #fff;
  box-shadow: 0 8px 24px rgba(64,158,255,0.3);
}

.auth-header h1 {
  font-size: 26px;
  font-weight: 750;
  color: #1a1d2e;
  letter-spacing: 0.5px;
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

@media (max-width: 480px) {
  .auth-card {
    padding: 32px 24px 28px;
    border-radius: 16px;
  }
}
</style>
