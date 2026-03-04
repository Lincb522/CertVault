<template>
  <div>
    <div class="page-header">
      <h1>权限管理</h1>
      <p>管理 Bundle ID 的 Capabilities / Entitlements，支持一键开启常用权限</p>
    </div>

    <!-- 选择 Bundle ID -->
    <div class="content-card">
      <div class="toolbar">
        <el-select
          v-model="selectedBundleId"
          placeholder="选择 Bundle ID"
          style="width: 100%; max-width: 400px"
          :disabled="!store.currentAccountId"
        >
          <el-option
            v-for="b in bundleIds"
            :key="b.id"
            :label="`${b.name} (${b.identifier})`"
            :value="b.apple_id || b.id"
          />
        </el-select>
        <el-button @click="fetchCapabilities" :disabled="!selectedBundleId" :loading="loading">
          <el-icon><Refresh /></el-icon> 加载权限
        </el-button>
      </div>

      <div v-if="!selectedBundleId" class="empty-state">
        <el-icon><Setting /></el-icon>
        <p>请选择一个 Bundle ID 来管理其权限</p>
      </div>
    </div>

    <!-- 快捷操作区 -->
    <div v-if="selectedBundleId && capabilities.length" class="content-card">
      <div class="card-header">
        <h3>快捷操作</h3>
        <div>
          <el-button type="danger" size="small" @click="disableAll" :loading="batchLoading" :disabled="enabledCount === 0">
            <el-icon><Close /></el-icon> 一键关闭全部 ({{ enabledCount }})
          </el-button>
        </div>
      </div>

      <!-- 预设方案 -->
      <div class="preset-grid">
        <div
          v-for="(preset, key) in presets"
          :key="key"
          class="preset-card"
          @click="applyPreset(key)"
        >
          <div class="preset-header">
            <el-icon size="20" :color="presetColors[key]"><component :is="presetIcons[key]" /></el-icon>
            <strong>{{ preset.label }}</strong>
          </div>
          <p class="preset-desc">{{ preset.desc }}</p>
          <div class="preset-tags">
            <el-tag
              v-for="t in preset.types"
              :key="t"
              size="small"
              :type="isEnabled(t) ? 'success' : 'info'"
              effect="plain"
            >
              {{ getCapLabel(t) }}
            </el-tag>
          </div>
        </div>
      </div>
    </div>

    <!-- 权限列表（分类） -->
    <div v-if="selectedBundleId && capabilities.length">
      <div v-for="cat in categories" :key="cat.key" class="content-card">
        <div class="card-header">
          <h3>
            <el-icon size="18" style="vertical-align: middle; margin-right: 6px"><component :is="cat.icon" /></el-icon>
            {{ cat.label }}
          </h3>
          <div>
            <el-button
              size="small"
              type="primary"
              @click="enableCategory(cat.key)"
              :disabled="getCategoryUnenabled(cat.key).length === 0"
            >
              全部开启 ({{ getCategoryUnenabled(cat.key).length }})
            </el-button>
            <el-button
              size="small"
              type="danger"
              @click="disableCategory(cat.key)"
              :disabled="getCategoryEnabled(cat.key).length === 0"
            >
              全部关闭 ({{ getCategoryEnabled(cat.key).length }})
            </el-button>
          </div>
        </div>

        <el-table :data="getByCategory(cat.key)" stripe>
          <el-table-column label="权限" min-width="200">
            <template #default="{ row }">
              <div class="cap-name">
                <strong>{{ row.label }}</strong>
                <el-tag v-if="row.category === 'common'" size="small" type="warning" effect="plain" style="margin-left:6px">常用</el-tag>
              </div>
              <div class="cap-desc">{{ row.desc }}</div>
            </template>
          </el-table-column>
          <el-table-column label="要求说明" min-width="220">
            <template #default="{ row }">
              <div class="cap-req">
                <el-icon size="14" color="#e6a23c" style="flex-shrink:0"><WarningFilled /></el-icon>
                <span>{{ row.requirement }}</span>
              </div>
            </template>
          </el-table-column>
          <el-table-column label="标识" width="200">
            <template #default="{ row }">
              <el-text size="small" style="font-family:monospace; color:#909399">{{ row.type }}</el-text>
            </template>
          </el-table-column>
          <el-table-column label="状态" width="100" align="center">
            <template #default="{ row }">
              <el-switch
                :model-value="row.enabled"
                @change="(val) => toggleCapability(row, val)"
                :loading="togglingId === row.type"
              />
            </template>
          </el-table-column>
        </el-table>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import { capabilityApi, profileApi } from '../api'
