<template>
  <div>
    <div class="page-header">
      <h1>账号管理</h1>
      <p>管理 Apple Developer API Key 配置，支持 .p8 密钥文件导入</p>
    </div>

    <div class="content-card">
      <div class="card-header">
        <h3>账号列表</h3>
        <div>
          <el-button type="success" @click="openImportDialog">
            <el-icon><Upload /></el-icon> 导入 P8
          </el-button>
          <el-button type="primary" @click="openAddDialog">
            <el-icon><Plus /></el-icon> 添加账号
          </el-button>
        </div>
      </div>

      <el-table :data="accounts" stripe v-loading="loading" empty-text="暂无账号，请先添加">
        <el-table-column prop="name" label="账号名称" min-width="150" />
        <el-table-column prop="issuer_id" label="Issuer ID" min-width="260">
          <template #default="{ row }">
            <el-text style="font-family: monospace; font-size: 12px">{{ row.issuer_id }}</el-text>
          </template>
        </el-table-column>
        <el-table-column prop="key_id" label="Key ID" width="130">
          <template #default="{ row }">
            <el-tag size="small" type="info">{{ row.key_id }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="created_at" label="创建时间" width="180">
          <template #default="{ row }">{{ formatDate(row.created_at) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="380" fixed="right">
          <template #default="{ row }">
            <el-button size="small" @click="viewDetail(row)">
              <el-icon><View /></el-icon> 详情
            </el-button>
            <el-button size="small" type="success" @click="testConnection(row.id)" :loading="testingId === row.id">
              测试
            </el-button>
            <el-button size="small" @click="downloadP8(row)">
              <el-icon><Download /></el-icon> P8
            </el-button>
            <el-button size="small" type="primary" @click="editAccount(row)">编辑</el-button>
            <el-button size="small" type="danger" @click="deleteAccount(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </div>

    <!-- 添加/编辑账号 -->
    <el-dialog v-model="showDialog" :title="editingId ? '编辑账号' : '添加账号'" width="600px" destroy-on-close>
      <el-form :model="form" label-width="110px" label-position="left">
        <el-form-item label="账号名称" required>
          <el-input v-model="form.name" placeholder="例如：个人开发者账号" />
        </el-form-item>
        <el-form-item label="Issuer ID" required>
          <el-input v-model="form.issuer_id" placeholder="App Store Connect → Users and Access → Keys" />
        </el-form-item>
        <el-form-item label="Key ID" required>
          <el-input v-model="form.key_id" placeholder="API Key 的 Key ID" />
        </el-form-item>
        <el-form-item label="Private Key" required>
          <div
            class="p8-drop-zone"
            :class="{ 'drag-over': isDragging, 'has-file': !!p8FileName }"
            @dragover.prevent="isDragging = true"
            @dragleave.prevent="isDragging = false"
            @drop.prevent="handleDrop"
          >
            <div v-if="p8FileName" class="p8-file-info">
              <el-icon size="20" color="#67c23a"><Document /></el-icon>
              <span class="p8-filename">{{ p8FileName }}</span>
              <el-tag size="small" type="success" v-if="p8KeyType">{{ p8KeyType }}</el-tag>
              <el-button size="small" text type="danger" @click.stop="clearP8File">移除</el-button>
            </div>
            <div v-else class="p8-placeholder">
              <el-icon size="32" color="#c0c4cc"><UploadFilled /></el-icon>
              <p>拖拽 .p8 文件到此处，或点击选择文件</p>
              <p style="font-size: 12px; color: #909399">支持 .p8 / .pem / .key 格式</p>
            </div>
            <input
              type="file"
              ref="fileInput"
              accept=".p8,.pem,.key"
              style="display: none"
              @change="handleFileSelect"
            />
            <div v-if="!p8FileName" class="p8-actions" @click.stop>
              <el-button size="small" @click="$refs.fileInput.click()">选择文件</el-button>
              <el-button size="small" @click="showPasteMode = true">手动粘贴</el-button>
            </div>
          </div>

          <el-input
            v-if="showPasteMode || form.private_key"
            v-model="form.private_key"
            type="textarea"
            :rows="5"
            style="margin-top: 8px"
            :readonly="!!p8FileName"
            placeholder="粘贴 .p8 文件内容 (-----BEGIN PRIVATE KEY-----...)"
            @blur="validatePastedKey"
          />
          <div v-if="showPasteMode && pasteValidation" style="margin-top: 4px">
            <el-tag :type="pasteValidation.valid ? 'success' : 'danger'" size="small">
              {{ pasteValidation.valid ? `有效密钥 (${pasteValidation.type})` : '无效的密钥格式' }}
            </el-tag>
          </div>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showDialog = false">取消</el-button>
        <el-button type="primary" @click="saveAccount" :loading="saving">保存</el-button>
      </template>
    </el-dialog>

    <!-- 快速导入 P8 -->
    <el-dialog v-model="showImportDialog" title="快速导入 P8 密钥" width="600px" destroy-on-close>
      <el-steps :active="importStep" simple style="margin-bottom: 24px">
        <el-step title="上传密钥" />
        <el-step title="填写信息" />
        <el-step title="完成" />
      </el-steps>

      <!-- Step 1: Upload -->
      <div v-if="importStep === 0">
        <div
          class="p8-drop-zone large"
          :class="{ 'drag-over': isDragging, 'has-file': !!importData.filename }"
          @dragover.prevent="isDragging = true"
          @dragleave.prevent="isDragging = false"
          @drop.prevent="handleImportDrop"
          @click="$refs.importFileInput?.click()"
        >
          <div v-if="importData.filename" class="p8-file-info">
            <el-icon size="32" color="#67c23a"><Document /></el-icon>
            <div>
              <div class="p8-filename">{{ importData.filename }}</div>
              <el-tag size="small" type="success">{{ importData.key_type }}</el-tag>
            </div>
          </div>
          <div v-else class="p8-placeholder">
            <el-icon size="48" color="#c0c4cc"><UploadFilled /></el-icon>
            <p style="font-size: 16px; margin-top: 12px">点击或拖拽 .p8 文件到此处</p>
            <p style="font-size: 13px; color: #909399; margin-top: 4px">
              Apple API 密钥文件 (AuthKey_XXXXXXXXXX.p8)
            </p>
          </div>
        </div>
        <input
          type="file"
          ref="importFileInput"
          accept=".p8,.pem,.key"
          style="display: none"
          @change="handleImportFileSelect"
        />
      </div>

      <!-- Step 2: Account info -->
      <div v-if="importStep === 1">
        <el-alert type="success" :closable="false" style="margin-bottom: 16px">
          <template #title>
            密钥文件已加载：{{ importData.filename }}
            <el-tag size="small" style="margin-left: 8px">{{ importData.key_type }}</el-tag>
          </template>
        </el-alert>
        <el-form :model="importForm" label-width="110px">
          <el-form-item label="账号名称" required>
            <el-input v-model="importForm.name" placeholder="例如：个人开发者账号" />
          </el-form-item>
          <el-form-item label="Issuer ID" required>
            <el-input v-model="importForm.issuer_id" placeholder="从 App Store Connect 获取" />
          </el-form-item>
          <el-form-item label="Key ID" required>
            <el-input v-model="importForm.key_id" :placeholder="guessedKeyId || 'API Key ID'" />
          </el-form-item>
        </el-form>
      </div>

      <!-- Step 3: Done -->
      <div v-if="importStep === 2" style="text-align: center; padding: 20px 0">
        <el-icon size="64" color="#67c23a"><CircleCheckFilled /></el-icon>
        <h3 style="margin-top: 16px">导入成功</h3>
        <p style="color: #606266; margin-top: 8px">账号「{{ importForm.name }}」已添加</p>
      </div>

      <template #footer>
        <el-button @click="showImportDialog = false">{{ importStep === 2 ? '关闭' : '取消' }}</el-button>
        <el-button v-if="importStep === 0" type="primary" :disabled="!importData.content" @click="importStep = 1">
          下一步
        </el-button>
        <el-button v-if="importStep === 1" @click="importStep = 0">上一步</el-button>
        <el-button v-if="importStep === 1" type="primary" @click="doImport" :loading="importing">
          导入
        </el-button>
      </template>
    </el-dialog>

    <!-- 账号详情 -->
    <el-dialog v-model="showDetailDialog" title="账号详细信息" width="750px" destroy-on-close>
      <div v-if="detailData" v-loading="detailLoading">
        <el-alert
          v-if="detailData.remote_synced"
          type="success"
          :closable="false"
          style="margin-bottom: 12px"
        >
          已从 Apple API 同步最新数据
        </el-alert>
        <el-alert
          v-else-if="detailData.remote_synced === false"
          type="warning"
          :closable="false"
          style="margin-bottom: 12px"
        >
          Apple API 同步失败，仅显示本地缓存数据
        </el-alert>
        <el-descriptions :column="2" border size="small" style="margin-bottom: 20px">
          <el-descriptions-item label="账号名称">{{ detailData.name }}</el-descriptions-item>
          <el-descriptions-item label="创建时间">{{ formatDate(detailData.created_at) }}</el-descriptions-item>
          <el-descriptions-item label="Issuer ID" :span="2">
            <code style="font-size: 12px">{{ detailData.issuer_id }}</code>
          </el-descriptions-item>
          <el-descriptions-item label="Key ID">
            <el-tag size="small">{{ detailData.key_id }}</el-tag>
          </el-descriptions-item>
        </el-descriptions>

        <!-- 统计卡片 -->
        <el-row :gutter="12" style="margin-bottom: 20px">
          <el-col :xs="12" :sm="6">
            <div class="detail-stat">
              <div class="detail-stat-num">{{ detailData.stats.certificates }}</div>
              <div class="detail-stat-label">证书
                <span v-if="detailData.stats.expired_certificates" class="stat-warn">
                  ({{ detailData.stats.expired_certificates }} 已过期)
                </span>
              </div>
            </div>
          </el-col>
          <el-col :xs="12" :sm="6">
            <div class="detail-stat">
              <div class="detail-stat-num">{{ detailData.stats.devices }}</div>
              <div class="detail-stat-label">设备
                <span class="stat-ok">({{ detailData.stats.active_devices }} 活跃)</span>
              </div>
            </div>
          </el-col>
          <el-col :xs="12" :sm="6">
            <div class="detail-stat">
              <div class="detail-stat-num">{{ detailData.stats.bundle_ids }}</div>
              <div class="detail-stat-label">Bundle ID</div>
            </div>
          </el-col>
          <el-col :xs="12" :sm="6">
            <div class="detail-stat">
              <div class="detail-stat-num">{{ detailData.stats.profiles }}</div>
              <div class="detail-stat-label">描述文件
                <span v-if="detailData.stats.expired_profiles" class="stat-warn">
                  ({{ detailData.stats.expired_profiles }} 已过期)
                </span>
              </div>
            </div>
          </el-col>
        </el-row>

        <!-- 证书列表 -->
        <el-collapse v-model="detailExpanded">
          <el-collapse-item title="证书" name="certs">
            <template #title>
              <span>证书 ({{ detailData.certificates.length }})</span>
            </template>
            <el-table :data="detailData.certificates" stripe size="small" empty-text="暂无" max-height="200">
              <el-table-column prop="name" label="名称" min-width="150" />
              <el-table-column prop="type" label="类型" width="140" />
              <el-table-column label="过期时间" width="110">
                <template #default="{ row }">
                  <span :style="{ color: isExpired(row.expires_at) ? '#f56c6c' : '' }">
                    {{ row.expires_at ? new Date(row.expires_at).toLocaleDateString() : '-' }}
                  </span>
                </template>
              </el-table-column>
            </el-table>
          </el-collapse-item>

          <el-collapse-item title="设备" name="devices">
            <template #title>
              <span>设备 ({{ detailData.devices.length }})</span>
            </template>
            <el-table :data="detailData.devices" stripe size="small" empty-text="暂无" max-height="200">
              <el-table-column prop="name" label="名称" min-width="120" />
              <el-table-column prop="udid" label="UDID" min-width="200">
                <template #default="{ row }">
                  <code style="font-size:11px">{{ row.udid }}</code>
                </template>
              </el-table-column>
              <el-table-column prop="platform" label="平台" width="70" />
              <el-table-column prop="status" label="状态" width="80">
                <template #default="{ row }">
                  <el-tag size="small" :type="row.status === 'ENABLED' ? 'success' : 'danger'">{{ row.status }}</el-tag>
                </template>
              </el-table-column>
            </el-table>
          </el-collapse-item>

          <el-collapse-item title="Bundle ID" name="bundles">
            <template #title>
              <span>Bundle ID ({{ detailData.bundle_ids.length }})</span>
            </template>
            <el-table :data="detailData.bundle_ids" stripe size="small" empty-text="暂无" max-height="200">
              <el-table-column prop="name" label="名称" width="120" />
              <el-table-column prop="identifier" label="标识符" min-width="220">
                <template #default="{ row }">
                  <code style="font-size:12px">{{ row.identifier }}</code>
                </template>
              </el-table-column>
              <el-table-column prop="platform" label="平台" width="70" />
            </el-table>
          </el-collapse-item>

          <el-collapse-item title="描述文件" name="profiles">
            <template #title>
              <span>描述文件 ({{ detailData.profiles.length }})</span>
            </template>
            <el-table :data="detailData.profiles" stripe size="small" empty-text="暂无" max-height="200">
              <el-table-column prop="name" label="名称" min-width="200" />
              <el-table-column prop="type" label="类型" width="160" />
              <el-table-column label="过期时间" width="110">
                <template #default="{ row }">
                  <span :style="{ color: isExpired(row.expires_at) ? '#f56c6c' : '' }">
                    {{ row.expires_at ? new Date(row.expires_at).toLocaleDateString() : '-' }}
                  </span>
                </template>
              </el-table-column>
            </el-table>
          </el-collapse-item>
        </el-collapse>
      </div>
      <template #footer>
        <el-button @click="showDetailDialog = false">关闭</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { accountApi } from '../api'
import { useAppStore } from '../stores/app'

const store = useAppStore()
const accounts = ref([])
const loading = ref(false)
const showDialog = ref(false)
const showImportDialog = ref(false)
const showDetailDialog = ref(false)
const detailLoading = ref(false)
const detailData = ref(null)
const detailExpanded = ref(['certs', 'devices'])
const saving = ref(false)
const importing = ref(false)
const editingId = ref(null)
const testingId = ref(null)
const isDragging = ref(false)
const p8FileName = ref('')
const p8KeyType = ref('')
const p8File = ref(null)
const showPasteMode = ref(false)
const pasteValidation = ref(null)
const importStep = ref(0)
const guessedKeyId = ref('')
const fileInput = ref(null)
const importFileInput = ref(null)

const form = ref({ name: '', issuer_id: '', key_id: '', private_key: '' })
const importForm = ref({ name: '', issuer_id: '', key_id: '' })
const importData = ref({ filename: '', key_type: '', content: '', file: null })

function formatDate(d) {
  return d ? new Date(d).toLocaleString('zh-CN') : '-'
}

async function fetchAccounts() {
  loading.value = true
  try {
    const res = await accountApi.list()
    accounts.value = res.data || []
    store.fetchAccounts()
  } finally {
    loading.value = false
  }
}

function openAddDialog() {
  editingId.value = null
  form.value = { name: '', issuer_id: '', key_id: '', private_key: '' }
  p8FileName.value = ''
  p8KeyType.value = ''
  p8File.value = null
  showPasteMode.value = false
  pasteValidation.value = null
  showDialog.value = true
}

function openImportDialog() {
  importStep.value = 0
  importForm.value = { name: '', issuer_id: '', key_id: '' }
  importData.value = { filename: '', key_type: '', content: '', file: null }
  guessedKeyId.value = ''
  showImportDialog.value = true
}

function editAccount(row) {
  editingId.value = row.id
  form.value = { name: row.name, issuer_id: row.issuer_id, key_id: row.key_id, private_key: '' }
  p8FileName.value = ''
  p8KeyType.value = ''
  p8File.value = null
  showPasteMode.value = false
  pasteValidation.value = null
  showDialog.value = true
}

async function processP8File(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = async (e) => {
      const content = e.target.result
      try {
        const res = await accountApi.validateP8(content)
        resolve({ content, validation: res.data, filename: file.name })
      } catch {
        resolve({ content, validation: { valid: false }, filename: file.name })
      }
    }
    reader.onerror = () => reject(new Error('文件读取失败'))
    reader.readAsText(file)
  })
}

