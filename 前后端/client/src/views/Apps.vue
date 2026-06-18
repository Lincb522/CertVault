<template>
  <div>
    <div class="page-header">
      <h1>应用管理</h1>
      <p>查看 App Store Connect 中的应用、构建版本和发布历史</p>
    </div>

    <div class="content-card">
      <div class="card-header">
        <h3>应用列表</h3>
        <el-button @click="loadApps" :loading="loading" :disabled="!store.currentAccountId">
          <el-icon><Refresh /></el-icon> 刷新
        </el-button>
      </div>

      <div v-if="!store.currentAccountId" class="empty-state">
        <el-icon><Warning /></el-icon>
        <p>请先在左侧选择一个账号</p>
      </div>

      <el-table v-else :data="apps" stripe v-loading="loading" empty-text="暂无应用" row-key="id">
        <el-table-column prop="name" label="应用名称" min-width="180">
          <template #default="{ row }">
            <span style="font-weight: 600">{{ row.name }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="bundle_id" label="Bundle ID" min-width="220">
          <template #default="{ row }">
            <el-text size="small" style="font-family: monospace">{{ row.bundle_id }}</el-text>
          </template>
        </el-table-column>
        <el-table-column prop="sku" label="SKU" width="140" />
        <el-table-column prop="primary_locale" label="语言" width="90" />
        <el-table-column label="操作" width="200" fixed="right">
          <template #default="{ row }">
            <el-button size="small" @click="viewBuilds(row)">
              <el-icon><Box /></el-icon> 构建
            </el-button>
            <el-button size="small" type="primary" @click="viewVersions(row)">
              <el-icon><Document /></el-icon> 版本
            </el-button>
          </template>
        </el-table-column>
      </el-table>
    </div>

    <!-- 构建版本弹窗 -->
    <el-dialog v-model="showBuildsDialog" :title="`构建版本 — ${selectedApp?.name || ''}`" width="700px" destroy-on-close>
      <div style="margin-bottom: 14px; display: flex; align-items: center; gap: 10px">
        <span style="font-family: monospace; font-size: 12px; color: var(--nask-text-secondary)">{{ selectedApp?.bundle_id }}</span>
        <el-tag size="small" effect="plain">{{ builds.length }} 个构建</el-tag>
      </div>
      <el-table :data="builds" stripe v-loading="buildsLoading" empty-text="暂无构建版本">
        <el-table-column prop="version" label="版本号" width="100">
          <template #default="{ row }">
            <span style="font-weight: 600">{{ row.version }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="processing_state" label="状态" width="110">
          <template #default="{ row }">
            <el-tag :type="buildStateType(row.processing_state)" size="small">{{ row.processing_state }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="min_os_version" label="最低系统" width="100" />
        <el-table-column prop="uploaded_date" label="上传时间" min-width="160">
          <template #default="{ row }">{{ formatDate(row.uploaded_date) }}</template>
        </el-table-column>
        <el-table-column prop="expired" label="过期" width="70">
          <template #default="{ row }">
            <el-tag :type="row.expired ? 'danger' : 'success'" size="small">{{ row.expired ? '是' : '否' }}</el-tag>
          </template>
        </el-table-column>
      </el-table>
    </el-dialog>

    <!-- 版本历史弹窗 -->
    <el-dialog v-model="showVersionsDialog" :title="`版本历史 — ${selectedApp?.name || ''}`" width="700px" destroy-on-close>
      <div style="margin-bottom: 14px; display: flex; align-items: center; gap: 10px">
        <span style="font-family: monospace; font-size: 12px; color: var(--nask-text-secondary)">{{ selectedApp?.bundle_id }}</span>
        <el-tag size="small" effect="plain">{{ versions.length }} 个版本</el-tag>
      </div>
      <el-table :data="versions" stripe v-loading="versionsLoading" empty-text="暂无版本">
        <el-table-column prop="version" label="版本号" width="100">
          <template #default="{ row }">
            <span style="font-weight: 600">{{ row.version }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="state" label="状态" min-width="140">
          <template #default="{ row }">
            <el-tag :type="versionStateType(row.state)" size="small">{{ row.state_label || row.state }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="platform" label="平台" width="80">
          <template #default="{ row }">
            <el-tag size="small" effect="plain">{{ row.platform }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="release_type" label="发布方式" width="120">
          <template #default="{ row }">{{ releaseLabel(row.release_type) }}</template>
        </el-table-column>
        <el-table-column prop="created_date" label="创建时间" min-width="160">
          <template #default="{ row }">{{ formatDate(row.created_date) }}</template>
        </el-table-column>
      </el-table>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, watch } from 'vue'
import { useAppStore } from '../stores/app'
import { appsApi } from '../api'
import { ElMessage } from 'element-plus'
import { Refresh, Warning, Box, Document } from '@element-plus/icons-vue'

const store = useAppStore()
const apps = ref([])
const loading = ref(false)

const showBuildsDialog = ref(false)
const showVersionsDialog = ref(false)
const selectedApp = ref(null)
const builds = ref([])
const versions = ref([])
const buildsLoading = ref(false)
const versionsLoading = ref(false)

async function loadApps() {
  if (!store.currentAccountId) return
  loading.value = true
  try {
    const res = await appsApi.list(store.currentAccountId)
    apps.value = res.data || []
  } catch (e) {
    console.error(e)
  } finally {
    loading.value = false
  }
}

async function viewBuilds(app) {
  selectedApp.value = app
  showBuildsDialog.value = true
  buildsLoading.value = true
  try {
    const res = await appsApi.builds(app.id, store.currentAccountId)
    builds.value = res.data || []
  } catch (e) {
    console.error(e)
  } finally {
    buildsLoading.value = false
  }
}

async function viewVersions(app) {
  selectedApp.value = app
  showVersionsDialog.value = true
  versionsLoading.value = true
  try {
    const res = await appsApi.versions(app.id, store.currentAccountId)
    versions.value = res.data || []
  } catch (e) {
    console.error(e)
  } finally {
    versionsLoading.value = false
  }
}

function buildStateType(state) {
  const map = { VALID: 'success', PROCESSING: 'warning', FAILED: 'danger', INVALID: 'danger' }
  return map[state] || 'info'
}

function versionStateType(state) {
  const map = {
    READY_FOR_SALE: 'success', ACCEPTED: 'success', PREPARE_FOR_SUBMISSION: 'info',
    WAITING_FOR_REVIEW: 'warning', IN_REVIEW: 'warning', READY_FOR_REVIEW: 'warning',
    REJECTED: 'danger', METADATA_REJECTED: 'danger', DEVELOPER_REJECTED: 'danger',
    DEVELOPER_REMOVED_FROM_SALE: 'info', REMOVED_FROM_SALE: 'danger',
  }
  return map[state] || 'info'
}

function releaseLabel(type) {
  const map = { MANUAL: '手动发布', AFTER_APPROVAL: '自动发布', SCHEDULED: '定时发布' }
  return map[type] || type || '-'
}

function formatDate(d) {
  if (!d) return '-'
  return new Date(d).toLocaleString('zh-CN')
}

watch(() => store.currentAccountId, () => {
  apps.value = []
  loadApps()
}, { immediate: true })
</script>