import { useAppStore } from '../stores/app'

const store = useAppStore()
const route = useRoute()
const bundleIds = ref([])
const capabilities = ref([])
const presets = ref({})
const selectedBundleId = ref('')
const loading = ref(false)
const batchLoading = ref(false)
const togglingId = ref('')

const categories = [
  { key: 'common', label: '常用权限', icon: 'Star' },
  { key: 'payment', label: '支付相关', icon: 'CreditCard' },
  { key: 'device', label: '设备能力', icon: 'Iphone' },
  { key: 'network', label: '网络相关', icon: 'Connection' },
  { key: 'security', label: '安全与隐私', icon: 'Lock' },
  { key: 'media', label: '媒体与教育', icon: 'VideoPlay' },
]

const presetColors = { basic: '#409eff', social: '#67c23a', game: '#e6a23c', enterprise: '#906afc' }
const presetIcons = { basic: 'Star', social: 'ChatDotRound', game: 'TrophyBase', enterprise: 'OfficeBuilding' }

const enabledCount = computed(() => capabilities.value.filter(c => c.enabled).length)

function isEnabled(type) {
  return capabilities.value.find(c => c.type === type)?.enabled || false
}

function getCapLabel(type) {
  return capabilities.value.find(c => c.type === type)?.label || type
}

function getByCategory(cat) {
  return capabilities.value.filter(c => c.category === cat)
}

function getCategoryEnabled(cat) {
  return capabilities.value.filter(c => c.category === cat && c.enabled)
}

function getCategoryUnenabled(cat) {
  return capabilities.value.filter(c => c.category === cat && !c.enabled)
}

async function fetchBundleIds() {
  if (!store.currentAccountId) return
  try {
    const res = await profileApi.bundleIds(store.currentAccountId)
    bundleIds.value = res.data || []
  } catch {}
}

async function fetchCapabilities() {
  if (!selectedBundleId.value || !store.currentAccountId) return
  loading.value = true
  try {
    const res = await capabilityApi.list(selectedBundleId.value, store.currentAccountId)
    capabilities.value = res.data || []

    const avail = await capabilityApi.available()
    presets.value = avail.presets || {}
  } finally {
    loading.value = false
  }
}

async function toggleCapability(cap, enabled) {
  togglingId.value = cap.type
  try {
    if (enabled) {
      await capabilityApi.enable({
        account_id: store.currentAccountId,
        bundle_id: selectedBundleId.value,
        capability_type: cap.type
      })
      ElMessage.success(`${cap.label} 已开启`)
    } else {
      if (!cap.id) {
        ElMessage.warning('无法关闭此权限（无有效 ID）')
        return
      }
      await capabilityApi.disable({
        account_id: store.currentAccountId,
        capability_id: cap.id
      })
      ElMessage.success(`${cap.label} 已关闭`)
    }
    await fetchCapabilities()
  } catch {
    ElMessage.error('操作失败')
  } finally {
    togglingId.value = ''
  }
}

async function applyPreset(key) {
  const preset = presets.value[key]
  if (!preset) return
  const toEnable = preset.types.filter(t => !isEnabled(t))
  if (toEnable.length === 0) {
    ElMessage.info('该预设的所有权限已开启')
    return
  }

  await ElMessageBox.confirm(
    `将开启「${preset.label}」预设中的 ${toEnable.length} 项权限，是否继续？`,
    '一键开启权限',
    { type: 'info', confirmButtonText: '开启' }
  )

  batchLoading.value = true
  try {
    const res = await capabilityApi.batchEnable({
      account_id: store.currentAccountId,
      bundle_id: selectedBundleId.value,
      capability_types: toEnable
    })
    const ok = res.data?.results?.length || 0
    const fail = res.data?.errors?.length || 0
    ElMessage.success(`完成：成功 ${ok} 项${fail ? `，失败 ${fail} 项` : ''}`)
    await fetchCapabilities()
  } finally {
    batchLoading.value = false
  }
}

