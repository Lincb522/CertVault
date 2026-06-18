<template>
  <div>
    <div class="welcome-banner">
      <h2>Welcome, {{ username }}! 👋</h2>
      <p>Apple 开发者证书一站式管理平台 — 轻松管理证书、设备、描述文件和推送配置</p>
    </div>

    <div class="stat-grid">
      <div class="stat-card">
        <div class="stat-icon blue"><HIcon name="profile-1" :size="22" /></div>
        <div class="stat-info">
          <div class="stat-value">{{ stats.accounts }}</div>
          <div class="stat-label">开发者账号</div>
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-icon green"><HIcon name="display-1" :size="22" /></div>
        <div class="stat-info">
          <div class="stat-value">{{ stats.devices }}</div>
          <div class="stat-label">已注册设备</div>
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-icon orange"><HIcon name="password-1" :size="22" /></div>
        <div class="stat-info">
          <div class="stat-value">{{ stats.certificates }}</div>
          <div class="stat-label">证书总数</div>
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-icon purple"><HIcon name="document-align-left-1" :size="22" /></div>
        <div class="stat-info">
          <div class="stat-value">{{ stats.profiles }}</div>
          <div class="stat-label">描述文件</div>
        </div>
      </div>
    </div>

    <div class="content-card" style="margin-bottom: 24px">
      <div class="card-header">
        <h3>快速操作</h3>
      </div>
      <div class="quick-grid">
        <div class="quick-card" @click="$router.push('/certificates')">
          <div class="q-icon stat-icon blue"><HIcon name="password-1" :size="20" /></div>
          <div class="q-label">创建证书</div>
        </div>
        <div class="quick-card" @click="$router.push('/devices')">
          <div class="q-icon stat-icon green"><HIcon name="display-1" :size="20" /></div>
          <div class="q-label">添加设备</div>
        </div>
        <div class="quick-card" @click="$router.push('/profiles')">
          <div class="q-icon stat-icon orange"><HIcon name="document-align-left-1" :size="20" /></div>
          <div class="q-label">生成描述文件</div>
        </div>
        <div class="quick-card" @click="$router.push('/accounts')">
          <div class="q-icon stat-icon purple"><HIcon name="profile-1" :size="20" /></div>
          <div class="q-label">管理账号</div>
        </div>
        <div class="quick-card" @click="$router.push('/get-udid')">
          <div class="q-icon stat-icon cyan"><HIcon name="scan-1" :size="20" /></div>
          <div class="q-label">获取 UDID</div>
        </div>
        <div class="quick-card" @click="$router.push('/healthcheck')">
          <div class="q-icon stat-icon pink"><HIcon name="tick-circle" :size="20" /></div>
          <div class="q-label">健康检查</div>
        </div>
      </div>
    </div>

    <el-row :gutter="20">
      <el-col :xs="24" :sm="12">
        <div class="content-card">
          <div class="card-header">
            <h3>最近证书</h3>
            <router-link to="/certificates" style="color: var(--nask-orange); font-size: 14px; font-weight: 600; text-decoration: none">查看全部</router-link>
          </div>
          <el-table :data="recentCerts" size="small" empty-text="暂无证书">
            <el-table-column prop="name" label="名称" show-overflow-tooltip />
            <el-table-column prop="type" label="类型" width="160" />
            <el-table-column prop="expires_at" label="过期" width="100">
              <template #default="{ row }">
                {{ row.expires_at ? new Date(row.expires_at).toLocaleDateString() : '-' }}
              </template>
            </el-table-column>
          </el-table>
        </div>
      </el-col>
      <el-col :xs="24" :sm="12">
        <div class="content-card">
          <div class="card-header">
            <h3>使用指南</h3>
          </div>
          <div class="guide-list">
            <div class="guide-item" v-for="(step, i) in guideSteps" :key="i">
              <div class="guide-num" :style="{ background: step.color }">{{ i + 1 }}</div>
              <span>{{ step.text }}</span>
            </div>
          </div>
        </div>
      </el-col>
    </el-row>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useAppStore } from '../stores/app'
import { dashboardApi, certApi } from '../api'
import HIcon from '../components/HIcon.vue'

const store = useAppStore()
const stats = ref({ accounts: 0, devices: 0, certificates: 0, profiles: 0 })
const recentCerts = ref([])

const userInfo = JSON.parse(localStorage.getItem('auth_user') || '{}')
const username = computed(() => userInfo.username || '用户')

const guideSteps = [
  { text: '配置 Apple 开发者账号 API Key', color: '#066DE6' },
  { text: '注册测试设备 UDID', color: '#4CD964' },
  { text: '创建开发/发布证书并导出 P12', color: '#FF6D00' },
  { text: '创建 Bundle ID 并配置权限', color: '#7c5ce7' },
  { text: '生成描述文件并下载', color: '#E60019' },
]

onMounted(async () => {
  await store.fetchAccounts()

  try {
    const res = await dashboardApi.stats()
    if (res.data?.stats) stats.value = res.data.stats
  } catch {
    stats.value.accounts = store.accounts.length
  }

  try {
    const res = await certApi.list()
    recentCerts.value = (res.data || []).slice(0, 5)
  } catch {}
})
</script>

<style scoped>
.guide-list {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.guide-item {
  display: flex;
  align-items: center;
  gap: 14px;
  font-size: 14px;
  font-weight: 500;
  color: var(--nask-text);
}

.guide-num {
  width: 28px;
  height: 28px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #fff;
  font-size: 12px;
  font-weight: 700;
  flex-shrink: 0;
}
</style>
