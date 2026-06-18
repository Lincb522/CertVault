<template>
  <div>
    <div class="page-header">
      <h1>证书检查</h1>
      <p>检查 P12 证书和描述文件的有效性，支持 ZIP 压缩包</p>
    </div>

    <!-- 上传区 -->
    <div class="content-card">
      <div
        class="drop-zone"
        :class="{ 'drag-over': dragging, 'has-files': selectedFiles.length > 0 }"
        @dragenter.prevent="dragging = true"
        @dragover.prevent="dragging = true"
        @dragleave.prevent="dragging = false"
        @drop.prevent="handleDrop"
        @click="$refs.fileInput.click()"
      >
        <input
          ref="fileInput"
          type="file"
          multiple
          accept=".p12,.pfx,.mobileprovision,.provisionprofile,.zip"
          style="display: none"
          @change="handleFileSelect"
        />
        <div v-if="selectedFiles.length === 0" class="drop-placeholder">
          <el-icon :size="48" color="var(--nask-text-muted)"><UploadFilled /></el-icon>
          <h3>拖拽文件到此处，或点击选择</h3>
          <p>支持 .p12 / .pfx / .mobileprovision / .zip 压缩包</p>
        </div>
        <div v-else class="file-list">
          <div v-for="(f, i) in selectedFiles" :key="i" class="file-item">
            <el-icon :size="20" :color="fileColor(f.name)"><Document /></el-icon>
            <span class="file-name">{{ f.name }}</span>
            <span class="file-size">{{ formatSize(f.size) }}</span>
            <el-button text type="danger" size="small" @click.stop="removeFile(i)">
              <el-icon><Close /></el-icon>
            </el-button>
          </div>
        </div>
      </div>

      <div class="check-options">
        <el-form :inline="true" label-width="auto" style="margin-bottom: 0">
          <el-form-item label="P12 密码">
            <el-input
              v-model="password"
              placeholder="留空自动尝试常用密码"
              type="password"
              show-password
              style="width: 260px"
            />
          </el-form-item>
          <el-form-item label="Apple 在线验证">
            <el-select v-model="accountId" placeholder="选择账号（可选）" clearable style="width: 240px">
              <el-option
                v-for="acc in accounts"
                :key="acc.id"
                :label="acc.name"
                :value="acc.id"
              />
            </el-select>
            <el-tooltip content="选择账号后，将通过 Apple API 验证证书和描述文件是否在 Apple 服务器上真实有效（非吊销/删除）" placement="top">
              <el-icon style="margin-left: 6px; color: var(--nask-text-muted); cursor: help"><QuestionFilled /></el-icon>
            </el-tooltip>
          </el-form-item>
        </el-form>
      </div>
      <div class="check-actions">
        <el-button
          type="primary"
          size="large"
          :loading="checking"
          :disabled="selectedFiles.length === 0"
          @click="doCheck"
        >
          <el-icon><CircleCheck /></el-icon>
          {{ accountId ? '在线检查' : '本地检查' }}
        </el-button>
        <el-button v-if="selectedFiles.length > 0" size="large" @click="clearAll">清空</el-button>
      </div>
    </div>

    <!-- 远程验证提示 -->
    <el-alert
      v-if="result && result.remote_verified"
      type="success"
      :closable="false"
      style="margin-bottom: 16px; border-radius: 12px"
    >
      <template #title>已通过 Apple 服务器在线验证</template>
      证书和描述文件已与 Apple Developer 服务器进行了实时比对，验证结果包含 Apple 端真实状态。
    </el-alert>
    <el-alert
      v-if="result && result.remote_error"
      type="warning"
      :closable="false"
      style="margin-bottom: 16px; border-radius: 12px"
    >
      <template #title>Apple 在线验证失败</template>
      {{ result.remote_error }}。以下结果仅为本地文件解析，未包含 Apple 服务器端状态。
    </el-alert>

    <!-- 结果展示 -->
    <template v-if="result">
      <!-- 匹配摘要 -->
      <div v-if="result.matches && result.matches.length > 0" class="content-card">
        <div class="card-header">
          <h3><el-icon size="18" style="vertical-align:middle;margin-right:6px"><Connection /></el-icon>证书 &amp; 描述文件匹配</h3>
        </div>
        <div class="match-list">
          <div v-for="(m, i) in result.matches" :key="i" class="match-card" :class="m.both_valid ? 'valid' : 'invalid'">
            <div class="match-icon">
              <el-icon :size="24" :color="m.both_valid ? '#10B981' : '#EF4444'">
                <component :is="m.both_valid ? 'CircleCheckFilled' : 'CircleCloseFilled'" />
              </el-icon>
            </div>
            <div class="match-info">
              <div class="match-title">{{ m.bundle_id || '未知 Bundle ID' }}</div>
              <div class="match-detail">
                <el-tag size="small" :type="m.cert_expired ? 'danger' : 'success'">证书: {{ m.cert_type }}</el-tag>
                <el-tag size="small" :type="m.profile_expired ? 'danger' : 'success'">描述文件: {{ m.profile_type }}</el-tag>
              </div>
              <div class="match-summary">{{ m.summary }}</div>
            </div>
          </div>
        </div>
      </div>

      <!-- P12 证书 -->
      <div v-if="result.p12 && result.p12.length > 0" class="content-card">
        <div class="card-header">
          <h3><el-icon size="18" style="vertical-align:middle;margin-right:6px"><Key /></el-icon>P12 证书 ({{ result.p12.length }})</h3>
        </div>
        <div v-for="(cert, i) in result.p12" :key="'c'+i" class="result-item">
          <div class="result-item-header" :class="cert.valid ? (cert.is_expired ? 'expired' : 'ok') : 'error'">
            <div class="result-file-name">
              <el-icon :size="20"><Document /></el-icon>
              {{ cert.file }}
            </div>
            <el-tag :type="cert.valid ? (cert.is_expired ? 'danger' : 'success') : 'danger'" effect="dark" round size="small">
              {{ cert.valid ? cert.status_text : '解析失败' }}
            </el-tag>
          </div>
          <div v-if="cert.valid" class="result-item-body">
            <div v-if="cert.apple_status" class="apple-verify-badge" :class="cert.apple_status">
              <el-icon><CircleCheckFilled v-if="cert.apple_status === 'active'" /><CircleCloseFilled v-else /></el-icon>
              {{ cert.apple_status_text }}
            </div>
            <div class="info-grid">
              <div class="info-cell">
                <span class="info-label">证书类型</span>
                <span class="info-value">{{ cert.type }}</span>
              </div>
              <div class="info-cell">
                <span class="info-label">私钥</span>
                <el-tag size="small" :type="cert.has_private_key ? 'success' : 'danger'" round>
                  {{ cert.has_private_key ? '✓ 包含' : '✕ 无' }}
                </el-tag>
              </div>
              <div class="info-cell">
                <span class="info-label">解锁密码</span>
                <code>{{ cert.password_used || '(空)' }}</code>
              </div>
              <div class="info-cell">
                <span class="info-label">证书数量</span>
                <span class="info-value">{{ cert.cert_count }}</span>
              </div>
              <div class="info-cell">
                <span class="info-label">生效日期</span>
                <span class="info-value">{{ formatDate(cert.not_before) }}</span>
              </div>
              <div class="info-cell">
                <span class="info-label">过期日期</span>
                <span class="info-value" :style="{ color: cert.is_expired ? '#EF4444' : '#10B981', fontWeight: 600 }">
                  {{ formatDate(cert.not_after) }}
                </span>
              </div>
            </div>
            <div class="cert-subject">
              <div class="subject-section">
                <span class="subject-title">主体 (Subject)</span>
                <div class="subject-items">
                  <span v-for="(v, k) in cert.subject" :key="k" class="subject-item">
                    <code>{{ k }}</code> {{ v }}
                  </span>
                </div>
              </div>
              <div class="subject-section">
                <span class="subject-title">签发者 (Issuer)</span>
                <div class="subject-items">
                  <span v-for="(v, k) in cert.issuer" :key="k" class="subject-item">
                    <code>{{ k }}</code> {{ v }}
                  </span>
                </div>
              </div>
            </div>
          </div>
          <div v-else class="result-item-body">
            <el-alert type="error" :closable="false">{{ cert.error }}</el-alert>
          </div>
        </div>
      </div>

      <!-- 描述文件 -->
      <div v-if="result.profiles && result.profiles.length > 0" class="content-card">
        <div class="card-header">
          <h3><el-icon size="18" style="vertical-align:middle;margin-right:6px"><Tickets /></el-icon>描述文件 ({{ result.profiles.length }})</h3>
        </div>
        <div v-for="(prof, i) in result.profiles" :key="'p'+i" class="result-item">
          <div class="result-item-header" :class="prof.valid ? (prof.is_expired ? 'expired' : 'ok') : 'error'">
            <div class="result-file-name">
              <el-icon :size="20"><Document /></el-icon>
              {{ prof.file }}
            </div>
            <el-tag :type="prof.valid ? (prof.is_expired ? 'danger' : 'success') : 'danger'" effect="dark" round size="small">
              {{ prof.valid ? prof.status_text : '解析失败' }}
            </el-tag>
          </div>
          <div v-if="prof.valid" class="result-item-body">
            <div v-if="prof.apple_status" class="apple-verify-badge" :class="prof.apple_status">
              <el-icon><CircleCheckFilled v-if="prof.apple_status === 'active'" /><CircleCloseFilled v-else /></el-icon>
              {{ prof.apple_status_text }}
            </div>
            <div class="info-grid">
              <div class="info-cell">
                <span class="info-label">名称</span>
                <span class="info-value">{{ prof.name }}</span>
              </div>
              <div class="info-cell">
                <span class="info-label">类型</span>
                <el-tag size="small" :type="profTypeTag(prof.type)">{{ prof.type }}</el-tag>
              </div>
              <div class="info-cell">
                <span class="info-label">Bundle ID</span>
                <code>{{ prof.bundle_id || '*' }}</code>
              </div>
              <div class="info-cell">
                <span class="info-label">Team</span>
                <span class="info-value">{{ prof.team_name }} ({{ prof.team_id }})</span>
              </div>
              <div class="info-cell">
                <span class="info-label">UUID</span>
                <code style="font-size:11px">{{ prof.uuid }}</code>
              </div>
              <div class="info-cell">
                <span class="info-label">设备数量</span>
                <span class="info-value">{{ prof.provisions_all_devices ? '所有设备 (Enterprise)' : prof.device_count }}</span>
              </div>
              <div class="info-cell">
                <span class="info-label">创建日期</span>
                <span class="info-value">{{ formatDate(prof.creation_date) }}</span>
              </div>
              <div class="info-cell">
                <span class="info-label">过期日期</span>
                <span class="info-value" :style="{ color: prof.is_expired ? '#EF4444' : '#10B981', fontWeight: 600 }">
                  {{ formatDate(prof.expiration_date) }}
                </span>
              </div>
            </div>
            <div v-if="prof.devices.length > 0 && !prof.provisions_all_devices" class="device-list-section">
              <span class="subject-title" @click="prof._showDevices = !prof._showDevices" style="cursor:pointer">
                已注册设备 ({{ prof.device_count }})
                <el-icon :size="12"><ArrowDown v-if="!prof._showDevices" /><ArrowUp v-else /></el-icon>
              </span>
              <div v-if="prof._showDevices" class="device-udid-list">
                <code v-for="d in prof.devices" :key="d">{{ d }}</code>
              </div>
            </div>
          </div>
          <div v-else class="result-item-body">
            <el-alert type="error" :closable="false">{{ prof.error }}</el-alert>
          </div>
        </div>
      </div>

      <!-- 错误 -->
      <div v-if="result.errors && result.errors.length > 0" class="content-card">
        <div class="card-header">
          <h3 style="color: var(--nask-red)">
            <el-icon size="18" style="vertical-align:middle;margin-right:6px"><WarningFilled /></el-icon>
            错误 ({{ result.errors.length }})
          </h3>
        </div>
        <el-alert v-for="(e, i) in result.errors" :key="i" type="error" :title="e.file" :description="e.error" :closable="false" style="margin-bottom: 8px" />
      </div>
    </template>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { certCheckApi, accountApi } from '../api'

