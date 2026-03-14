<template>
  <div v-if="$route.meta.public">
    <router-view />
  </div>
  <div v-else class="app-layout">
    <div class="sidebar-overlay" :class="{ open: sidebarOpen }" @click="sidebarOpen = false"></div>

    <!-- ========== SIDEBAR ========== -->
    <aside class="sidebar" :class="{ open: sidebarOpen }">
      <div class="sidebar-brand">
        <div class="sidebar-brand-icon">
          <img src="./assets/app-icon.png" alt="CertVault">
        </div>
        <div class="sidebar-brand-text">
          <h2>CertVault</h2>
          <p>Workspace</p>
        </div>
        <button class="sidebar-close-btn" @click="sidebarOpen = false">
          <HIcon name="close" :size="18" />
        </button>
      </div>

      <nav class="sidebar-nav">
        <div class="nav-group">
          <router-link to="/" class="nav-item" :class="{ active: $route.path === '/' }" @click="sidebarOpen = false">
            <HIcon name="category" /> 仪表盘
          </router-link>
        </div>

        <div class="nav-group" v-if="userInfo.role === 'superadmin'">
          <div class="nav-group-label">管理</div>
          <router-link to="/users" class="nav-item" active-class="active" @click="sidebarOpen = false">
            <HIcon name="group-1" /> 用户管理
          </router-link>
        </div>

        <div class="nav-group">
          <div class="nav-group-label">核心功能</div>
          <router-link to="/accounts" class="nav-item" active-class="active" @click="sidebarOpen = false">
            <HIcon name="profile-1" /> 账号管理
          </router-link>
          <router-link to="/devices" class="nav-item" active-class="active" @click="sidebarOpen = false">
            <HIcon name="display-1" /> 设备管理
          </router-link>
          <router-link to="/certificates" class="nav-item" active-class="active" @click="sidebarOpen = false">
            <HIcon name="password-1" /> 证书管理
          </router-link>
          <router-link to="/profiles" class="nav-item" active-class="active" @click="sidebarOpen = false">
            <HIcon name="document-align-left-1" /> 描述文件
          </router-link>
          <router-link to="/capabilities" class="nav-item" active-class="active" @click="sidebarOpen = false">
            <HIcon name="lock-1" /> 权限管理
          </router-link>
        </div>

        <div class="nav-group">
          <div class="nav-group-label">App Store Connect</div>
          <router-link to="/apps" class="nav-item" active-class="active" @click="sidebarOpen = false">
            <HIcon name="category" /> 应用管理
          </router-link>
          <router-link to="/testflight" class="nav-item" active-class="active" @click="sidebarOpen = false">
            <HIcon name="send-1" /> TestFlight
          </router-link>
          <router-link to="/appstore" class="nav-item" active-class="active" @click="sidebarOpen = false">
            <HIcon name="document-align-left-1" /> App Store 版本
          </router-link>
        </div>

        <div class="nav-group">
          <div class="nav-group-label">工具</div>
          <router-link to="/cert-check" class="nav-item" active-class="active" @click="sidebarOpen = false">
            <HIcon name="shield-tick" /> 证书检查
          </router-link>
          <router-link to="/get-udid" class="nav-item" active-class="active" @click="sidebarOpen = false">
            <HIcon name="scan-1" /> 获取 UDID
          </router-link>
          <router-link to="/healthcheck" class="nav-item" active-class="active" @click="sidebarOpen = false">
            <HIcon name="tick-circle" /> 健康检查
          </router-link>
        </div>

        <div class="nav-group" v-if="userInfo.role === 'superadmin'">
          <div class="nav-group-label">分发</div>
          <router-link to="/ipa" class="nav-item" active-class="active" @click="sidebarOpen = false">
            <HIcon name="download" /> IPA 管理
          </router-link>
        </div>

        <div class="nav-group">
          <div class="nav-group-label">推送</div>
          <router-link to="/push-settings" class="nav-item" active-class="active" @click="sidebarOpen = false">
            <HIcon name="setting" /> 推送设置
          </router-link>
          <router-link to="/push-keys" class="nav-item" active-class="active" @click="sidebarOpen = false">
            <HIcon name="notification-1" /> 推送密钥
          </router-link>
          <router-link to="/push-devices" class="nav-item" active-class="active" @click="sidebarOpen = false">
            <HIcon name="display-1" /> 设备 Token
          </router-link>
          <router-link to="/push-broadcast" class="nav-item" active-class="active" @click="sidebarOpen = false">
            <HIcon name="send-1" /> 群发推送
          </router-link>
          <router-link to="/push" class="nav-item" active-class="active" @click="sidebarOpen = false">
            <HIcon name="scan-1" /> 推送测试
          </router-link>
          <router-link to="/push-history" class="nav-item" active-class="active" @click="sidebarOpen = false">
            <HIcon name="document-align-left-1" /> 推送历史
          </router-link>
          <router-link to="/push-scheduled" class="nav-item" active-class="active" @click="sidebarOpen = false">
            <HIcon name="time-circle-1" /> 定时推送
          </router-link>
        </div>
      </nav>

      <!-- Sidebar bottom -->
      <div class="sidebar-bottom-items">
        <div class="sidebar-theme-toggle" @click="toggleDarkMode">
          <HIcon name="moon" />
          <span>Dark Mode</span>
          <el-switch
            :model-value="isDark"
            size="small"
            style="margin-left: auto; pointer-events: none"
          />
        </div>
        <router-link v-if="userInfo.role === 'superadmin'" to="/settings" class="nav-item" active-class="active" @click="sidebarOpen = false">
          <HIcon name="setting" /> 系统设置
        </router-link>
        <div class="nav-item" @click="showChangePwd = true">
          <HIcon name="lock-1" /> 修改密码
        </div>
        <div class="nav-item" style="color: var(--nask-red)" @click="handleLogout">
          <HIcon name="logout" /> 退出登录
        </div>
      </div>

    </aside>

    <!-- ========== MAIN ========== -->
    <main class="main-content">
      <header class="main-header">
        <div style="display: flex; align-items: center; gap: 12px">
          <button class="mobile-menu-btn" @click="sidebarOpen = true">
            <HIcon name="menu-hamburger" :size="22" />
          </button>
          <div>
            <div class="main-header-title">{{ $route.meta.title || 'CertVault' }}</div>
            <div class="main-header-sub" v-if="store.currentAccount">{{ store.currentAccount.name }}</div>
          </div>
        </div>
        <div class="navbar-right">
          <el-select
            v-model="store.currentAccountId"
            placeholder="选择账号"
            size="small"
            class="navbar-account-select"
            @change="store.setCurrentAccount"
            v-if="store.accounts.length > 1"
          >
            <el-option
              v-for="acc in store.accounts"
              :key="acc.id"
              :label="acc.name"
              :value="acc.id"
            />
          </el-select>
          <div class="navbar-user" @click="showUserMenu = !showUserMenu">
            <div class="navbar-user-avatar">{{ avatarChar }}</div>
            <div class="navbar-user-info">
              <div class="navbar-user-name">{{ userInfo.username || '用户' }}</div>
              <div class="navbar-user-email">{{ roleLabel }}</div>
            </div>
            <HIcon name="down-1" :size="12" style="color: var(--nask-text-secondary)" />
          </div>
        </div>
      </header>

      <div class="main-body">
        <router-view />
      </div>
    </main>

    <!-- Change password dialog -->
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
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { ElMessage } from 'element-plus'
import { useAppStore } from './stores/app'
import { authApi } from './api'
import HIcon from './components/HIcon.vue'

const router = useRouter()
const route = useRoute()
const store = useAppStore()
const showChangePwd = ref(false)
const changingPwd = ref(false)
const sidebarOpen = ref(false)
const showUserMenu = ref(false)
const pwdForm = ref({ old_password: '', new_password: '' })

const isDark = ref(localStorage.getItem('theme') === 'dark')

function toggleDarkMode() {
  isDark.value = !isDark.value
  if (isDark.value) {
    document.documentElement.classList.add('dark')
    localStorage.setItem('theme', 'dark')
  } else {
    document.documentElement.classList.remove('dark')
    localStorage.setItem('theme', 'light')
  }
}

onMounted(() => {
  if (localStorage.getItem('theme') === 'dark') {
    document.documentElement.classList.add('dark')
    isDark.value = true
  }
})

const userInfo = ref(JSON.parse(localStorage.getItem('auth_user') || '{}'))

const avatarChar = computed(() => {
  const name = userInfo.value.username || ''
  return name.charAt(0).toUpperCase() || 'U'
})

const roleLabel = computed(() => {
  return userInfo.value.role === 'superadmin' ? '超级管理员' : '普通用户'
})

watch(() => route.path, () => {
  sidebarOpen.value = false
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
