<template>
  <div>
    <div class="page-header">
      <h1>设备管理</h1>
      <p>管理已注册的 Apple 测试设备，支持一键绑定自动生成证书和描述文件</p>
    </div>

    <div class="content-card">
      <div class="card-header">
        <h3>设备列表</h3>
        <div>
          <el-button type="warning" @click="openAutoBindDialog" :disabled="!store.currentAccountId">
            <el-icon><MagicStick /></el-icon> 一键绑定
          </el-button>
          <el-button type="primary" @click="showAddDialog = true" :disabled="!store.currentAccountId">
            <el-icon><Plus /></el-icon> 添加设备
          </el-button>
          <el-button @click="showBatchDialog = true" :disabled="!store.currentAccountId">
            <el-icon><Upload /></el-icon> 批量导入
          </el-button>
        </div>
      </div>

      <div v-if="!store.currentAccountId" class="empty-state">
        <el-icon><Warning /></el-icon>
        <p>请先在左侧选择一个账号</p>
      </div>

      <el-table v-else :data="devices" stripe v-loading="loading" empty-text="暂无设备" @expand-change="onExpandDevice" row-key="id">
        <el-table-column type="expand">
          <template #default="{ row }">
            <div v-if="row._profiles?.length" style="padding: 8px 20px">
              <div v-for="p in row._profiles" :key="p.id" class="device-profile-item">
                <el-tag size="small" :type="p.state === 'ACTIVE' ? 'success' : 'danger'">{{ p.state === 'ACTIVE' ? '有效' : p.state }}</el-tag>
                <strong>{{ p.name }}</strong>
                <el-tag size="small" effect="plain" type="info">{{ p.type }}</el-tag>
                <span v-if="p.bundle" style="color:#909399;font-size:12px;margin-left:4px">{{ p.bundle.identifier }}</span>
                <span style="color:#909399;font-size:12px;margin-left:auto">
                  证书: {{ p.certificates.map(c => c.name || c.type).join(', ') || '-' }}
                </span>
              </div>
            </div>
            <div v-else-if="row._loadingProfiles" style="padding:12px 20px;color:#909399">加载中...</div>
            <div v-else style="padding:12px 20px;color:#909399">该设备未关联任何描述文件</div>
          </template>
        </el-table-column>
        <el-table-column prop="name" label="设备名称" min-width="130" />
        <el-table-column prop="udid" label="UDID" min-width="240">
          <template #default="{ row }">
            <el-text size="small" style="font-family: monospace">{{ row.udid }}</el-text>
          </template>
        </el-table-column>
        <el-table-column prop="platform" label="平台" width="70">
          <template #default="{ row }">
            <el-tag size="small" :type="row.platform === 'IOS' ? 'primary' : 'success'">{{ row.platform }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="status" label="状态" width="70">
          <template #default="{ row }">
            <el-tag size="small" :type="row.status === 'ENABLED' ? 'success' : 'danger'">{{ row.status }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="描述文件" width="90" align="center">
          <template #default="{ row }">
            <el-tag v-if="row._profileCount > 0" size="small" type="success">{{ row._profileCount }} 个</el-tag>
            <el-tag v-else-if="row._profileCount === 0" size="small" type="info">0</el-tag>
            <span v-else style="color:#c0c4cc">-</span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="260" fixed="right">
          <template #default="{ row }">
            <el-button size="small" type="primary" @click="showResources(row)">
              <el-icon><Download /></el-icon> 下载资源
            </el-button>
            <el-button size="small" @click="downloadAll(row)">
              <el-icon><FolderOpened /></el-icon> 打包下载
            </el-button>
          </template>
        </el-table-column>
      </el-table>
    </div>

    <!-- 添加设备 -->
    <el-dialog v-model="showAddDialog" title="添加设备" width="480px" destroy-on-close>
      <el-form :model="addForm" label-width="80px">
        <el-form-item label="设备名称" required>
          <el-input v-model="addForm.name" placeholder="例如：iPhone 15 Pro" />
        </el-form-item>
        <el-form-item label="UDID" required>
          <el-input v-model="addForm.udid" placeholder="设备 UDID" />
        </el-form-item>
        <el-form-item label="平台">
          <el-select v-model="addForm.platform" style="width: 100%">
            <el-option label="iOS" value="IOS" />
            <el-option label="macOS" value="MAC_OS" />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showAddDialog = false">取消</el-button>
        <el-button type="primary" @click="addDevice" :loading="adding">确认添加</el-button>
      </template>
    </el-dialog>

    <!-- 批量导入 -->
    <el-dialog v-model="showBatchDialog" title="批量导入设备" width="560px" destroy-on-close>
      <el-alert type="info" :closable="false" style="margin-bottom: 16px">
        每行一个设备，格式：UDID,设备名称 或 UDID\t设备名称
      </el-alert>
      <el-input
        v-model="batchText"
        type="textarea"
        :rows="8"
        placeholder="00008110-001A28EE3A68801E,iPhone 15 Pro&#10;00008030-001C28123456801E,iPad Air"
      />
      <template #footer>
        <el-button @click="showBatchDialog = false">取消</el-button>
        <el-button type="primary" @click="batchImport" :loading="importing">导入</el-button>
      </template>
    </el-dialog>

    <!-- 一键绑定 -->
    <el-dialog
      v-model="showAutoBindDialog"
      title="一键绑定"
      width="640px"
      destroy-on-close
      :close-on-click-modal="false"
    >
      <el-alert type="info" :closable="false" style="margin-bottom: 20px">
        自动完成以下操作：注册设备 → 创建/复用证书 → 创建/查找 Bundle ID → 生成描述文件
      </el-alert>

      <!-- 表单 -->
      <div v-if="!autoBindResult">
        <el-form :model="autoBindForm" label-width="110px">
          <el-divider content-position="left">设备信息</el-divider>
          <el-form-item label="设备名称" required>
            <el-input v-model="autoBindForm.name" placeholder="例如：iPhone 15 Pro" />
          </el-form-item>
          <el-form-item label="UDID" required>
            <el-input v-model="autoBindForm.udid" placeholder="设备 UDID" />
          </el-form-item>
          <el-form-item label="平台">
            <el-select v-model="autoBindForm.platform" style="width: 100%">
              <el-option label="iOS" value="IOS" />
              <el-option label="macOS" value="MAC_OS" />
            </el-select>
          </el-form-item>

          <el-divider content-position="left">应用信息</el-divider>
          <el-form-item label="Bundle ID" required>
            <el-input v-model="autoBindForm.bundle_identifier" placeholder="例如：com.example.myapp" />
          </el-form-item>
          <el-form-item label="应用名称">
            <el-input v-model="autoBindForm.bundle_name" placeholder="可选，默认从 Bundle ID 提取" />
          </el-form-item>

          <el-divider content-position="left">证书配置</el-divider>
          <el-form-item label="证书类型">
            <el-select v-model="autoBindForm.cert_type" style="width: 100%">
              <el-option value="IOS_DEVELOPMENT">
                <span>iOS 开发证书</span>
                <span style="color:#909399; font-size:12px; float:right">真机调试</span>
              </el-option>
              <el-option value="IOS_DISTRIBUTION">
                <span>iOS 发布证书</span>
                <span style="color:#909399; font-size:12px; float:right">App Store / Ad Hoc</span>
              </el-option>
            </el-select>
          </el-form-item>
          <el-form-item label="描述文件类型">
            <el-select v-model="autoBindForm.profile_type" style="width: 100%">
              <el-option value="IOS_APP_DEVELOPMENT">
                <span>iOS 开发描述文件</span>
                <span style="color:#909399; font-size:12px; float:right">真机调试，需选设备</span>
              </el-option>
              <el-option value="IOS_APP_ADHOC">
                <span>iOS Ad Hoc 描述文件</span>
                <span style="color:#909399; font-size:12px; float:right">测试分发，最多100台</span>
              </el-option>
              <el-option value="IOS_APP_STORE">
                <span>iOS App Store 描述文件</span>
                <span style="color:#909399; font-size:12px; float:right">提交审核发布</span>
              </el-option>
              <el-option value="IOS_APP_INHOUSE">
                <span>iOS 企业内部描述文件</span>
                <span style="color:#909399; font-size:12px; float:right">企业账号，无限设备</span>
              </el-option>
            </el-select>
          </el-form-item>
          <el-form-item label="P12 密码">
            <el-input v-model="autoBindForm.password" placeholder="默认 123456" />
          </el-form-item>
        </el-form>
      </div>

      <!-- 结果 -->
      <div v-else>
        <el-result
          :icon="autoBindResult.success ? 'success' : 'error'"
          :title="autoBindResult.success ? '一键绑定完成' : '绑定失败'"
          :sub-title="autoBindResult.message"
        />

        <div v-if="autoBindResult.success" class="bind-steps">
          <el-timeline>
            <el-timeline-item
              v-for="step in autoBindResult.data.steps"
              :key="step.step"
              :type="step.status === 'success' ? 'success' : step.status === 'skipped' ? 'info' : 'danger'"
              :hollow="step.status === 'skipped'"
            >
              <div class="step-item">
                <span class="step-label">{{ stepLabels[step.step] }}</span>
                <el-tag size="small" :type="step.status === 'success' ? 'success' : 'info'" style="margin-left: 8px">
                  {{ step.status === 'success' ? '完成' : '已有' }}
                </el-tag>
              </div>
              <div class="step-message">{{ step.message }}</div>
            </el-timeline-item>
          </el-timeline>

          <el-divider />

          <div class="result-password" v-if="autoBindResult.data.certificate?.password">
            <el-icon color="#e6a23c"><Key /></el-icon>
            <span>P12 密码：</span>
            <code class="password-text">{{ autoBindResult.data.certificate.password }}</code>
            <el-button size="small" text type="primary" @click="copyText(autoBindResult.data.certificate.password)">复制</el-button>
          </div>

          <div class="result-actions">
            <el-button type="primary" @click="downloadResultCert">
              <el-icon><Download /></el-icon> 下载 P12 证书
            </el-button>
            <el-button type="success" @click="downloadResultProfile">
              <el-icon><Download /></el-icon> 下载描述文件
            </el-button>
            <el-button type="warning" @click="downloadResultBundle">
              <el-icon><FolderOpened /></el-icon> 打包下载全部
            </el-button>
          </div>
        </div>
      </div>

      <template #footer>
        <el-button @click="closeAutoBindDialog">{{ autoBindResult ? '关闭' : '取消' }}</el-button>
        <el-button
          v-if="!autoBindResult"
          type="warning"
          @click="doAutoBind"
          :loading="autoBinding"
        >
          <el-icon><MagicStick /></el-icon> 开始一键绑定
        </el-button>
        <el-button v-if="autoBindResult?.success" type="primary" @click="resetAutoBind">
          继续绑定下一台
        </el-button>
      </template>
    </el-dialog>

    <!-- 设备关联资源 -->
    <el-dialog v-model="showResourceDialog" title="设备关联资源" width="680px" destroy-on-close>
      <div v-if="resourceData" v-loading="resourceLoading">
        <el-descriptions :column="2" border size="small" style="margin-bottom: 16px">
          <el-descriptions-item label="设备名称">{{ resourceData.device.name }}</el-descriptions-item>
          <el-descriptions-item label="UDID">
            <code style="font-size:12px">{{ resourceData.device.udid }}</code>
          </el-descriptions-item>
        </el-descriptions>
        <el-alert
          v-if="resourceData.has_bindlinks"
          type="success"
          :closable="false"
          style="margin-bottom: 12px"
        >
          以下为该设备通过「一键绑定」生成的关联证书和描述文件
          <span v-if="resourceData.bundle_ids?.length"> ({{ resourceData.bundle_ids.join(', ') }})</span>
        </el-alert>
        <el-alert
          v-else
          type="info"
          :closable="false"
          style="margin-bottom: 12px"
        >
          该设备暂无绑定记录，显示账号下所有证书和描述文件
        </el-alert>

        <h4 style="margin: 16px 0 8px">证书 ({{ resourceData.certificates.length }})</h4>
        <el-table :data="resourceData.certificates" stripe size="small" empty-text="暂无证书">
          <el-table-column prop="name" label="名称" min-width="150" />
          <el-table-column prop="type" label="类型" width="140" />
          <el-table-column label="密码" width="120">
            <template #default="{ row }">
              <code class="password-text">{{ row.password || '123456' }}</code>
              <el-button size="small" text type="primary" @click="copyText(row.password || '123456')">
                <el-icon><CopyDocument /></el-icon>
              </el-button>
            </template>
          </el-table-column>
          <el-table-column label="过期" width="100">
            <template #default="{ row }">
              {{ row.expires_at ? new Date(row.expires_at).toLocaleDateString() : '-' }}
            </template>
          </el-table-column>
          <el-table-column label="操作" width="80">
            <template #default="{ row }">
              <el-button v-if="row.has_p12" size="small" type="primary" link @click="downloadCert(row.id)">
                <el-icon><Download /></el-icon> P12
              </el-button>
            </template>
          </el-table-column>
        </el-table>

        <h4 style="margin: 16px 0 8px">描述文件 ({{ resourceData.profiles.length }})</h4>
        <el-table :data="resourceData.profiles" stripe size="small" empty-text="暂无描述文件">
          <el-table-column prop="name" label="名称" min-width="200" />
          <el-table-column prop="type" label="类型" width="160" />
          <el-table-column label="过期" width="100">
            <template #default="{ row }">
              {{ row.expires_at ? new Date(row.expires_at).toLocaleDateString() : '-' }}
            </template>
          </el-table-column>
          <el-table-column label="操作" width="80">
            <template #default="{ row }">
              <el-button v-if="row.has_file" size="small" type="success" link @click="downloadProfile(row.id)">
                <el-icon><Download /></el-icon>
              </el-button>
            </template>
          </el-table-column>
        </el-table>
      </div>
      <template #footer>
        <el-button @click="showResourceDialog = false">关闭</el-button>
        <el-button type="warning" @click="downloadAll(currentResourceDevice)">
          <el-icon><FolderOpened /></el-icon> 打包下载全部
        </el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, watch, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { deviceApi, certApi, profileApi } from '../api'

let cachedRelations = null
import { useAppStore } from '../stores/app'

const store = useAppStore()
const devices = ref([])
const loading = ref(false)
const showAddDialog = ref(false)
const showBatchDialog = ref(false)
const showAutoBindDialog = ref(false)
const showResourceDialog = ref(false)
const adding = ref(false)
const importing = ref(false)
const autoBinding = ref(false)
const resourceLoading = ref(false)
const batchText = ref('')
const autoBindResult = ref(null)
const resourceData = ref(null)
const currentResourceDevice = ref(null)

const addForm = ref({ name: '', udid: '', platform: 'IOS' })
const autoBindForm = ref({
  name: '', udid: '', platform: 'IOS',
  bundle_identifier: '', bundle_name: '',
  cert_type: 'IOS_DEVELOPMENT',
  profile_type: 'IOS_APP_DEVELOPMENT',
  password: '123456'
})

const stepLabels = {
  register_device: '注册设备',
  create_certificate: '创建证书',
  create_bundle_id: '创建 Bundle ID',
  create_profile: '生成描述文件'
}

function formatDate(d) {
  return d ? new Date(d).toLocaleString('zh-CN') : '-'
}

async function fetchDevices() {
  if (!store.currentAccountId) return
  loading.value = true
  try {
    const res = await deviceApi.list(store.currentAccountId)
    devices.value = (res.data || []).map(d => ({ ...d, _profileCount: null, _profiles: null, _loadingProfiles: false }))
    loadDeviceRelations()
  } finally {
    loading.value = false
  }
}

async function loadDeviceRelations() {
  if (!store.currentAccountId) return
  try {
    const res = await certApi.relations(store.currentAccountId)
    cachedRelations = res.data || []
    for (const dev of devices.value) {
      const devId = dev.apple_id || dev.id
      const matched = cachedRelations.filter(p =>
        p.devices.some(d => d.id === devId || d.udid === dev.udid)
      )
      dev._profileCount = matched.length
      dev._profiles = matched
    }
  } catch {
    cachedRelations = null
  }
}

function onExpandDevice(row, expandedRows) {
  if (!row._profiles && cachedRelations) {
    const devId = row.apple_id || row.id
    row._profiles = cachedRelations.filter(p =>
      p.devices.some(d => d.id === devId || d.udid === row.udid)
    )
    row._profileCount = row._profiles.length
  }
}

async function addDevice() {
  if (!addForm.value.name || !addForm.value.udid) {
    return ElMessage.warning('请填写设备名称和 UDID')
  }
  adding.value = true
  try {
    await deviceApi.register({ account_id: store.currentAccountId, ...addForm.value })
    ElMessage.success('设备添加成功')
    showAddDialog.value = false
    addForm.value = { name: '', udid: '', platform: 'IOS' }
    fetchDevices()
  } finally {
    adding.value = false
  }
}

async function batchImport() {
  const lines = batchText.value.trim().split('\n').filter(Boolean)
  if (!lines.length) return ElMessage.warning('请输入设备信息')

  const devicesList = lines.map(line => {
    const parts = line.split(/[,\t]/).map(s => s.trim())
    return { udid: parts[0], name: parts[1] || `Device-${parts[0].slice(-6)}` }
  })

  importing.value = true
  try {
    const res = await deviceApi.batchRegister({
      account_id: store.currentAccountId,
      devices: devicesList
    })
    const successCount = res.data?.results?.length || 0
    const errorCount = res.data?.errors?.length || 0
    ElMessage.success(`导入完成：成功 ${successCount}，失败 ${errorCount}`)
    showBatchDialog.value = false
    batchText.value = ''
    fetchDevices()
  } finally {
    importing.value = false
  }
}

function openAutoBindDialog() {
  autoBindResult.value = null
  autoBindForm.value = {
    name: '', udid: '', platform: 'IOS',
    bundle_identifier: '', bundle_name: '',
    cert_type: 'IOS_DEVELOPMENT',
    profile_type: 'IOS_APP_DEVELOPMENT',
    password: '123456'
  }
  showAutoBindDialog.value = true
}

function closeAutoBindDialog() {
  showAutoBindDialog.value = false
  if (autoBindResult.value?.success) fetchDevices()
}

function resetAutoBind() {
  autoBindResult.value = null
  autoBindForm.value.name = ''
  autoBindForm.value.udid = ''
}

async function doAutoBind() {
  const f = autoBindForm.value
  if (!f.name || !f.udid || !f.bundle_identifier) {
    return ElMessage.warning('请填写设备名称、UDID 和 Bundle ID')
  }

  autoBinding.value = true
  try {
    const res = await deviceApi.autoBindAll({
      account_id: store.currentAccountId,
      ...f
    })
    autoBindResult.value = res
  } catch (err) {
    autoBindResult.value = {
      success: false,
      message: err.response?.data?.message || err.message || '绑定失败'
    }
  } finally {
    autoBinding.value = false
  }
}

function downloadResultCert() {
  if (autoBindResult.value?.data?.certificate?.id) {
    window.open(certApi.download(autoBindResult.value.data.certificate.id), '_blank')
  }
}

function downloadResultProfile() {
  if (autoBindResult.value?.data?.profile?.id) {
    window.open(profileApi.download(autoBindResult.value.data.profile.id), '_blank')
  }
}

function downloadResultBundle() {
  const d = autoBindResult.value?.data
  if (!d?.device?.apple_id) return
  const url = deviceApi.downloadBundle(d.device.apple_id, d.certificate?.id, d.profile?.id)
  window.open(url, '_blank')
}

async function showResources(row) {
  currentResourceDevice.value = row
  showResourceDialog.value = true
  resourceLoading.value = true
  resourceData.value = null
  try {
    const res = await deviceApi.resources(row.id || row.apple_id)
    resourceData.value = res.data
  } catch {
    ElMessage.error('获取资源失败')
  } finally {
    resourceLoading.value = false
  }
}

function downloadCert(certId) {
  window.open(certApi.download(certId), '_blank')
}

function downloadProfile(profileId) {
  window.open(profileApi.download(profileId), '_blank')
}

function downloadAll(row) {
  if (!row) return
  const url = deviceApi.downloadBundle(row.id || row.apple_id)
  window.open(url, '_blank')
}

function copyText(text) {
  navigator.clipboard.writeText(text)
  ElMessage.success('已复制到剪贴板')
}

watch(() => store.currentAccountId, fetchDevices)
onMounted(fetchDevices)
</script>

<style scoped>
.bind-steps {
  margin-top: 16px;
}

.step-item {
  display: flex;
  align-items: center;
}

.step-label {
  font-weight: 600;
  font-size: 14px;
}

.step-message {
  color: var(--cv-text-secondary);
  font-size: 13px;
  margin-top: 4px;
}

.result-password {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 14px 16px;
  background: linear-gradient(135deg, rgba(245,158,11,0.06), rgba(245,158,11,0.1));
  border: 1px solid rgba(245,158,11,0.3);
  border-radius: var(--cv-radius-sm);
  margin-bottom: 16px;
  font-size: 14px;
}

.password-text {
  background: var(--cv-surface);
  padding: 2px 10px;
  border-radius: 6px;
  font-family: 'SF Mono', Monaco, Menlo, Consolas, monospace;
  font-size: 15px;
  font-weight: 600;
  color: var(--cv-text);
  letter-spacing: 1px;
}

.result-actions {
  display: flex;
  gap: 12px;
  justify-content: center;
  flex-wrap: wrap;
}

@media (max-width: 768px) {
  .result-actions {
    flex-direction: column;
  }

  .result-password {
    flex-wrap: wrap;
    font-size: 13px;
  }
}

.device-profile-item {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 0;
  border-bottom: 1px solid var(--cv-border-light);
  font-size: 13px;
}

.device-profile-item:last-child {
  border-bottom: none;
}
</style>
