<template>
  <div>
    <div class="page-header">
      <h1>定时推送</h1>
      <p>管理定时推送任务，设置推送计划并追踪执行状态</p>
    </div>

    <!-- 统计卡片 -->
    <el-row :gutter="16" style="margin-bottom: 20px">
      <el-col :xs="12" :sm="6">
        <div class="content-card stat-card">
          <div class="stat-value">{{ computedStats.total }}</div>
          <div class="stat-label">总计</div>
        </div>
      </el-col>
      <el-col :xs="12" :sm="6">
        <div class="content-card stat-card">
          <div class="stat-value pending">{{ computedStats.pending }}</div>
          <div class="stat-label">待执行</div>
        </div>
      </el-col>
      <el-col :xs="12" :sm="6">
        <div class="content-card stat-card">
          <div class="stat-value success">{{ computedStats.success }}</div>
          <div class="stat-label">已完成</div>
        </div>
      </el-col>
      <el-col :xs="12" :sm="6">
        <div class="content-card stat-card">
          <div class="stat-value failed">{{ computedStats.failed }}</div>
          <div class="stat-label">失败</div>
        </div>
      </el-col>
    </el-row>

    <!-- 主表格 -->
    <div class="content-card">
      <div class="card-header">
        <h3>定时任务列表</h3>
        <div style="display: flex; gap: 8px; align-items: center">
          <el-select v-model="filterStatus" placeholder="状态" size="small" clearable style="width: 110px" @change="fetchList">
            <el-option label="全部" value="" />
            <el-option label="待执行" value="pending" />
            <el-option label="已完成" value="success" />
            <el-option label="失败" value="failed" />
            <el-option label="已取消" value="cancelled" />
          </el-select>
          <el-button size="small" type="primary" @click="showCreate = true">
            <el-icon><Plus /></el-icon> 创建定时推送
          </el-button>
          <el-button size="small" @click="fetchList" :loading="loading">
            <el-icon><Refresh /></el-icon>
          </el-button>
        </div>
      </div>

      <el-table :data="items" v-loading="loading" empty-text="暂无定时推送任务" stripe>
        <el-table-column label="推送类型" width="90" align="center">
          <template #default="{ row }">
            <el-tag :type="row.type === 'broadcast' ? 'warning' : ''" size="small" effect="plain">
              {{ row.type === 'broadcast' ? '广播' : '单推' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="标题" min-width="140">
          <template #default="{ row }">
            <strong style="font-size: 13px; color: var(--nask-text)">{{ row.title }}</strong>
          </template>
        </el-table-column>
        <el-table-column label="内容" min-width="160">
          <template #default="{ row }">
            <span class="body-preview">{{ row.body || '-' }}</span>
          </template>
        </el-table-column>
        <el-table-column label="Bundle ID" prop="bundle_id" min-width="130">
          <template #default="{ row }">
            <code style="font-size: 11px">{{ row.bundle_id || '-' }}</code>
          </template>
        </el-table-column>
        <el-table-column label="环境" width="90" align="center">
          <template #default="{ row }">
            <el-tag :type="row.sandbox ? 'info' : 'success'" size="small" effect="plain">
              {{ row.sandbox ? 'Sandbox' : 'Production' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="90" align="center">
          <template #default="{ row }">
            <el-tag :type="statusTagType(row.status)" size="small">{{ statusText(row.status) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="定时时间" width="165">
          <template #default="{ row }">
            <span class="time-text">{{ formatTime(row.scheduled_at) }}</span>
          </template>
        </el-table-column>
        <el-table-column label="执行结果" min-width="140">
          <template #default="{ row }">
            <span v-if="row.result" class="result-text">{{ parseResult(row.result) }}</span>
            <span v-else class="time-text">-</span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="130" align="center" fixed="right">
          <template #default="{ row }">
            <el-button v-if="row.status === 'pending'" link size="small" type="warning" @click="handleCancel(row)">取消</el-button>
            <el-button link size="small" type="danger" @click="handleDelete(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>

      <div class="pagination-wrap" v-if="total > pageSize">
        <el-pagination
          v-model:current-page="currentPage"
          :page-size="pageSize"
          :total="total"
          layout="prev, pager, next"
          @current-change="fetchList"
          small
        />
      </div>
    </div>

    <!-- 创建定时推送对话框 -->
    <el-dialog v-model="showCreate" title="创建定时推送" width="520" destroy-on-close @closed="resetForm">
      <el-form :model="form" label-width="90px" size="default">
        <el-form-item label="推送类型">
          <el-radio-group v-model="form.type">
            <el-radio value="broadcast">广播</el-radio>
            <el-radio value="single">单推</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="标题" required>
          <el-input v-model="form.title" placeholder="推送标题" />
        </el-form-item>
        <el-form-item label="内容">
          <el-input v-model="form.body" type="textarea" :rows="3" placeholder="推送内容" />
        </el-form-item>
        <el-form-item label="Bundle ID">
          <el-input v-model="form.bundle_id" placeholder="可选，指定 Bundle ID" />
        </el-form-item>
        <el-form-item label="环境">
          <el-radio-group v-model="form.sandbox">
            <el-radio :value="false">Production</el-radio>
            <el-radio :value="true">Sandbox</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item v-if="form.type === 'single'" label="Device Token">
          <el-input v-model="form.device_token" placeholder="目标设备 Token" />
        </el-form-item>
        <el-form-item label="推送密钥">
          <el-select v-model="form.push_key_id" placeholder="选择推送密钥" style="width: 100%">
            <el-option v-for="key in pushKeys" :key="key.id" :label="key.name" :value="key.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="定时时间" required>
          <el-date-picker
            v-model="form.scheduled_at"
            type="datetime"
            placeholder="选择定时时间"
            style="width: 100%"
            format="YYYY-MM-DD HH:mm:ss"
            value-format="YYYY-MM-DDTHH:mm:ss"
          />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showCreate = false">取消</el-button>
        <el-button type="primary" @click="submitCreate" :loading="submitting">创建</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { pushApi, pushKeyApi } from '../api'

const loading = ref(false)
const submitting = ref(false)
const items = ref([])
const total = ref(0)
const currentPage = ref(1)
const pageSize = 15
const filterStatus = ref('')
const showCreate = ref(false)
const pushKeys = ref([])

const form = ref({
  type: 'broadcast',
  title: '',
  body: '',
  bundle_id: '',
  sandbox: false,
  device_token: '',
  push_key_id: '',
  scheduled_at: '',
})

const computedStats = computed(() => {
  const list = items.value
  return {
    total: total.value,
    pending: list.filter(i => i.status === 'pending').length,
    success: list.filter(i => i.status === 'success').length,
    failed: list.filter(i => i.status === 'failed').length,
  }
})

function statusTagType(s) {
  const map = { pending: 'warning', success: 'success', failed: 'danger', cancelled: 'info', executing: '', partial: 'warning' }
  return map[s] ?? ''
}

function statusText(s) {
  const map = { pending: '待执行', success: '已完成', failed: '失败', cancelled: '已取消', executing: '执行中', partial: '部分成功' }
  return map[s] ?? s
}

function formatTime(t) {
  if (!t) return '-'
  return new Date(t).toLocaleString('zh-CN', { month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit' })
}

function parseResult(result) {
  if (!result) return '-'
  try {
    const r = typeof result === 'string' ? JSON.parse(result) : result
    if (r.success_count !== undefined) {
      return `成功 ${r.success_count} / 失败 ${r.failed_count ?? 0}`
    }
    if (r.message) return r.message
    if (r.error) return r.error
    return JSON.stringify(r)
  } catch {
    return String(result)
  }
}

function resetForm() {
  form.value = {
    type: 'broadcast',
    title: '',
    body: '',
    bundle_id: '',
    sandbox: false,
    device_token: '',
    push_key_id: '',
    scheduled_at: '',
  }
}

async function fetchList() {
  loading.value = true
  try {
    const params = { page: currentPage.value, limit: pageSize }
    if (filterStatus.value) params.status = filterStatus.value
    const res = await pushApi.scheduled(params)
    items.value = res.data || []
    total.value = res.total || 0
  } finally {
    loading.value = false
  }
}

async function fetchPushKeys() {
  try {
    const res = await pushKeyApi.list()
    pushKeys.value = res.data || []
  } catch {}
}

async function submitCreate() {
  if (!form.value.title?.trim()) {
    return ElMessage.warning('请输入推送标题')
  }
  if (!form.value.scheduled_at) {
    return ElMessage.warning('请选择定时时间')
  }
  submitting.value = true
  try {
    const data = { ...form.value }
    if (data.type === 'broadcast') delete data.device_token
    if (!data.bundle_id) delete data.bundle_id
    if (!data.push_key_id) delete data.push_key_id
    await pushApi.createScheduled(data)
    ElMessage.success('定时推送创建成功')
    showCreate.value = false
    fetchList()
  } finally {
    submitting.value = false
  }
}

async function handleCancel(row) {
  try {
    await ElMessageBox.confirm('确定取消该定时推送任务？', '取消确认', { type: 'warning' })
    await pushApi.cancelScheduled(row.id)
    ElMessage.success('已取消')
    fetchList()
  } catch {}
}

async function handleDelete(row) {
  try {
    await ElMessageBox.confirm('确定删除该定时推送记录？', '删除确认', { type: 'warning' })
    await pushApi.deleteScheduled(row.id)
    ElMessage.success('已删除')
    fetchList()
  } catch {}
}

onMounted(() => {
  fetchList()
  fetchPushKeys()
})
</script>

<style scoped>
.stat-card { text-align: center; padding: 16px 12px !important; }
.stat-value { font-size: 28px; font-weight: 700; color: var(--nask-text); line-height: 1.2; }
.stat-value.pending { color: var(--el-color-warning); }
.stat-value.success { color: var(--el-color-success); }
.stat-value.failed { color: var(--el-color-danger); }
.stat-label { font-size: 12px; color: var(--nask-text-muted); margin-top: 4px; }

.body-preview { font-size: 12px; color: var(--nask-text-muted); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; display: block; max-width: 240px; }
.time-text { font-size: 12px; color: var(--nask-text-secondary); }
.result-text { font-size: 12px; color: var(--nask-text-secondary); }

.pagination-wrap { display: flex; justify-content: center; padding-top: 16px; }
</style>