function guessInfoFromFilename(filename) {
  const info = { keyId: '', name: '' }
  const patterns = [
    /AuthKey[_-]?(\w{8,12})\.p8/i,
    /^(\w{8,12})\.p8$/i,
    /[_-](\w{8,12})\.(p8|pem|key)$/i,
  ]
  for (const p of patterns) {
    const m = filename.match(p)
    if (m) { info.keyId = m[1]; break }
  }
  const nameBase = filename.replace(/\.(p8|pem|key)$/i, '').replace(/AuthKey[_-]?/i, '')
  if (nameBase && nameBase.length > 2) info.name = nameBase
  return info
}

async function handleDrop(e) {
  isDragging.value = false
  const file = e.dataTransfer.files[0]
  if (!file) return
  await loadP8ForDialog(file)
}

async function handleFileSelect(e) {
  const file = e.target.files[0]
  if (!file) return
  await loadP8ForDialog(file)
}

async function loadP8ForDialog(file) {
  const ext = file.name.split('.').pop().toLowerCase()
  if (!['p8', 'pem', 'key'].includes(ext)) {
    return ElMessage.warning('仅支持 .p8 / .pem / .key 格式')
  }
  try {
    const result = await processP8File(file)
    if (!result.validation.valid) {
      return ElMessage.error('无效的私钥文件')
    }
    p8FileName.value = file.name
    p8KeyType.value = result.validation.type
    p8File.value = file
    form.value.private_key = result.content
    showPasteMode.value = false

    const info = guessInfoFromFilename(file.name)
    if (info.keyId && !form.value.key_id) form.value.key_id = info.keyId
    if (info.name && !form.value.name) form.value.name = info.name
  } catch {
    ElMessage.error('文件处理失败')
  }
}

