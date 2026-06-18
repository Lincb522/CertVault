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
          <el-dropdown :disabled="!selectedIds.length" @command="handleBatchUpdate" style="margin-left: 0">
            <el-button size="small" type="primary" plain :disabled="!selectedIds.length">
              <el-icon><Switch /></el-icon> 批量切换 {{ selectedIds.length ? `(${selectedIds.length})` : '' }}
            </el-button>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item command="production">切换为 Production</el-dropdown-item>
                <el-dropdown-item command="sandbox">切换为 Sandbox</el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
          <el-button size="small" type="warning" plain @click="showCleanupDialog = true">
            <el-icon><Brush /></el-icon> 清理无效
          </el-button>
          <el-button size="small" type="success" plain @click="showValidateDialog = true">
            <el-icon><Check /></el-icon> 验证设备
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

    <!-- 注册历史 -->
    <div class="content-card" style="margin-top: 20px">
      <div class="card-header">
        <h3>注册历史</h3>
        <div style="display: flex; gap: 8px; align-items: center">
          <el-select v-model="historyAction" placeholder="全部类型" clearable size="small" style="width: 120px" @change="fetchHistory">
            <el-option label="全部" value="" />
            <el-option label="注册" value="register" />
            <el-option label="上报" value="report" />
            <el-option label="注销" value="unregister" />
            <el-option label="失效" value="invalidated" />
          </el-select>
          <el-button size="small" @click="fetchHistory" :loading="historyLoading">
            <el-icon><Refresh /></el-icon>
          </el-button>
        </div>
      </div>
      <el-table :data="historyItems" stripe v-loading="historyLoading" empty-text="暂无注册历史" size="small">
        <el-table-column label="操作" width="80" align="center">
          <template #default="{ row }">
            <el-tag :type="actionTagType(row.action)" size="small">{{ actionLabel(row.action) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="设备" min-width="150">
          <template #default="{ row }">
            <div>{{ row.device_name || row.model || row.label || '未知设备' }}</div>
            <div v-if="row.model && row.device_name" style="font-size: 11px; color: var(--nask-text-muted)">{{ row.model }}</div>
          </template>
        </el-table-column>
        <el-table-column label="Token" min-width="140">
          <template #default="{ row }">
            <code style="font-size: 11px; color: var(--nask-text-secondary)">{{ (row.device_token || '').substring(0, 16) }}...</code>
          </template>
        </el-table-column>
        <el-table-column label="环境" width="90" align="center">
          <template #default="{ row }">
            <el-tag :type="row.sandbox ? 'warning' : 'success'" size="small" effect="plain">
              {{ row.sandbox ? '沙盒' : '生产' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="用户" prop="username" width="100" />
        <el-table-column label="时间" width="170">
          <template #default="{ row }">
            <span style="font-size: 13px; color: var(--nask-text-secondary)">{{ formatTime(row.created_at) }}</span>
          </template>
        </el-table-column>
      </el-table>
      <div v-if="historyTotal > historyItems.length" style="text-align: center; padding: 12px">
        <el-button size="small" @click="loadMoreHistory" :loading="historyLoading">加载更多 ({{ historyItems.length }}/{{ historyTotal }})</el-button>
      </div>
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
          <el-input v-model="cleanupForm.bundle_id" placeholder="例如：com.example.yourapp" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showCleanupDialog = false">取消</el-button>
        <el-button type="warning" @click="submitCleanup" :loading="cleanupLoading">开始清理</el-button>
      </template>
    </el-dialog>

    <!-- 验证设备对话框 -->
    <el-dialog v-model="showValidateDialog" title="验证设备 Token" width="600" destroy-on-close>
      <el-alert type="info" :closable="false" style="margin-bottom: 16px">
        <template #title>发送静默推送验证 Token 有效性</template>
        通过向所有设备发送静默推送来检测 Token 是否仍然有效，无效 Token 会被标记。
      </el-alert>
      <el-form :model="validateForm" label-width="100px">
        <el-form-item label="推送密钥" required>
          <el-select v-model="validateForm.push_key_id" style="width: 100%" placeholder="选择推送密钥">
            <el-option v-for="pk in pushKeys" :key="pk.id" :label="`${pk.name} (${pk.key_id})`" :value="pk.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="Bundle ID" required>
          <el-input v-model="validateForm.bundle_id" placeholder="例如：com.example.myapp" />
        </el-form-item>
      </el-form>
      <div v-if="validateResult" style="margin-top: 16px">
        <el-descriptions :column="3" border size="small" style="margin-bottom: 12px">
          <el-descriptions-item label="总计">{{ validateResult.total }}</el-descriptions-item>
          <el-descriptions-item label="有效"><span style="color: var(--el-color-success)">{{ validateResult.valid }}</span></el-descriptions-item>
          <el-descriptions-item label="无效"><span style="color: var(--el-color-danger)">{{ validateResult.invalid }}</span></el-descriptions-item>
        </el-descriptions>
        <el-table :data="validateResult.results" stripe size="small" max-height="300">
          <el-table-column label="设备" min-width="120">
            <template #default="{ row }">{{ row.device_name || row.model || row.device_token?.substring(0, 12) + '...' }}</template>
          </el-table-column>
          <el-table-column label="Token" min-width="140">
            <template #default="{ row }"><code style="font-size: 11px">{{ row.device_token?.substring(0, 16) }}...</code></template>
          </el-table-column>
          <el-table-column label="状态" width="100" align="center">
            <template #default="{ row }">
              <el-tag :type="row.valid ? 'success' : 'danger'" size="small">{{ row.valid ? '有效' : '无效' }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column label="原因" min-width="120">
            <template #default="{ row }">
              <span style="font-size: 12px; color: var(--nask-text-secondary)">{{ row.reason_cn || '-' }}</span>
            </template>
          </el-table-column>
        </el-table>
      </div>
      <template #footer>
        <el-button @click="showValidateDialog = false">关闭</el-button>
        <el-button type="success" @click="submitValidateAll" :loading="validateLoading">验证全部设备</el-button>
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
          <el-input v-model="testForm.bundle_id" placeholder="例如：com.example.yourapp" />
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

// 验证
const showValidateDialog = ref(false)
const validateLoading = ref(false)
const validateResult = ref(null)
const validateForm = ref({ push_key_id: '', bundle_id: '' })

// 历史
const historyItems = ref([])
const historyTotal = ref(0)
const historyLoading = ref(false)
const historyAction = ref('')
const historyPage = ref(1)

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

async function submitValidateAll() {
  if (!validateForm.value.push_key_id || !validateForm.value.bundle_id) {
    return ElMessage.warning('请选择推送密钥并填写 Bundle ID')
  }
  validateLoading.value = true
  validateResult.value = null
  try {
    const res = await pushApi.validateAllDevices(validateForm.value)
    validateResult.value = res.data || {}
    ElMessage.success(res.message || '验证完成')
    fetchDevices()
    fetchStats()
  } catch {} finally {
    validateLoading.value = false
  }
}

async function handleBatchUpdate(command) {
  if (!selectedIds.value.length) return
  const sandbox = command === 'sandbox'
  const label = sandbox ? 'Sandbox' : 'Production'
  try {
    await ElMessageBox.confirm(
      `确定将选中的 ${selectedIds.value.length} 个设备切换为 ${label}？`,
      '批量切换环境',
      { type: 'warning' }
    )
    await pushApi.batchUpdateDevices(selectedIds.value, { sandbox })
    ElMessage.success(`已切换 ${selectedIds.value.length} 个设备为 ${label}`)
    selectedIds.value = []
    fetchDevices()
    fetchStats()
  } catch {}
}

function actionLabel(action) {
  const map = { register: '注册', report: '上报', unregister: '注销', invalidated: '失效' }
  return map[action] || action || '未知'
}

function actionTagType(action) {
  const map = { register: 'success', report: 'primary', unregister: 'warning', invalidated: 'danger' }
  return map[action] || 'info'
}

async function fetchHistory() {
  historyLoading.value = true
  historyPage.value = 1
  try {
    const res = await pushApi.deviceHistory({ limit: 30, offset: 0, action: historyAction.value || undefined })
    historyItems.value = res.data || []
    historyTotal.value = res.total || 0
  } catch {
    historyItems.value = []
  } finally {
    historyLoading.value = false
  }
}

async function loadMoreHistory() {
  historyLoading.value = true
  historyPage.value++
  const offset = (historyPage.value - 1) * 30
  try {
    const res = await pushApi.deviceHistory({ limit: 30, offset, action: historyAction.value || undefined })
    historyItems.value.push(...(res.data || []))
  } catch {} finally {
    historyLoading.value = false
  }
}

onMounted(() => {
  fetchDevices()
  fetchStats()
  fetchPushKeys()
  fetchHistory()
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
