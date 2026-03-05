<template>
  <div class="ipa-manage">
    <el-card shadow="never">
      <template #header>
        <div style="display:flex;justify-content:space-between;align-items:center">
          <span>IPA 文件管理</span>
          <el-button type="primary" size="small" @click="triggerUpload" :loading="uploading">
            <el-icon><Upload /></el-icon> 上传新版本
          </el-button>
        </div>
      </template>

      <div v-if="ipaList.length" class="ipa-info">
        <el-table :data="ipaList" stripe style="width:100%">
          <el-table-column label="应用" min-width="200">
            <template #default="{ row }">
              <div>{{ row.name }}</div>
              <div v-if="row.ipa_info" style="font-size:12px;color:#999;margin-top:2px">
                {{ row.ipa_info.app_name }} · {{ row.ipa_info.bundle_id }} · v{{ row.ipa_info.version }}({{ row.ipa_info.build }})
              </div>
            </template>
          </el-table-column>
          <el-table-column label="大小" width="90">
            <template #default="{ row }">{{ formatSize(row.size) }}</template>
          </el-table-column>
          <el-table-column label="上传时间" width="170">
            <template #default="{ row }">{{ formatTime(row.updated_at) }}</template>
          </el-table-column>
          <el-table-column label="操作" width="200" align="center">
            <template #default="{ row }">
              <el-button size="small" text type="primary" @click="copyUrl(row)">复制链接</el-button>
              <el-button size="small" text type="primary" @click="downloadFile(row)">下载</el-button>
              <el-popconfirm title="确认删除该文件？" @confirm="deleteFile(row)">
                <template #reference>
                  <el-button size="small" text type="danger">删除</el-button>
                </template>
              </el-popconfirm>
            </template>
          </el-table-column>
        </el-table>
      </div>
      <el-empty v-else description="尚未上传 IPA 文件" />

      <div style="margin-top:16px" v-if="uploading && uploadProgress > 0">
        <el-progress :percentage="uploadProgress" :stroke-width="6" />
      </div>
    </el-card>

    <el-card shadow="never" style="margin-top:16px">
      <template #header>
        <div style="display:flex;justify-content:space-between;align-items:center">
          <span>发布新版本</span>
          <el-button type="primary" size="small" @click="publishVersion" :loading="savingVersion">发布</el-button>
        </div>
      </template>
      <el-form :model="versionForm" label-width="80px" style="max-width:500px">
        <el-form-item label="关联 IPA" required>
          <el-select v-model="versionForm.ipa_file" placeholder="选择要发布的 IPA 文件" style="width:100%" @change="onIpaSelect">
            <el-option v-for="f in ipaList" :key="f.name" :label="f.ipa_info ? `${f.ipa_info.app_name} v${f.ipa_info.version}(${f.ipa_info.build})` : f.name" :value="f.name">
              <span>{{ f.ipa_info ? `${f.ipa_info.app_name} v${f.ipa_info.version}(${f.ipa_info.build})` : f.name }}</span>
              <span style="float:right;color:#999;font-size:12px">{{ formatSize(f.size) }}</span>
            </el-option>
          </el-select>
        </el-form-item>
        <el-form-item label="版本号" required>
          <el-input v-model="versionForm.version" placeholder="1.0.0" />
        </el-form-item>
        <el-form-item label="Build">
          <el-input v-model="versionForm.build" placeholder="1" />
        </el-form-item>
        <el-form-item label="更新日志">
          <el-input v-model="versionForm.changelog" type="textarea" :rows="3" placeholder="描述本次更新内容" />
        </el-form-item>
        <el-form-item label="强制更新">
          <el-switch v-model="versionForm.force_update" />
        </el-form-item>
      </el-form>
    </el-card>

    <el-card shadow="never" style="margin-top:16px">
      <template #header>
        <span>版本历史</span>
      </template>
      <el-table v-if="versionList.length" :data="versionList" stripe style="width:100%">
        <el-table-column label="版本" width="140">
          <template #default="{ row }">
            <div style="font-weight:600">v{{ row.version }} ({{ row.build }})</div>
            <el-tag v-if="row.is_current" size="small" type="success" style="margin-top:4px">当前版本</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="关联 IPA" prop="ipa_file" min-width="180" show-overflow-tooltip />
        <el-table-column label="更新日志" min-width="160">
          <template #default="{ row }">
            <span style="color:#666">{{ row.changelog || '-' }}</span>
          </template>
        </el-table-column>
        <el-table-column label="强制更新" width="80" align="center">
          <template #default="{ row }">
            <el-tag :type="row.force_update ? 'danger' : 'info'" size="small">{{ row.force_update ? '是' : '否' }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="发布时间" width="170">
          <template #default="{ row }">{{ formatTime(row.created_at) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="160" align="center">
          <template #default="{ row }">
            <el-button v-if="!row.is_current" size="small" text type="primary" @click="setCurrentVersion(row)">设为当前</el-button>
            <el-popconfirm v-if="!row.is_current" title="确认删除该版本记录？" @confirm="deleteVersion(row)">
              <template #reference>
                <el-button size="small" text type="danger">删除</el-button>
              </template>
            </el-popconfirm>
            <span v-if="row.is_current" style="color:#999;font-size:12px">当前发布中</span>
          </template>
        </el-table-column>
      </el-table>
      <el-empty v-else description="暂无版本发布记录" />
    </el-card>

    <input ref="fileInput" type="file" accept=".ipa" style="display:none" @change="handleUpload" />
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import api from '../api'

const ipaList = ref([])
const uploading = ref(false)
const uploadProgress = ref(0)
const fileInput = ref(null)
const versionForm = ref({ version: '', build: '1', changelog: '', force_update: false, ipa_file: '' })
const versionList = ref([])
const savingVersion = ref(false)

function formatSize(bytes) {
  if (!bytes) return '-'
  const mb = bytes / 1024 / 1024
  return mb >= 1 ? `${mb.toFixed(1)} MB` : `${(bytes / 1024).toFixed(1)} KB`
}

function formatTime(ts) {
  if (!ts) return '-'
  return new Date(ts).toLocaleString('zh-CN')
}

async function fetchList() {
  try {
    const resp = await api.get('/ipa/list')
    ipaList.value = resp.data || []
  } catch {}
}

function triggerUpload() {
  fileInput.value?.click()
}

async function handleUpload(e) {
  const file = e.target.files?.[0]
  if (!file) return
  if (!file.name.endsWith('.ipa')) {
    ElMessage.warning('请选择 .ipa 文件')
    return
  }
  uploading.value = true
  uploadProgress.value = 0
  try {
    const form = new FormData()
    form.append('ipa', file)
    const resp = await api.post('/ipa/upload', form, {
      headers: { 'Content-Type': 'multipart/form-data' },
      timeout: 120000,
      onUploadProgress: (e) => {
        if (e.total) uploadProgress.value = Math.round((e.loaded / e.total) * 100)
      }
    })
    ElMessage.success(resp.message || '上传成功')
    await fetchList()
    if (resp.data?.ipa_info) {
      const info = resp.data.ipa_info
      versionForm.value.version = info.version || versionForm.value.version
      versionForm.value.build = info.build || versionForm.value.build
      versionForm.value.ipa_file = resp.data.name || ''
    }
  } catch (err) {
    ElMessage.error(err.response?.data?.message || '上传失败')
  } finally {
    uploading.value = false
    uploadProgress.value = 0
    fileInput.value.value = ''
  }
}

function onIpaSelect(name) {
  const item = ipaList.value.find(f => f.name === name)
  if (item?.ipa_info) {
    versionForm.value.version = item.ipa_info.version || versionForm.value.version
    versionForm.value.build = item.ipa_info.build || versionForm.value.build
  }
}

function copyUrl(row) {
  const url = `${window.location.origin}/download/ipa/${row.name}`
  navigator.clipboard.writeText(url)
  ElMessage.success('已复制下载链接')
}

function downloadFile(row) {
  window.open(`/download/ipa/${row.name}`, '_blank')
}

async function deleteFile(row) {
  try {
    const resp = await api.delete(`/ipa/${encodeURIComponent(row.name)}`)
    ElMessage.success(resp.message || '已删除')
    await fetchList()
  } catch (err) {
    ElMessage.error(err.response?.data?.message || '删除失败')
  }
}

async function fetchVersions() {
  try {
    const resp = await api.get('/app/versions')
    versionList.value = resp.data || []
  } catch {}
}

async function publishVersion() {
  if (!versionForm.value.ipa_file) {
    ElMessage.warning('请选择要发布的 IPA 文件')
    return
  }
  if (!versionForm.value.version) {
    ElMessage.warning('请填写版本号')
    return
  }
  savingVersion.value = true
  try {
    const resp = await api.post('/app/versions', versionForm.value)
    ElMessage.success(resp.message || '已发布')
    versionForm.value = { version: '', build: '1', changelog: '', force_update: false, ipa_file: '' }
    await fetchVersions()
  } catch (err) {
    ElMessage.error(err.response?.data?.message || '发布失败')
  } finally {
    savingVersion.value = false
  }
}

async function setCurrentVersion(row) {
  try {
    const resp = await api.put(`/app/versions/${row.id}/current`)
    ElMessage.success(resp.message || '已设为当前版本')
    await fetchVersions()
  } catch (err) {
    ElMessage.error(err.response?.data?.message || '操作失败')
  }
}

async function deleteVersion(row) {
  try {
    const resp = await api.delete(`/app/versions/${row.id}`)
    ElMessage.success(resp.message || '已删除')
    await fetchVersions()
  } catch (err) {
    ElMessage.error(err.response?.data?.message || '删除失败')
  }
}

onMounted(() => { fetchList(); fetchVersions() })
</script>

<style scoped>
.ipa-manage { max-width: 900px; width: 100%; }
.ipa-info { padding: 8px 0; }

@media (max-width: 768px) {
  .ipa-manage { max-width: 100%; }
}
</style>