function clearP8File() {
  p8FileName.value = ''
  p8KeyType.value = ''
  p8File.value = null
  form.value.private_key = ''
}

async function validatePastedKey() {
  if (!form.value.private_key.trim()) {
    pasteValidation.value = null
    return
  }
  try {
    const res = await accountApi.validateP8(form.value.private_key)
    pasteValidation.value = res.data
  } catch {
    pasteValidation.value = { valid: false }
  }
}

async function handleImportDrop(e) {
  isDragging.value = false
  const file = e.dataTransfer.files[0]
  if (!file) return
  await loadP8ForImport(file)
}

async function handleImportFileSelect(e) {
  const file = e.target.files[0]
  if (!file) return
  await loadP8ForImport(file)
}

async function loadP8ForImport(file) {
  const ext = file.name.split('.').pop().toLowerCase()
  if (!['p8', 'pem', 'key'].includes(ext)) {
    return ElMessage.warning('仅支持 .p8 / .pem / .key 格式')
  }
  try {
    const result = await processP8File(file)
    if (!result.validation.valid) {
      return ElMessage.error('无效的私钥文件')
    }
    importData.value = {
      filename: file.name,
      key_type: result.validation.type,
      content: result.content,
      file
    }
    const info = guessInfoFromFilename(file.name)
    if (info.keyId) {
      guessedKeyId.value = info.keyId
      if (!importForm.value.key_id) importForm.value.key_id = info.keyId
    }
    if (info.name && !importForm.value.name) {
      importForm.value.name = info.name
    }
  } catch {
    ElMessage.error('文件处理失败')
  }
}

