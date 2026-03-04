<template>
  <div v-if="$route.meta.public">
    <router-view />
  </div>
  <div v-else class="app-layout">
    <aside class="sidebar">
      <div class="sidebar-brand">
        <div class="sidebar-brand-icon">
          <el-icon><Key /></el-icon>
        </div>
        <div class="sidebar-brand-text">
          <h2>CertVault</h2>
          <p>Apple 证书管理工具</p>
        </div>
      </div>

      <nav class="sidebar-nav">
        <div class="nav-group">
          <div class="nav-group-label">概览</div>
          <router-link to="/" class="nav-item" active-class="active" exact-active-class="active" :class="{ active: $route.path === '/' }">
            <el-icon><Odometer /></el-icon> 仪表盘
          </router-link>
        </div>

        <div class="nav-group" v-if="userInfo.role === 'superadmin'">
          <div class="nav-group-label">管理</div>
          <router-link to="/users" class="nav-item" active-class="active">
            <el-icon><UserFilled /></el-icon> 用户管理
          </router-link>
        </div>

        <div class="nav-group">
          <div class="nav-group-label">核心功能</div>
          <router-link to="/accounts" class="nav-item" active-class="active">
            <el-icon><User /></el-icon> 账号管理
          </router-link>
          <router-link to="/devices" class="nav-item" active-class="active">
            <el-icon><Iphone /></el-icon> 设备管理
          </router-link>
          <router-link to="/certificates" class="nav-item" active-class="active">
            <el-icon><Key /></el-icon> 证书管理
          </router-link>
          <router-link to="/profiles" class="nav-item" active-class="active">
            <el-icon><Document /></el-icon> 描述文件
          </router-link>
          <router-link to="/capabilities" class="nav-item" active-class="active">
            <el-icon><Lock /></el-icon> 权限管理
          </router-link>
        </div>

        <div class="nav-group">
          <div class="nav-group-label">开发工具</div>
          <router-link to="/get-udid" class="nav-item" active-class="active">
            <el-icon><Monitor /></el-icon> 获取 UDID
          </router-link>
          <router-link to="/healthcheck" class="nav-item" active-class="active">
            <el-icon><CircleCheck /></el-icon> 健康检查
          </router-link>
        </div>

        <div class="nav-group">
          <div class="nav-group-label">推送服务</div>
          <router-link to="/push-keys" class="nav-item" active-class="active">
            <el-icon><Bell /></el-icon> 推送密钥
          </router-link>
          <router-link to="/push" class="nav-item" active-class="active">
            <el-icon><Promotion /></el-icon> 推送测试
          </router-link>
        </div>
      </nav>

      <div class="sidebar-footer">
        <el-select
          v-model="store.currentAccountId"
          placeholder="选择账号"
          size="small"
          style="width: 100%; margin-bottom: 10px"
          @change="store.setCurrentAccount"
        >
          <el-option
            v-for="acc in store.accounts"
            :key="acc.id"
            :label="acc.name"
            :value="acc.id"
          />
        </el-select>

        <div class="sidebar-user">
          <div class="sidebar-user-avatar">{{ avatarChar }}</div>
          <div class="sidebar-user-info">
            <div class="sidebar-user-name">{{ userInfo.username || '用户' }}</div>
            <div class="sidebar-user-role">{{ roleLabel }}</div>
          </div>
        </div>

        <div style="display: flex; gap: 6px">
          <el-button size="small" style="flex:1" @click="showChangePwd = true">
            <el-icon><Lock /></el-icon> 改密码
          </el-button>
          <el-button size="small" type="danger" style="flex:1" @click="handleLogout">
            <el-icon><SwitchButton /></el-icon> 退出
          </el-button>
        </div>
      </div>
    </aside>

    <main class="main-content">
      <header class="main-header">
        <div>
          <div class="main-header-title">{{ $route.meta.title || 'CertVault' }}</div>
          <div class="main-header-sub" v-if="store.currentAccount">
            {{ store.currentAccount.name }}
          </div>
        </div>
        <div style="display: flex; align-items: center; gap: 12px">
          <el-tag v-if="store.accounts.length" size="small" type="info" effect="plain">
            {{ store.accounts.length }} 个账号
          </el-tag>
        </div>
      </header>
      <div class="main-body">
        <router-view />
      </div>
    </main>

    <el-dialog v-model="showChangePwd" title="修改密码" width="420px" destroy-on-close>
      <el-form :model="pwdForm" label-width="80px">
        <el-form-item label="旧密码" required>
          <el-input v-model="pwdForm.old_password" type="password" show-password />
        </el-form-item>
        <el-form-item label="新密码" required>
          <el-input v-model="pwdForm.new_password" type="password" show-password placeholder="至少 6 位" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showChangePwd = false">取消</el-button>
        <el-button type="primary" @click="changePassword" :loading="changingPwd">确认修改</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { useAppStore } from './stores/app'
import { authApi } from './api'

const router = useRouter()
const store = useAppStore()
const showChangePwd = ref(false)
const changingPwd = ref(false)
const pwdForm = ref({ old_password: '', new_password: '' })

const userInfo = ref(JSON.parse(localStorage.getItem('auth_user') || '{}'))

const avatarChar = computed(() => {
  const name = userInfo.value.username || ''
  return name.charAt(0).toUpperCase() || 'U'
})

const roleLabel = computed(() => {
  return userInfo.value.role === 'superadmin' ? '超级管理员' : '普通用户'
})

async function handleLogout() {
  try { await authApi.logout() } catch {}
  localStorage.removeItem('auth_token')
  localStorage.removeItem('auth_user')
  userInfo.value = {}
  router.push('/login')
}

async function changePassword() {
  if (!pwdForm.value.old_password || !pwdForm.value.new_password) {
    return ElMessage.warning('请填写旧密码和新密码')
  }
  changingPwd.value = true
  try {
    await authApi.changePassword(pwdForm.value)
    ElMessage.success('密码修改成功')
    showChangePwd.value = false
    pwdForm.value = { old_password: '', new_password: '' }
  } finally {
    changingPwd.value = false
  }
}

onMounted(() => {
  const token = localStorage.getItem('auth_token')
  if (token) store.fetchAccounts()
})
</script>
