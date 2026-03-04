<template>
  <div>
    <div class="welcome-banner">
      <h2>欢迎使用 CertVault</h2>
      <p>Apple 开发者证书一站式管理平台 — 轻松管理证书、设备、描述文件和推送配置</p>
    </div>

    <div class="stat-grid">
      <div class="stat-card">
        <div class="stat-icon blue"><el-icon><User /></el-icon></div>
        <div class="stat-info">
          <div class="stat-value">{{ stats.accounts }}</div>
          <div class="stat-label">开发者账号</div>
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-icon green"><el-icon><Iphone /></el-icon></div>
        <div class="stat-info">
          <div class="stat-value">{{ stats.devices }}</div>
          <div class="stat-label">已注册设备</div>
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-icon orange"><el-icon><Key /></el-icon></div>
        <div class="stat-info">
          <div class="stat-value">{{ stats.certificates }}</div>
          <div class="stat-label">证书总数</div>
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-icon purple"><el-icon><Document /></el-icon></div>
        <div class="stat-info">
          <div class="stat-value">{{ stats.profiles }}</div>
          <div class="stat-label">描述文件</div>
        </div>
      </div>
    </div>

    <div class="content-card" style="margin-bottom: 24px">
      <div class="card-header"><h3>快速操作</h3></div>
      <div class="quick-grid">
        <div class="quick-card" @click="$router.push('/certificates')">
          <div class="q-icon" style="background: linear-gradient(135deg, rgba(64,158,255,0.12), rgba(64,158,255,0.2)); color: var(--cv-blue)">
            <el-icon><Key /></el-icon>
          </div>
          <div class="q-label">创建证书</div>
        </div>
        <div class="quick-card" @click="$router.push('/devices')">
          <div class="q-icon" style="background: linear-gradient(135deg, rgba(34,197,94,0.12), rgba(34,197,94,0.2)); color: var(--cv-green)">
            <el-icon><Iphone /></el-icon>
          </div>
          <div class="q-label">添加设备</div>
        </div>
        <div class="quick-card" @click="$router.push('/profiles')">
          <div class="q-icon" style="background: linear-gradient(135deg, rgba(245,158,11,0.12), rgba(245,158,11,0.2)); color: var(--cv-orange)">
            <el-icon><Document /></el-icon>
          </div>
          <div class="q-label">生成描述文件</div>
        </div>
        <div class="quick-card" @click="$router.push('/accounts')">
          <div class="q-icon" style="background: linear-gradient(135deg, rgba(144,106,252,0.12), rgba(144,106,252,0.2)); color: var(--cv-purple)">
            <el-icon><User /></el-icon>
          </div>
          <div class="q-label">管理账号</div>
        </div>
        <div class="quick-card" @click="$router.push('/get-udid')">
          <div class="q-icon" style="background: linear-gradient(135deg, rgba(6,182,212,0.12), rgba(6,182,212,0.2)); color: var(--cv-cyan)">
            <el-icon><Monitor /></el-icon>
          </div>
          <div class="q-label">获取 UDID</div>
        </div>
        <div class="quick-card" @click="$router.push('/healthcheck')">
          <div class="q-icon" style="background: linear-gradient(135deg, rgba(236,72,153,0.12), rgba(236,72,153,0.2)); color: var(--cv-pink)">
            <el-icon><CircleCheck /></el-icon>
          </div>
          <div class="q-label">健康检查</div>
        </div>
      </div>
    </div>

    <el-row :gutter="20">
      <el-col :span="12">
        <div class="content-card">
          <div class="card-header"><h3>最近证书</h3></div>
          <el-table :data="recentCerts" size="small" empty-text="暂无证书" :header-cell-style="{ background: 'var(--cv-surface-hover)' }">
            <el-table-column prop="name" label="名称" show-overflow-tooltip />
            <el-table-column prop="type" label="类型" width="160" />
            <el-table-column prop="expires_at" label="过期时间" width="120">
              <template #default="{ row }">
                {{ row.expires_at ? new Date(row.expires_at).toLocaleDateString() : '-' }}
              </template>
            </el-table-column>
          </el-table>
        </div>
      </el-col>
      <el-col :span="12">
        <div class="content-card">
          <div class="card-header"><h3>使用指南</h3></div>
          <el-timeline>
            <el-timeline-item type="primary" :hollow="true">
              <div class="guide-step">配置 Apple 开发者账号 API Key</div>
            </el-timeline-item>
            <el-timeline-item type="success" :hollow="true">
              <div class="guide-step">注册测试设备 UDID</div>
            </el-timeline-item>
            <el-timeline-item type="warning" :hollow="true">
              <div class="guide-step">创建开发/发布证书并导出 P12</div>
            </el-timeline-item>
            <el-timeline-item color="#906AFC" :hollow="true">
              <div class="guide-step">创建 Bundle ID 并配置权限</div>
            </el-timeline-item>
            <el-timeline-item type="danger" :hollow="true">
              <div class="guide-step">生成描述文件并下载</div>
            </el-timeline-item>
          </el-timeline>
        </div>
      </el-col>
    </el-row>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useAppStore } from '../stores/app'
import { dashboardApi, certApi } from '../api'

const store = useAppStore()
const stats = ref({ accounts: 0, devices: 0, certificates: 0, profiles: 0 })
const recentCerts = ref([])

onMounted(async () => {
  await store.fetchAccounts()

  try {
    const res = await dashboardApi.stats()
    if (res.data?.stats) {
      stats.value = res.data.stats
    }
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
.guide-step {
  font-size: 14px;
  color: var(--cv-text);
  font-weight: 500;
}
</style>