async function saveAccount() {
  if (!form.value.name || !form.value.issuer_id || !form.value.key_id) {
    return ElMessage.warning('请填写所有必填字段')
  }
  if (!editingId.value && !form.value.private_key) {
    return ElMessage.warning('请提供 Private Key（上传文件或手动粘贴）')
  }

  saving.value = true
  try {
    if (editingId.value) {
      const data = { ...form.value }
      if (!data.private_key) delete data.private_key
      await accountApi.update(editingId.value, data)
      ElMessage.success('更新成功')
    } else {
      await accountApi.create(form.value)
      ElMessage.success('添加成功')
    }
    showDialog.value = false
    editingId.value = null
    fetchAccounts()
  } finally {
    saving.value = false
  }
}

async function doImport() {
  if (!importForm.value.name || !importForm.value.issuer_id || !importForm.value.key_id) {
    return ElMessage.warning('请填写所有必填字段')
  }
  importing.value = true
  try {
    await accountApi.importP8({
      ...importForm.value,
      private_key: importData.value.content
    })
    importStep.value = 2
    fetchAccounts()
  } finally {
    importing.value = false
  }
}

async function deleteAccount(row) {
  await ElMessageBox.confirm(`确定删除账号「${row.name}」？`, '确认删除', { type: 'warning' })
  await accountApi.delete(row.id)
  ElMessage.success('删除成功')
  fetchAccounts()
}

