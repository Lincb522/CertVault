<template>
  <div>
    <div class="page-header">
      <h1>描述文件</h1>
      <p>管理 Bundle ID 和 Provisioning Profiles</p>
    </div>

    <!-- Bundle IDs -->
    <div class="content-card">
      <div class="card-header">
        <h3>Bundle ID</h3>
        <div>
          <el-button type="primary" size="small" @click="showBundleDialog = true" :disabled="!store.currentAccountId">
            <el-icon><Plus /></el-icon> 创建 Bundle ID
          </el-button>
          <el-button size="small" @click="fetchBundleIds" :disabled="!store.currentAccountId">
            <el-icon><Refresh /></el-icon> 刷新
          </el-button>
        </div>
      </div>
      <el-table :data="bundleIds" stripe v-loading="loadingBundles" size="small" empty-text="暂无 Bundle ID">
        <el-table-column prop="name" label="名称" min-width="150" />
        <el-table-column prop="identifier" label="标识符" min-width="250">
          <template #default="{ row }">
            <el-text style="font-family: monospace">{{ row.identifier }}</el-text>
          </template>
        </el-table-column>
        <el-table-column prop="platform" label="平台" width="100" />
        <el-table-column label="操作" width="160">
          <template #default="{ row }">
            <el-button size="small" type="primary" @click="$router.push(`/capabilities?bundle_id=${row.apple_id || row.id}`)">
              权限
            </el-button>
            <el-button size="small" type="danger" @click="deleteBundleId(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </div>

    <!-- Profiles -->
    <div class="content-card">
      <div class="card-header">
        <h3>描述文件</h3>
        <el-button type="primary" @click="openCreateProfile" :disabled="!store.currentAccountId">
          <el-icon><Plus /></el-icon> 创建描述文件
        </el-button>
      </div>

      <el-table :data="profiles" stripe v-loading="loadingProfiles" empty-text="暂无描述文件">
        <el-table-column prop="name" label="名称" min-width="200" />
        <el-table-column prop="type" label="类型" width="200">
          <template #default="{ row }">
            <el-tag size="small">{{ profileTypeLabel(row.type) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="expires_at" label="过期时间" width="120">
          <template #default="{ row }">
            {{ row.expires_at ? new Date(row.expires_at).toLocaleDateString() : '-' }}
          </template>
        </el-table-column>
        <el-table-column label="操作" width="200">
          <template #default="{ row }">
            <el-button size="small" type="primary" @click="downloadProfile(row)">
              <el-icon><Download /></el-icon> 下载
            </el-button>
            <el-button size="small" type="danger" @click="deleteProfile(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </div>

    <!-- 创建 Bundle ID -->
    <el-dialog v-model="showBundleDialog" title="创建 Bundle ID" width="480px" destroy-on-close>
      <el-form :model="bundleForm" label-width="80px">
        <el-form-item label="名称" required>
          <el-input v-model="bundleForm.name" placeholder="例如：My App" />
        </el-form-item>
        <el-form-item label="标识符" required>
          <el-input v-model="bundleForm.identifier" placeholder="例如：com.example.myapp" />
        </el-form-item>
        <el-form-item label="平台">
          <el-select v-model="bundleForm.platform" style="width: 100%">
            <el-option label="iOS" value="IOS" />
            <el-option label="macOS" value="MAC_OS" />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showBundleDialog = false">取消</el-button>
        <el-button type="primary" @click="createBundleId" :loading="savingBundle">创建</el-button>
      </template>
    </el-dialog>

    <!-- 创建描述文件 -->
    <el-dialog v-model="showProfileDialog" title="创建描述文件" width="600px" destroy-on-close>
      <el-form :model="profileForm" label-width="100px">
        <el-form-item label="名称" required>
          <el-input v-model="profileForm.name" placeholder="描述文件名称" />
        </el-form-item>
        <el-form-item label="类型" required>
          <el-select v-model="profileForm.type" style="width: 100%">
            <el-option
              v-for="t in profileTypes"
              :key="t.value"
              :label="t.label"
              :value="t.value"
            >
              <div style="display:flex; justify-content:space-between; align-items:center">
                <span>{{ t.label }}</span>
                <span style="color:#909399; font-size:12px; margin-left:12px">{{ t.desc }}</span>
              </div>
            </el-option>
          </el-select>
        </el-form-item>
        <el-form-item label="Bundle ID" required>
          <el-select v-model="profileForm.bundle_id" style="width: 100%" placeholder="选择 Bundle ID">
            <el-option
              v-for="b in bundleIds"
              :key="b.id"
              :label="`${b.name} (${b.identifier})`"
              :value="b.apple_id || b.id"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="证书" required>
          <el-select v-model="profileForm.certificate_ids" multiple style="width: 100%" placeholder="选择证书">
            <el-option
              v-for="c in remoteCerts"
              :key="c.id"
              :label="`${c.attributes?.name || c.id} (${c.attributes?.certificateType || ''})`"
              :value="c.id"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="设备" v-if="needDevices">
          <el-select v-model="profileForm.device_ids" multiple style="width: 100%" placeholder="选择设备">
            <el-option
              v-for="d in devices"
              :key="d.id"
              :label="`${d.name} (${d.udid?.slice(-8)})`"
              :value="d.apple_id || d.id"
            />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showProfileDialog = false">取消</el-button>
        <el-button type="primary" @click="createProfile" :loading="savingProfile">创建</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { profileApi, certApi, deviceApi } from '../api'
import { useAppStore } from '../stores/app'

const store = useAppStore()
const bundleIds = ref([])
const profiles = ref([])
const remoteCerts = ref([])
const devices = ref([])
const profileTypes = ref([])

const PROFILE_TYPE_MAP = {
  IOS_APP_DEVELOPMENT: 'iOS 开发描述文件',
  IOS_APP_STORE: 'iOS App Store 描述文件',
  IOS_APP_ADHOC: 'iOS Ad Hoc 描述文件',
  IOS_APP_INHOUSE: 'iOS 企业内部描述文件',
  MAC_APP_DEVELOPMENT: 'macOS 开发描述文件',
  MAC_APP_STORE: 'macOS App Store 描述文件',
  MAC_APP_DIRECT: 'macOS 直接分发描述文件',
  TVOS_APP_DEVELOPMENT: 'tvOS 开发描述文件',
  TVOS_APP_STORE: 'tvOS App Store 描述文件',
  TVOS_APP_ADHOC: 'tvOS Ad Hoc 描述文件',
  TVOS_APP_INHOUSE: 'tvOS 企业内部描述文件',
}

function profileTypeLabel(type) {
  return PROFILE_TYPE_MAP[type] || type
}
const loadingBundles = ref(false)
const loadingProfiles = ref(false)
const savingBundle = ref(false)
const savingProfile = ref(false)
const showBundleDialog = ref(false)
const showProfileDialog = ref(false)

const bundleForm = ref({ name: '', identifier: '', platform: 'IOS' })
const profileForm = ref({ name: '', type: 'IOS_APP_DEVELOPMENT', bundle_id: '', certificate_ids: [], device_ids: [] })

const needDevices = computed(() => {
  const t = profileForm.value.type
  return t.includes('DEVELOPMENT') || t.includes('ADHOC')
})

async function fetchBundleIds() {
  if (!store.currentAccountId) return
  loadingBundles.value = true
  try {
    const res = await profileApi.bundleIds(store.currentAccountId)
    bundleIds.value = res.data || []
  } finally {
    loadingBundles.value = false
  }
}

async function fetchProfiles() {
  if (!store.currentAccountId) return
  loadingProfiles.value = true
  try {
    const res = await profileApi.list(store.currentAccountId)
    profiles.value = res.data || []
  } finally {
    loadingProfiles.value = false
  }
}

async function fetchProfileTypes() {
  try {
    const res = await profileApi.types()
    profileTypes.value = res.data || []
  } catch {}
}

async function createBundleId() {
  if (!bundleForm.value.name || !bundleForm.value.identifier) {
    return ElMessage.warning('请填写所有必填字段')
  }
  savingBundle.value = true
  try {
    await profileApi.createBundleId({ account_id: store.currentAccountId, ...bundleForm.value })
    ElMessage.success('Bundle ID 创建成功')
    showBundleDialog.value = false
    bundleForm.value = { name: '', identifier: '', platform: 'IOS' }
    fetchBundleIds()
  } finally {
    savingBundle.value = false
  }
}

async function deleteBundleId(row) {
  await ElMessageBox.confirm(`确定删除 Bundle ID「${row.identifier}」？`, '确认', { type: 'warning' })
  await profileApi.deleteBundleId(row.id)
  ElMessage.success('删除成功')
  fetchBundleIds()
}

async function openCreateProfile() {
  showProfileDialog.value = true
  try {
    const [certRes, devRes] = await Promise.all([
      certApi.list(store.currentAccountId),
      deviceApi.list(store.currentAccountId)
    ])
    remoteCerts.value = certRes.remote || []
    devices.value = devRes.data || []
  } catch {}
}

async function createProfile() {
  const f = profileForm.value
  if (!f.name || !f.type || !f.bundle_id || !f.certificate_ids.length) {
    return ElMessage.warning('请填写所有必填字段')
  }
  savingProfile.value = true
  try {
    await profileApi.create({ account_id: store.currentAccountId, ...f })
    ElMessage.success('描述文件创建成功')
    showProfileDialog.value = false
    profileForm.value = { name: '', type: 'IOS_APP_DEVELOPMENT', bundle_id: '', certificate_ids: [], device_ids: [] }
    fetchProfiles()
  } finally {
    savingProfile.value = false
  }
}

function downloadProfile(row) {
  window.open(profileApi.download(row.id), '_blank')
}

async function deleteProfile(row) {
  await ElMessageBox.confirm(`确定删除描述文件「${row.name}」？`, '确认', { type: 'warning' })
  await profileApi.delete(row.id)
  ElMessage.success('删除成功')
  fetchProfiles()
}

watch(() => store.currentAccountId, () => { fetchBundleIds(); fetchProfiles() })
onMounted(() => { fetchBundleIds(); fetchProfiles(); fetchProfileTypes() })
</script>
