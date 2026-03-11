<template>
  <div>
    <div class="page-header">
      <h1>推送密钥管理</h1>
      <p>导入和管理 APNs 推送认证密钥 (.p8)，用于向 Apple 推送服务发送通知</p>
    </div>

    <!-- 说明 -->
    <div class="content-card">
      <el-alert type="info" :closable="false">
        <template #title>此处导入的是 <strong>APNs 推送密钥</strong>（从 Apple Developer → Keys 页面创建）</template>
        <div style="margin-top: 4px; line-height: 1.6; font-size: 13px">
          与「账号管理」中的 App Store Connect API Key 不同，推送密钥仅用于发送推送通知。
          如需管理证书/设备/描述文件，请在「账号管理」中导入 App Store Connect API Key。
        </div>
      </el-alert>
    </div>

    <!-- 列表 -->
    <div class="content-card">
      <div class="card-header">
        <h3>推送密钥列表</h3>
        <el-button type="primary" @click="openAddDialog">
          <el-icon><Plus /></el-icon> 导入推送密钥
        </el-button>
      </div>

      <el-table :data="keys" stripe v-loading="loading" empty-text="暂无推送密钥，请先导入">
        <el-table-column prop="name" label="名称" min-width="150" />
        <el-table-column prop="key_id" label="Key ID" width="130">
          <template #default="{ row }">
            <el-tag size="small" type="info">{{ row.key_id }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="team_id" label="Team ID" width="130">
          <template #default="{ row }">
            <el-text style="font-family: monospace; font-size: 12px">{{ row.team_id }}</el-text>
          </template>
        </el-table-column>
        <el-table-column prop="bundle_ids" label="关联 Bundle ID" min-width="200">
          <template #default="{ row }">
            <div v-if="row.bundle_ids">
              <el-tag
                v-for="bid in row.bundle_ids.split(',')"
                :key="bid"
                size="small"
                effect="plain"
                style="margin: 2px"
              >
                {{ bid.trim() }}
              </el-tag>
            </div>
            <el-text v-else type="info" size="small">通用（所有 App）</el-text>
          </template>
        </el-table-column>
        <el-table-column prop="created_at" label="导入时间" width="170">
          <template #default="{ row }">{{ formatDate(row.created_at) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="160" fixed="right">
          <template #default="{ row }">
            <el-button size="small" type="success" @click="goTest(row)">测试</el-button>
            <el-dropdown trigger="click" @command="cmd => handleKeyCmd(cmd, row)">
              <el-button size="small">
                更多 <el-icon style="margin-left:4px"><ArrowDown /></el-icon>
              </el-button>
              <template #dropdown>
                <el-dropdown-menu>
                  <el-dropdown-item command="edit">
                    <el-icon><Edit /></el-icon> 编辑
                  </el-dropdown-item>
                  <el-dropdown-item command="download">
                    <el-icon><Download /></el-icon> 下载 P8
                  </el-dropdown-item>
                  <el-dropdown-item command="delete" divided style="color: var(--nask-red)">
                    <el-icon><Delete /></el-icon> 删除
                  </el-dropdown-item>
                </el-dropdown-menu>
              </template>
            </el-dropdown>
          </template>
        </el-table-column>
      </el-table>
    </div>

    <!-- 导入/编辑对话框 -->
    <el-dialog v-model="showDialog" :title="editingId ? '编辑推送密钥' : '导入推送密钥'" width="600px" destroy-on-close>
      <el-form :model="form" label-width="110px">
        <el-form-item label="名称" required>
          <el-input v-model="form.name" placeholder="例如：MyApp 推送密钥" />
        </el-form-item>

        <el-form-item label="P8 密钥文件" required v-if="!editingId">
          <div
            class="p8-drop-zone"
            :class="{ 'drag-over': isDragging, 'has-file': !!p8FileName }"
            @dragover.prevent="isDragging = true"
            @dragleave.prevent="isDragging = false"
            @drop.prevent="handleDrop"
            @click="$refs.fileInput?.click()"
          >
            <div v-if="p8FileName" class="p8-file-info">
              <el-icon size="20" color="#67c23a"><Document /></el-icon>
              <span class="p8-filename">{{ p8FileName }}</span>
              <el-button size="small" text type="danger" @click.stop="clearFile">移除</el-button>
            </div>
            <div v-else class="p8-placeholder">
              <el-icon size="32" color="var(--nask-text-muted)"><UploadFilled /></el-icon>
              <p>拖拽 .p8 文件到此处，或点击选择</p>
            </div>
          </div>
          <input type="file" ref="fileInput" accept=".p8,.pem,.key" style="display:none" @change="handleFileSelect" />

          <div style="margin-top: 8px">
            <el-button size="small" @click="showPaste = !showPaste">
              {{ showPaste ? '隐藏' : '手动粘贴' }}
            </el-button>
          </div>
          <el-input
            v-if="showPaste"
            v-model="form.private_key"
            type="textarea"
            :rows="5"
            style="margin-top: 8px"
            placeholder="粘贴 .p8 文件内容 (-----BEGIN PRIVATE KEY-----...)"
          />
        </el-form-item>

        <el-form-item label="Key ID" required>
          <el-input v-model="form.key_id" placeholder="APNs Key 的 Key ID" />
          <div class="form-tip">Apple Developer → Keys 页面中显示的 Key ID</div>
        </el-form-item>

        <el-form-item label="Team ID" required>
          <el-input v-model="form.team_id" placeholder="10位字母数字，如 ABC1234DEF" />
          <div class="form-tip">Apple Developer 账号页面右上角可以看到</div>
        </el-form-item>

        <el-form-item label="关联 Bundle ID">
          <el-input v-model="form.bundle_ids" placeholder="可选，多个用逗号分隔，如 com.app1,com.app2" />
          <div class="form-tip">留空表示此 Key 可用于所有 App 的推送</div>
        </el-form-item>
      </el-form>

      <template #footer>
        <el-button @click="showDialog = false">取消</el-button>
        <el-button type="primary" @click="saveKey" :loading="saving">
          {{ editingId ? '保存' : '导入' }}
        </el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import { pushKeyApi } from '../api'

const router = useRouter()
const keys = ref([])
const loading = ref(false)
const showDialog = ref(false)
const saving = ref(false)
const editingId = ref(null)
const isDragging = ref(false)
const p8FileName = ref('')
const p8File = ref(null)
const showPaste = ref(false)
const fileInput = ref(null)

const form = ref({ name: '', key_id: '', team_id: '', private_key: '', bundle_ids: '' })

function formatDate(d) {
  return d ? new Date(d).toLocaleString('zh-CN') : '-'
}

async function fetchKeys() {
  loading.value = true
  try {
    const res = await pushKeyApi.list()
    keys.value = res.data || []
  } finally {
    loading.value = false
  }
}

function openAddDialog() {
  editingId.value = null
  form.value = { name: '', key_id: '', team_id: '', private_key: '', bundle_ids: '' }
  p8FileName.value = ''
  p8File.value = null
  showPaste.value = false
  showDialog.value = true
}

function editKey(row) {
  editingId.value = row.id
  form.value = { name: row.name, key_id: row.key_id, team_id: row.team_id, private_key: '', bundle_ids: row.bundle_ids || '' }
  showDialog.value = true
}

function handleDrop(e) {
  isDragging.value = false
  const file = e.dataTransfer.files[0]
  if (file) loadFile(file)
}

function handleFileSelect(e) {
  const file = e.target.files[0]
  if (file) loadFile(file)
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

function loadFile(file) {
  const reader = new FileReader()
  reader.onload = (e) => {
    form.value.private_key = e.target.result
    p8FileName.value = file.name
    p8File.value = file
    const info = guessInfoFromFilename(file.name)
    if (info.keyId && !form.value.key_id) form.value.key_id = info.keyId
    if (info.name && !form.value.name) form.value.name = `${info.name} 推送密钥`
  }
  reader.readAsText(file)
}

function clearFile() {
  p8FileName.value = ''
  p8File.value = null
  form.value.private_key = ''
}

async function saveKey() {
  if (!form.value.name || !form.value.key_id || !form.value.team_id) {
    return ElMessage.warning('请填写名称、Key ID 和 Team ID')
  }
  if (!editingId.value && !form.value.private_key) {
    return ElMessage.warning('请上传或粘贴 .p8 密钥文件')
  }

  saving.value = true
  try {
    if (editingId.value) {
      const data = { ...form.value }
      if (!data.private_key) delete data.private_key
      await pushKeyApi.update(editingId.value, data)
      ElMessage.success('更新成功')
    } else {
      await pushKeyApi.create(form.value)
      ElMessage.success('推送密钥导入成功')
    }
    showDialog.value = false
    fetchKeys()
  } finally {
    saving.value = false
  }
}

async function deleteKey(row) {
  await ElMessageBox.confirm(`确定删除推送密钥「${row.name}」？`, '确认删除', { type: 'warning' })
  await pushKeyApi.delete(row.id)
  ElMessage.success('删除成功')
  fetchKeys()
}

function handleKeyCmd(cmd, row) {
  if (cmd === 'edit') editKey(row)
  else if (cmd === 'download') downloadKey(row)
  else if (cmd === 'delete') deleteKey(row)
}

function downloadKey(row) {
  window.open(pushKeyApi.download(row.id), '_blank')
}

function goTest(row) {
  router.push({ path: '/push', query: { push_key_id: row.id } })
}

onMounted(fetchKeys)
</script>

<style scoped>
.p8-drop-zone {
  border: 2px dashed var(--nask-border);
  border-radius: var(--nask-radius-sm);
  padding: 20px;
  text-align: center;
  cursor: pointer;
  transition: all var(--nask-transition);
  background: var(--nask-surface-hover);
}

.p8-drop-zone:hover { border-color: var(--nask-blue); background: rgba(64,158,255,0.04); }
.p8-drop-zone.drag-over { border-color: var(--nask-blue); background: rgba(64,158,255,0.08); }
.p8-drop-zone.has-file { border-color: var(--nask-green); background: rgba(34,197,94,0.04); border-style: solid; }

.p8-file-info { display: flex; align-items: center; gap: 10px; justify-content: center; }
.p8-filename { font-weight: 600; font-family: monospace; color: var(--nask-text); }
.p8-placeholder p { margin: 8px 0 0; color: var(--nask-text-muted); font-size: 14px; }

.form-tip { color: var(--nask-text-muted); font-size: 12px; margin-top: 4px; }
</style>