async function viewDetail(row) {
  showDetailDialog.value = true
  detailLoading.value = true
  detailData.value = null
  try {
    const res = await accountApi.get(row.id)
    detailData.value = res.data
  } catch {
    ElMessage.error('获取详情失败')
  } finally {
    detailLoading.value = false
  }
}

function isExpired(dateStr) {
  if (!dateStr) return false
  return new Date(dateStr) < new Date()
}

function downloadP8(row) {
  window.open(accountApi.downloadP8(row.id), '_blank')
}

async function testConnection(id) {
  testingId.value = id
  try {
    const res = await accountApi.test(id)
    ElMessage.success(`API 连接成功，发现 ${res.data?.certificates_found || 0} 个证书`)
  } catch (err) {
    const data = err.response?.data
    const msg = data?.message || '连接失败'
    const tips = data?.data?.tips || []
    ElMessageBox.alert(
      `<div style="line-height:1.8">
        <p style="color:#f56c6c;font-weight:600;margin-bottom:8px">${msg}</p>
        <p style="font-weight:600;margin-bottom:4px">排查建议：</p>
        <ol style="padding-left:18px;color:#606266;font-size:13px">
          ${tips.map(t => `<li>${t}</li>`).join('')}
        </ol>
      </div>`,
      '连接测试失败',
      { dangerouslyUseHTMLString: true, confirmButtonText: '知道了' }
    )
  } finally {
    testingId.value = null
  }
}