async function enableCategory(cat) {
  const toEnable = getCategoryUnenabled(cat).map(c => c.type)
  if (!toEnable.length) return

  await ElMessageBox.confirm(`将开启该分类下 ${toEnable.length} 项权限，是否继续？`, '批量开启', { type: 'info' })

  batchLoading.value = true
  try {
    const res = await capabilityApi.batchEnable({
      account_id: store.currentAccountId,
      bundle_id: selectedBundleId.value,
      capability_types: toEnable
    })
    const ok = res.data?.results?.length || 0
    ElMessage.success(`成功开启 ${ok} 项权限`)
    await fetchCapabilities()
  } finally {
    batchLoading.value = false
  }
}

async function disableCategory(cat) {
  const toDisable = getCategoryEnabled(cat).filter(c => c.id).map(c => c.id)
  if (!toDisable.length) return

  await ElMessageBox.confirm(`将关闭该分类下 ${toDisable.length} 项权限，是否继续？`, '批量关闭', { type: 'warning' })

  batchLoading.value = true
  try {
    const res = await capabilityApi.batchDisable({
      account_id: store.currentAccountId,
      capability_ids: toDisable
    })
    const ok = res.data?.results?.length || 0
    ElMessage.success(`成功关闭 ${ok} 项权限`)
    await fetchCapabilities()
  } finally {
    batchLoading.value = false
  }
}

async function disableAll() {
  const toDisable = capabilities.value.filter(c => c.enabled && c.id).map(c => c.id)
  if (!toDisable.length) return

  await ElMessageBox.confirm(
    `确定关闭全部 ${toDisable.length} 项已开启的权限？此操作不可撤销。`,
    '一键关闭全部权限',
    { type: 'error', confirmButtonText: '全部关闭' }
  )

  batchLoading.value = true
  try {
    const res = await capabilityApi.batchDisable({
      account_id: store.currentAccountId,
      capability_ids: toDisable
    })
    const ok = res.data?.results?.length || 0
    ElMessage.success(`已关闭 ${ok} 项权限`)
    await fetchCapabilities()
  } finally {
    batchLoading.value = false
  }
}

watch(() => store.currentAccountId, () => {
  fetchBundleIds()
  capabilities.value = []
  selectedBundleId.value = ''
})
watch(selectedBundleId, fetchCapabilities)

onMounted(() => {
  fetchBundleIds()
  if (route.query.bundle_id) {
    selectedBundleId.value = route.query.bundle_id
  }
})
</script>

<style scoped>
.preset-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
  gap: 14px;
}

.preset-card {
  border: 1px solid var(--cv-border-light);
  border-radius: var(--cv-radius-sm);
  padding: 16px;
  cursor: pointer;
  transition: all var(--cv-transition);
  background: var(--cv-surface-hover);
}

.preset-card:hover {
  border-color: var(--cv-blue);
  background: rgba(64,158,255,0.04);
  box-shadow: 0 4px 12px rgba(64,158,255,0.1);
  transform: translateY(-1px);
}

.preset-header {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 6px;
}

.preset-desc {
  color: var(--cv-text-secondary);
  font-size: 13px;
  margin: 0 0 10px 0;
}

.preset-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
}

.cap-name {
  display: flex;
  align-items: center;
  font-size: 14px;
}

.cap-desc {
  color: var(--cv-text-secondary);
  font-size: 12px;
  margin-top: 2px;
}

.cap-req {
  display: flex;
  align-items: flex-start;
  gap: 6px;
  color: var(--cv-text-muted);
  font-size: 12px;
  line-height: 1.5;
}
</style>
