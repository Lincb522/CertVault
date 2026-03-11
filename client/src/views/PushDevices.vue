<template>
  <div>
    <div class="page-header">
      <h1>设备 Token 管理</h1>
      <p>管理已注册的推送设备 Token，支持查看、编辑、删除和批量清理无效 Token</p>
    </div>

    <!-- 统计卡片 -->
    <el-row :gutter="16" style="margin-bottom: 20px">
      <el-col :xs="12" :sm="6">
        <div class="content-card stat-card">
          <div class="stat-value">{{ stats.total ?? '-' }}</div>
          <div class="stat-label">总设备数</div>
        </div>
      </el-col>
      <el-col :xs="12" :sm="6">
        <div class="content-card stat-card">
          <div class="stat-value production">{{ stats.production ?? '-' }}</div>
          <div class="stat-label">Production</div>
        </div>
      </el-col>
      <el-col :xs="12" :sm="6">
        <div class="content-card stat-card">
          <div class="stat-value sandbox">{{ stats.sandbox ?? '-' }}</div>
          <div class="stat-label">Sandbox</div>
        </div>
      </el-col>
      <el-col :xs="12" :sm="6">
        <div class="content-card stat-card">
          <div class="stat-value ios">{{ stats.ios ?? '-' }}</div>
          <div class="stat-label">iOS</div>
        </div>
      </el-col>
    </el-row>

    <!-- 主表格 -->
    <div class="content-card">
      <div class="card-header">
        <h3>设备列表</h3>
        <div style="display: flex; gap: 8px; align-items: center">
          <el-button size="small" @click="showAddDialog = true">
            <el-icon><Plus /></el-icon> 添加设备
          </el-button>
          <el-button size="small" type="danger" plain :disabled="!selectedIds.length" @click="batchDelete">
            <el-icon><Delete /></el-icon> 批量删除 {{ selectedIds.length ? `(${selectedIds.length})` : '' }}
          </el-button>
          <el-button size="small" type="warning" plain @click="showCleanupDialog = true">
            <el-icon><Brush /></el-icon> 清理无效
          </el-button>
          <el-button size="small" @click="fetchDevices" :loading="loading">
            <el-icon><Refresh /></el-icon>
          </el-button>
        </div>
      </div>

      <el-table
        :data="devices"
        v-loading="loading"
        @selection-change="onSelectionChange"
        empty-text="暂无已注册的设备"
        stripe
      >
        <el-table-column type="selection" width="42" />
        <el-table-column label="设备" min-width="260">
          <template #default="{ row }">
            <div class="device-info">
              <div class="device-main">
                <span class="device-icon">{{ parseLabel(row.label).icon }}</span>
                <div>
                  <div class="device-name">{{ parseLabel(row.label).name || '未知设备' }}</div>
                  <div class="device-meta" v-if="parseLabel(row.label).model">
                    <span class="meta-chip">{{ parseLabel(row.label).model }}</span>
                    <span class="meta-chip" v-if="parseLabel(row.label).osVersion">{{ parseLabel(row.label).osVersion }}</span>
                    <span class="meta-chip app-ver" v-if="parseLabel(row.label).appVersion">{{ parseLabel(row.label).appVersion }}</span>
                  </div>
                  <div class="device-meta" v-else-if="row.label">
                    <span class="meta-chip">{{ row.label }}</span>
                  </div>
                </div>
              </div>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="Token" min-width="180">
          <template #default="{ row }">
            <div class="token-cell">
              <code class="token-text">{{ row.device_token.substring(0, 20) }}...</code>
              <el-button link size="small" @click="copyToken(row.device_token)">
                <el-icon><CopyDocument /></el-icon>
              </el-button>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="环境" width="110" align="center">
          <template #default="{ row }">
            <el-tag :type="row.sandbox ? 'warning' : 'success'" size="small" effect="plain">
              {{ row.sandbox ? 'Sandbox' : 'Production' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="平台" width="80" align="center">
          <template #default="{ row }">
            <el-tag size="small" effect="plain">{{ (row.platform || 'ios').toUpperCase() }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="用户" prop="username" width="100" />
        <el-table-column label="注册时间" width="170">
          <template #default="{ row }">
            <span class="time-text">{{ formatTime(row.created_at) }}</span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="180" align="center" fixed="right">
          <template #default="{ row }">
            <el-button link size="small" @click="testPush(row)">
              <el-icon><Promotion /></el-icon> 测试
            </el-button>
            <el-button link size="small" @click="editDevice(row)">
              <el-icon><Edit /></el-icon> 编辑
            </el-button>
            <el-button link size="small" type="danger" @click="deleteDevice(row)">
              <el-icon><Delete /></el-icon>
            </el-button>
          </template>
        </el-table-column>
      </el-table>
    </div>

    <!-- 添加设备对话框 -->
    <el-dialog v-model="showAddDialog" title="添加设备 Token" width="520" destroy-on-close>
      <el-form :model="addForm" label-width="100px">
        <el-form-item label="Device Token" required>
          <el-input v-model="addForm.device_token" placeholder="64位十六进制字符串" />
        </el-form-item>
        <el-form-item label="平台">
          <el-radio-group v-model="addForm.platform">
            <el-radio-button value="ios">iOS</el-radio-button>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="环境">
          <el-radio-group v-model="addForm.sandbox">
            <el-radio-button :value="false">Production</el-radio-button>
            <el-radio-button :value="true">Sandbox</el-radio-button>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="备注">
          <el-input v-model="addForm.label" placeholder="可选，如：我的 iPhone 15 Pro" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showAddDialog = false">取消</el-button>
        <el-button type="primary" @click="submitAdd" :loading="addLoading">添加</el-button>
      </template>
    </el-dialog>

    <!-- 编辑设备对话框 -->
    <el-dialog v-model="showEditDialog" title="编辑设备" width="520" destroy-on-close>
      <el-form :model="editForm" label-width="100px">
        <el-form-item label="Device Token">
          <code style="font-size: 12px; word-break: break-all; color: var(--nask-text-muted)">{{ editForm.device_token }}</code>
        </el-form-item>
        <el-form-item label="环境">
          <el-radio-group v-model="editForm.sandbox">
            <el-radio-button :value="false">Production</el-radio-button>
            <el-radio-button :value="true">Sandbox</el-radio-button>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="备注">
          <el-input v-model="editForm.label" placeholder="设备备注" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showEditDialog = false">取消</el-button>
        <el-button type="primary" @click="submitEdit" :loading="editLoading">保存</el-button>
      </template>
    </el-dialog>

    <!-- 清理对话框 -->
    <el-dialog v-model="showCleanupDialog" title="清理无效 Token" width="480" destroy-on-close>
      <el-alert type="info" :closable="false" style="margin-bottom: 16px">
        <template #title>自动验证所有设备 Token</template>
        向每个设备发送静默推送来验证 Token 是否有效，自动删除已注销 (410 Unregistered) 的设备。
      </el-alert>
      <el-form :model="cleanupForm" label-width="100px">
        <el-form-item label="推送密钥" required>
          <el-select v-model="cleanupForm.push_key_id" style="width: 100%" placeholder="选择推送密钥">
            <el-option
              v-for="pk in pushKeys"
              :key="pk.id"
              :label="`${pk.name} (${pk.key_id})`"
              :value="pk.id"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="Bundle ID" required>
          <el-input v-model="cleanupForm.bundle_id" placeholder="例如：zijiu.Aside.com" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showCleanupDialog = false">取消</el-button>
        <el-button type="warning" @click="submitCleanup" :loading="cleanupLoading">开始清理</el-button>
      </template>
    </el-dialog>

    <!-- 测试推送对话框 -->
    <el-dialog v-model="showTestDialog" title="测试推送" width="480" destroy-on-close>
      <el-form :model="testForm" label-width="100px">
        <el-form-item label="目标设备">
          <code style="font-size: 12px; word-break: break-all; color: var(--nask-text-muted)">{{ testForm.device_token?.substring(0, 16) }}...</code>
          <el-tag :type="testForm.sandbox ? 'warning' : 'success'" size="small" style="margin-left: 8px">
            {{ testForm.sandbox ? 'Sandbox' : 'Production' }}
          </el-tag>
        </el-form-item>
        <el-form-item label="推送密钥" required>
          <el-select v-model="testForm.push_key_id" style="width: 100%" placeholder="选择推送密钥">
            <el-option
              v-for="pk in pushKeys"
              :key="pk.id"
              :label="`${pk.name} (${pk.key_id})`"
              :value="pk.id"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="Bundle ID" required>
          <el-input v-model="testForm.bundle_id" placeholder="例如：zijiu.Aside.com" />
        </el-form-item>
        <el-form-item label="标题" required>
          <el-input v-model="testForm.title" placeholder="推送标题" />
        </el-form-item>
        <el-form-item label="内容">
          <el-input v-model="testForm.body" placeholder="推送内容" />
        </el-form-item>
      </el-form>
      <div v-if="testResult" class="push-result" :class="testResult.success ? 'success' : 'error'" style="margin-top: 12px">
        <el-icon size="18">
          <CircleCheckFilled v-if="testResult.success" />
          <CircleCloseFilled v-else />
        </el-icon>
        <div>
          <strong>{{ testResult.message }}</strong>
          <div v-if="testResult.data?.reason" class="result-detail">Reason: {{ testResult.data.reason }}</div>
        </div>
      </div>
      <template #footer>
        <el-button @click="showTestDialog = false">关闭</el-button>
        <el-button type="primary" @click="submitTest" :loading="testLoading">发送测试推送</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { pushApi, pushKeyApi } from '../api'

const loading = ref(false)
const devices = ref([])
const stats = ref({})
const selectedIds = ref([])
const pushKeys = ref([])

// 添加
const showAddDialog = ref(false)
const addLoading = ref(false)
const addForm = ref({ device_token: '', platform: 'ios', sandbox: false, label: '' })

// 编辑
const showEditDialog = ref(false)
const editLoading = ref(false)
const editForm = ref({ id: null, device_token: '', sandbox: false, label: '' })

// 清理
const showCleanupDialog = ref(false)
const cleanupLoading = ref(false)
const cleanupForm = ref({ push_key_id: '', bundle_id: '' })

// 测试
const showTestDialog = ref(false)
const testLoading = ref(false)
const testResult = ref(null)
const testForm = ref({ device_token: '', sandbox: false, push_key_id: '', bundle_id: '', title: '测试推送', body: 'Hello from CertVault!' })

function onSelectionChange(rows) {
  selectedIds.value = rows.map(r => r.id)
}

function formatTime(t) {
  if (!t) return '-'
  const d = new Date(t)
  return d.toLocaleString('zh-CN', { year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' })
}

function parseLabel(label) {
  if (!label) return { icon: '📱', name: '', model: '', osVersion: '', appVersion: '' }
  const parts = label.split('|').map(s => s.trim())
  if (parts.length >= 4) {
    return {
      icon: parts[1]?.startsWith('iPad') ? '📋' : '📱',
      name: parts[0],
      model: parts[1],
      osVersion: parts[2],
      appVersion: parts[3],
    }
  }
  return { icon: '📱', name: label, model: '', osVersion: '', appVersion: '' }
}

function copyToken(token) {
  navigator.clipboard.writeText(token)
  ElMessage.success('已复制到剪贴板')
}

async function fetchDevices() {
  loading.value = true
  try {
    const res = await pushApi.devices()
    devices.value = res.data || []
  } finally {
    loading.value = false
  }
}

async function fetchStats() {
  try {
    const res = await pushApi.devicesStats()
    stats.value = res.data || {}
  } catch {
    stats.value = {}
  }
}

async function fetchPushKeys() {
  try {
    const res = await pushKeyApi.list()
    pushKeys.value = res.data || []
  } catch {}
}

async function submitAdd() {
  if (!addForm.value.device_token) return ElMessage.warning('请填写 Device Token')
  addLoading.value = true
  try {
    await pushApi.addDevice(addForm.value)
    ElMessage.success('设备添加成功')
    showAddDialog.value = false
    addForm.value = { device_token: '', platform: 'ios', sandbox: false, label: '' }
    fetchDevices()
    fetchStats()
  } catch {} finally {
    addLoading.value = false
  }
}

function editDevice(row) {
  editForm.value = { id: row.id, device_token: row.device_token, sandbox: !!row.sandbox, label: row.label || '' }
  showEditDialog.value = true
}

async function submitEdit() {
  editLoading.value = true
  try {
    await pushApi.updateDevice(editForm.value.id, {
      sandbox: editForm.value.sandbox,
      label: editForm.value.label,
    })
    ElMessage.success('设备信息已更新')
    showEditDialog.value = false
    fetchDevices()
  } catch {} finally {
    editLoading.value = false
  }
}

async function deleteDevice(row) {
  try {
    await ElMessageBox.confirm(
      `确定删除设备 ${row.device_token.substring(0, 12)}... ？`,
      '删除确认',
      { type: 'warning', confirmButtonText: '删除', cancelButtonText: '取消' }
    )
    await pushApi.deleteDevice(row.id)
    ElMessage.success('设备已删除')
    fetchDevices()
    fetchStats()
  } catch {}
}

async function batchDelete() {
  if (!selectedIds.value.length) return
  try {
    await ElMessageBox.confirm(
      `确定删除选中的 ${selectedIds.value.length} 个设备？`,
      '批量删除',
      { type: 'warning', confirmButtonText: '删除', cancelButtonText: '取消' }
    )
    await pushApi.batchDeleteDevices(selectedIds.value)
    ElMessage.success('批量删除成功')
    selectedIds.value = []
    fetchDevices()
    fetchStats()
  } catch {}
}

async function submitCleanup() {
  if (!cleanupForm.value.push_key_id || !cleanupForm.value.bundle_id) {
    return ElMessage.warning('请选择推送密钥并填写 Bundle ID')
  }
  cleanupLoading.value = true
  try {
    const res = await pushApi.cleanupDevices(cleanupForm.value)
    ElMessage.success(res.message || '清理完成')
    showCleanupDialog.value = false
    fetchDevices()
    fetchStats()
  } catch {} finally {
    cleanupLoading.value = false
  }
}

function testPush(row) {
  testForm.value = {
    device_token: row.device_token,
    sandbox: !!row.sandbox,
    push_key_id: pushKeys.value[0]?.id || '',
    bundle_id: '',
    title: '测试推送',
    body: 'Hello from CertVault!',
  }
  testResult.value = null
  showTestDialog.value = true
}

async function submitTest() {
  if (!testForm.value.push_key_id || !testForm.value.bundle_id || !testForm.value.title) {
    return ElMessage.warning('请填写推送密钥、Bundle ID 和标题')
  }
  testLoading.value = true
  testResult.value = null
  try {
    const res = await pushApi.send({
      push_key_id: testForm.value.push_key_id,
      device_token: testForm.value.device_token,
      bundle_id: testForm.value.bundle_id,
      sandbox: testForm.value.sandbox,
      title: testForm.value.title,
      body: testForm.value.body,
      sound: 'default',
    })
    testResult.value = res
  } catch (err) {
    testResult.value = { success: false, message: err.response?.data?.message || err.message }
  } finally {
    testLoading.value = false
  }
}

onMounted(() => {
  fetchDevices()
  fetchStats()
  fetchPushKeys()
})
</script>

<style scoped>
.stat-card {
  text-align: center;
  padding: 16px 12px !important;
}
.stat-value {
  font-size: 28px;
  font-weight: 700;
  color: var(--nask-text);
  line-height: 1.2;
}
.stat-value.production { color: var(--el-color-success); }
.stat-value.sandbox { color: var(--el-color-warning); }
.stat-value.ios { color: var(--el-color-primary); }
.stat-label {
  font-size: 12px;
  color: var(--nask-text-muted);
  margin-top: 4px;
}

.device-info {
  padding: 4px 0;
}
.device-main {
  display: flex;
  align-items: flex-start;
  gap: 10px;
}
.device-icon {
  font-size: 22px;
  line-height: 1;
  flex-shrink: 0;
  margin-top: 2px;
}
.device-name {
  font-size: 14px;
  font-weight: 600;
  color: var(--nask-text);
  line-height: 1.3;
}
.device-meta {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
  margin-top: 4px;
}
.meta-chip {
  display: inline-block;
  font-size: 11px;
  padding: 1px 7px;
  border-radius: 4px;
  background: var(--el-fill-color-light, #f4f4f5);
  color: var(--nask-text-secondary, #606266);
  line-height: 1.6;
}
.meta-chip.app-ver {
  background: rgba(64, 158, 255, 0.08);
  color: var(--el-color-primary);
}

.token-cell {
  display: flex;
  align-items: center;
  gap: 4px;
}
.token-text {
  font-size: 11px;
  color: var(--nask-text-secondary);
  word-break: break-all;
  line-height: 1.4;
  font-family: 'SF Mono', Monaco, Menlo, monospace;
}
.time-text {
  font-size: 13px;
  color: var(--nask-text-secondary);
}

.push-result {
  display: flex;
  align-items: flex-start;
  gap: 10px;
  padding: 12px 14px;
  border-radius: var(--nask-radius-sm);
}
.push-result.success {
  background: rgba(34, 197, 94, 0.06);
  border: 1px solid var(--nask-green, #22c55e);
  color: var(--nask-green, #22c55e);
}
.push-result.error {
  background: rgba(239, 68, 68, 0.06);
  border: 1px solid var(--nask-red, #ef4444);
  color: var(--nask-red, #ef4444);
}
.push-result strong {
  color: var(--nask-text);
}
.result-detail {
  font-size: 12px;
  color: var(--nask-text-muted);
  margin-top: 4px;
  font-family: monospace;
}
</style>