const dragging = ref(false)
const selectedFiles = ref([])
const password = ref('')
const accountId = ref('')
const accounts = ref([])
const checking = ref(false)
const result = ref(null)

function handleDrop(e) {
  dragging.value = false
  const files = [...e.dataTransfer.files]
  addFiles(files)
}

function handleFileSelect(e) {
  addFiles([...e.target.files])
  e.target.value = ''
}

function addFiles(files) {
  const valid = files.filter(f => {
    const ext = f.name.split('.').pop().toLowerCase()
    return ['p12', 'pfx', 'mobileprovision', 'provisionprofile', 'zip'].includes(ext)
  })
  if (valid.length < files.length) {
    ElMessage.warning('已忽略不支持的文件类型')
  }
  selectedFiles.value.push(...valid)
}

function removeFile(index) {
  selectedFiles.value.splice(index, 1)
}

function clearAll() {
  selectedFiles.value = []
  result.value = null
}

function fileColor(name) {
  const ext = name.split('.').pop().toLowerCase()
  if (ext === 'p12' || ext === 'pfx') return '#3B82F6'
  if (ext === 'mobileprovision' || ext === 'provisionprofile') return '#10B981'
  if (ext === 'zip') return '#F59E0B'
  return '#6B7280'
}

function formatSize(bytes) {
  if (bytes < 1024) return bytes + ' B'
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB'
  return (bytes / (1024 * 1024)).toFixed(1) + ' MB'
}