onMounted(fetchAccounts)
</script>

<style scoped>
.p8-drop-zone {
  border: 2px dashed var(--cv-border);
  border-radius: var(--cv-radius-sm);
  padding: 20px;
  text-align: center;
  cursor: pointer;
  transition: all var(--cv-transition);
  background: var(--cv-surface-hover);
}

.p8-drop-zone:hover {
  border-color: var(--cv-blue);
  background: rgba(64,158,255,0.04);
}

.p8-drop-zone.drag-over {
  border-color: var(--cv-blue);
  background: rgba(64,158,255,0.08);
  box-shadow: 0 0 0 3px rgba(64,158,255,0.1);
}

.p8-drop-zone.has-file {
  border-color: var(--cv-green);
  background: rgba(34,197,94,0.04);
  border-style: solid;
}

.p8-drop-zone.large {
  padding: 40px 20px;
  min-height: 180px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
}

.p8-file-info {
  display: flex;
  align-items: center;
  gap: 10px;
}

.p8-filename {
  font-weight: 600;
  font-size: 14px;
  color: var(--cv-text);
  font-family: monospace;
}

.p8-placeholder p {
  margin: 0;
  color: var(--cv-text-muted);
  font-size: 14px;
}

.p8-actions {
  margin-top: 12px;
  display: flex;
  gap: 8px;
  justify-content: center;
}

.detail-stat {
  text-align: center;
  padding: 16px 8px;
  background: var(--cv-gradient-light);
  border-radius: var(--cv-radius-sm);
  border: 1px solid var(--cv-border-light);
}

.detail-stat-num {
  font-size: 28px;
  font-weight: 750;
  color: var(--cv-text);
  line-height: 1;
}

.detail-stat-label {
  font-size: 12px;
  color: var(--cv-text-secondary);
  margin-top: 6px;
}

.stat-warn { color: var(--cv-red); }
.stat-ok { color: var(--cv-green); }
</style>