function formatDate(d) {
  if (!d) return '-'
  return new Date(d).toLocaleString('zh-CN', { year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' })
}

function profTypeTag(type) {
  if (type === 'Development') return 'primary'
  if (type === 'Ad Hoc') return 'warning'
  if (type === 'App Store') return 'success'
  if (type.includes('Enterprise')) return 'danger'
  return 'info'
}

async function doCheck() {
  checking.value = true
  result.value = null
  try {
    const res = await certCheckApi.validate(selectedFiles.value, password.value, accountId.value)
    const data = res.data || res
    if (data.profiles) {
      data.profiles.forEach(p => { p._showDevices = false })
    }
    result.value = data
    ElMessage.success(res.message || '检查完成')
  } catch (err) {
    ElMessage.error(err.response?.data?.message || '检查失败')
  } finally {
    checking.value = false
  }
}

async function fetchAccounts() {
  try {
    const res = await accountApi.list()
    accounts.value = res.data || []
  } catch {}
}

onMounted(fetchAccounts)
</script>

<style scoped>
.drop-zone {
  border: 2px dashed var(--nask-border);
  border-radius: 16px;
  padding: 40px 20px;
  text-align: center;
  cursor: pointer;
  transition: all 0.2s;
  background: var(--nask-surface-hover);
  min-height: 160px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.drop-zone:hover,
.drop-zone.drag-over {
  border-color: var(--nask-blue);
  background: rgba(6, 109, 230, 0.04);
  box-shadow: 0 0 0 3px rgba(6, 109, 230, 0.08);
}

.drop-zone.has-files {
  border-style: solid;
  padding: 16px 20px;
  min-height: auto;
}

.drop-placeholder h3 {
  margin: 12px 0 4px;
  font-size: 16px;
  font-weight: 600;
  color: var(--nask-text);
}

.drop-placeholder p {
  margin: 0;
  font-size: 13px;
  color: var(--nask-text-muted);
}

.file-list {
  width: 100%;
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.file-item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 8px 12px;
  border-radius: 8px;
  background: var(--nask-surface);
  border: 1px solid var(--nask-border);
  text-align: left;
}

.file-name {
  font-weight: 600;
  font-size: 13px;
  color: var(--nask-text);
  flex: 1;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.file-size {
  font-size: 12px;
  color: var(--nask-text-muted);
  flex-shrink: 0;
}

.check-actions {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-top: 20px;
  flex-wrap: wrap;
}

/* ===== Results ===== */
.match-list {
  display: flex;
  flex-direction: column;
  gap: 10px;
  margin-top: 12px;
}

.match-card {
  display: flex;
  align-items: flex-start;
  gap: 14px;
  padding: 16px;
  border-radius: 12px;
  border: 1px solid;
}

.match-card.valid {
  background: rgba(16, 185, 129, 0.04);
  border-color: rgba(16, 185, 129, 0.2);
}

.match-card.invalid {
  background: rgba(239, 68, 68, 0.04);
  border-color: rgba(239, 68, 68, 0.2);
}

.match-icon {
  flex-shrink: 0;
  margin-top: 2px;
}

.match-title {
  font-weight: 700;
  font-size: 14px;
  color: var(--nask-text);
  margin-bottom: 6px;
}

.match-detail {
  display: flex;
  gap: 6px;
  flex-wrap: wrap;
  margin-bottom: 4px;
}

.match-summary {
  font-size: 13px;
  color: var(--nask-text-secondary);
}

.result-item {
  border: 1px solid var(--nask-border);
  border-radius: 12px;
  overflow: hidden;
  margin-top: 12px;
}

.result-item-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 12px 16px;
  gap: 12px;
}

.result-item-header.ok {
  background: linear-gradient(135deg, rgba(16, 185, 129, 0.06), rgba(16, 185, 129, 0.02));
}

.result-item-header.expired {
  background: linear-gradient(135deg, rgba(239, 68, 68, 0.06), rgba(239, 68, 68, 0.02));
}

.result-item-header.error {
  background: linear-gradient(135deg, rgba(239, 68, 68, 0.08), rgba(239, 68, 68, 0.03));
}

.result-file-name {
  display: flex;
  align-items: center;
  gap: 8px;
  font-weight: 600;
  font-size: 14px;
  color: var(--nask-text);
}

.result-item-body {
  padding: 16px;
}

.info-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
  gap: 12px;
}

.info-cell {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.info-label {
  font-size: 11px;
  font-weight: 600;
  color: var(--nask-text-secondary);
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.info-value {
  font-size: 13px;
  color: var(--nask-text);
}

.info-cell code {
  font-size: 12px;
  background: var(--nask-surface-hover);
  padding: 2px 8px;
  border-radius: 4px;
  width: fit-content;
}

.cert-subject {
  margin-top: 14px;
  padding-top: 14px;
  border-top: 1px solid var(--nask-border);
  display: flex;
  gap: 24px;
  flex-wrap: wrap;
}

.subject-section {
  flex: 1;
  min-width: 200px;
}

.subject-title {
  font-size: 11px;
  font-weight: 700;
  color: var(--nask-text-secondary);
  text-transform: uppercase;
  letter-spacing: 0.5px;
  display: flex;
  align-items: center;
  gap: 4px;
  margin-bottom: 6px;
}

.subject-items {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.subject-item {
  font-size: 13px;
  color: var(--nask-text);
}

.subject-item code {
  font-size: 11px;
  background: var(--nask-surface-hover);
  padding: 1px 6px;
  border-radius: 4px;
  margin-right: 6px;
  color: var(--nask-text-secondary);
}

.device-list-section {
  margin-top: 14px;
  padding-top: 14px;
  border-top: 1px solid var(--nask-border);
}

.device-udid-list {
  display: flex;
  flex-direction: column;
  gap: 3px;
  margin-top: 8px;
  max-height: 200px;
  overflow-y: auto;
}

.device-udid-list code {
  font-size: 11px;
  background: var(--nask-surface-hover);
  padding: 4px 8px;
  border-radius: 4px;
  color: var(--nask-text);
}

.check-options {
  margin-top: 16px;
  padding-top: 16px;
  border-top: 1px solid var(--nask-border);
}

.apple-verify-badge {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 8px 14px;
  border-radius: 8px;
  font-size: 13px;
  font-weight: 600;
  margin-bottom: 14px;
}

.apple-verify-badge.active {
  background: rgba(16, 185, 129, 0.08);
  color: #059669;
  border: 1px solid rgba(16, 185, 129, 0.2);
}

.apple-verify-badge.not_found,
.apple-verify-badge.invalid {
  background: rgba(239, 68, 68, 0.06);
  color: #DC2626;
  border: 1px solid rgba(239, 68, 68, 0.2);
}
</style>
