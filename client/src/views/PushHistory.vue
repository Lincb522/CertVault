<template>
  <div>
    <div class="page-header">
      <h1>推送历史</h1>
      <p>查看所有推送记录，追踪推送状态和投递结果</p>
    </div>

    <!-- 统计卡片 -->
    <el-row :gutter="16" style="margin-bottom: 20px">
      <el-col :xs="12" :sm="4">
        <div class="content-card stat-card">
          <div class="stat-value">{{ stats.total_pushes ?? '-' }}</div>
          <div class="stat-label">总推送次数</div>
        </div>
      </el-col>
      <el-col :xs="12" :sm="4">
        <div class="content-card stat-card">
          <div class="stat-value today">{{ stats.today_pushes ?? '-' }}</div>
          <div class="stat-label">今日推送</div>
        </div>
      </el-col>
      <el-col :xs="12" :sm="4">
        <div class="content-card stat-card">
          <div class="stat-value success">{{ stats.total_delivered ?? '-' }}</div>
          <div class="stat-label">总投递成功</div>
        </div>
      </el-col>
      <el-col :xs="12" :sm="4">
        <div class="content-card stat-card">
          <div class="stat-value danger">{{ stats.total_failed ?? '-' }}</div>
          <div class="stat-label">总投递失败</div>
        </div>
      </el-col>
      <el-col :xs="12" :sm="4">
        <div class="content-card stat-card">
          <div class="stat-value broadcast">{{ stats.broadcasts ?? '-' }}</div>
          <div class="stat-label">广播次数</div>
        </div>
      </el-col>
      <el-col :xs="12" :sm="4">
        <div class="content-card stat-card">
          <div class="stat-value single">{{ stats.singles ?? '-' }}</div>
          <div class="stat-label">单发次数</div>
        </div>
      </el-col>
    </el-row>

    <!-- 主表格 -->
    <div class="content-card">
      <div class="card-header">
        <h3>推送记录</h3>
        <div style="display: flex; gap: 8px; align-items: center">
          <el-select v-model="filterType" placeholder="类型" size="small" clearable style="width: 110px" @change="fetchHistory">
            <el-option label="全部" value="" />
            <el-option label="单发" value="single" />
            <el-option label="广播" value="broadcast" />
          </el-select>
          <el-select v-model="filterStatus" placeholder="状态" size="small" clearable style="width: 110px" @change="fetchHistory">
            <el-option label="全部" value="" />
            <el-option label="成功" value="success" />
            <el-option label="部分成功" value="partial" />
            <el-option label="失败" value="failed" />
          </el-select>
          <el-dropdown @command="handleClear">
            <el-button size="small" type="danger" plain>
              <el-icon><Delete /></el-icon> 清理
            </el-button>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item command="7">清理 7 天前</el-dropdown-item>
                <el-dropdown-item command="30">清理 30 天前</el-dropdown-item>
                <el-dropdown-item command="all" divided>清空全部</el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
          <el-button size="small" @click="fetchHistory" :loading="loading">
            <el-icon><Refresh /></el-icon>
          </el-button>
        </div>
      </div>

      <el-table :data="history" v-loading="loading" empty-text="暂无推送记录" stripe>
        <el-table-column label="类型" width="80" align="center">
          <template #default="{ row }">
            <el-tag :type="row.type === 'broadcast' ? 'warning' : ''" size="small" effect="plain">
              {{ row.type === 'broadcast' ? '广播' : '单发' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="标题" min-width="180">
          <template #default="{ row }">
            <div class="title-cell">
              <strong>{{ row.title }}</strong>
              <span v-if="row.body" class="body-preview">{{ row.body }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="100" align="center">
          <template #default="{ row }">
            <el-tag :type="statusType(row.status)" size="small">{{ statusText(row.status) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="投递" width="130" align="center">
          <template #default="{ row }">
            <span class="delivery-text">
              <span class="delivery-success">{{ row.success_count }}</span>
              <span class="delivery-sep">/</span>
              <span>{{ row.target_count }}</span>
              <span v-if="row.failed_count" class="delivery-failed"> ({{ row.failed_count }} 失败)</span>
            </span>
          </template>
        </el-table-column>
        <el-table-column label="耗时" width="80" align="center">
          <template #default="{ row }">
            <span class="time-text">{{ row.duration_ms ? (row.duration_ms / 1000).toFixed(1) + 's' : '-' }}</span>
          </template>
        </el-table-column>
        <el-table-column label="操作人" prop="username" width="90" />
        <el-table-column label="时间" width="165">
          <template #default="{ row }">
            <span class="time-text">{{ formatTime(row.created_at) }}</span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="100" align="center" fixed="right">
          <template #default="{ row }">
            <el-button link size="small" @click="viewDetail(row)">
              <el-icon><View /></el-icon> 详情
            </el-button>
          </template>
        </el-table-column>
      </el-table>

      <div class="pagination-wrap" v-if="total > pageSize">
        <el-pagination
          v-model:current-page="currentPage"
          :page-size="pageSize"
          :total="total"
          layout="prev, pager, next"
          @current-change="fetchHistory"
          small
        />
      </div>
    </div>

    <!-- 详情对话框 -->
    <el-dialog v-model="showDetail" title="推送详情" width="560" destroy-on-close>
      <template v-if="detail">
        <el-descriptions :column="2" border size="small">
          <el-descriptions-item label="类型">
            <el-tag :type="detail.type === 'broadcast' ? 'warning' : ''" size="small">
              {{ detail.type === 'broadcast' ? '广播推送' : '单发推送' }}
            </el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="状态">
            <el-tag :type="statusType(detail.status)" size="small">{{ statusText(detail.status) }}</el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="标题" :span="2">{{ detail.title }}</el-descriptions-item>
          <el-descriptions-item label="内容" :span="2">{{ detail.body || '-' }}</el-descriptions-item>
          <el-descriptions-item label="Bundle ID">{{ detail.bundle_id }}</el-descriptions-item>
          <el-descriptions-item label="环境">{{ detail.sandbox ? 'Sandbox' : detail.sandbox === false ? 'Production' : '自动' }}</el-descriptions-item>
          <el-descriptions-item label="目标设备">{{ detail.target_count }}</el-descriptions-item>
          <el-descriptions-item label="耗时">{{ detail.duration_ms ? (detail.duration_ms / 1000).toFixed(2) + 's' : '-' }}</el-descriptions-item>
          <el-descriptions-item label="成功">
            <span style="color: var(--el-color-success); font-weight: 600">{{ detail.success_count }}</span>
          </el-descriptions-item>
          <el-descriptions-item label="失败">
            <span style="color: var(--el-color-danger); font-weight: 600">{{ detail.failed_count }}</span>
          </el-descriptions-item>
          <el-descriptions-item label="已注销" v-if="detail.unregistered_count">{{ detail.unregistered_count }}</el-descriptions-item>
          <el-descriptions-item label="APNs ID" v-if="detail.apns_id" :span="2">
            <code style="font-size: 12px">{{ detail.apns_id }}</code>
          </el-descriptions-item>
          <el-descriptions-item label="Device Token" v-if="detail.device_token" :span="2">
            <code style="font-size: 11px; word-break: break-all">{{ detail.device_token }}</code>
          </el-descriptions-item>
          <el-descriptions-item label="操作人">{{ detail.username || '-' }}</el-descriptions-item>
          <el-descriptions-item label="时间">{{ formatTimeFull(detail.created_at) }}</el-descriptions-item>
        </el-descriptions>

        <div v-if="detailErrors?.length" style="margin-top: 16px">
          <h4 style="font-size: 14px; margin-bottom: 8px">失败详情</h4>
          <el-table :data="detailErrors" size="small" max-height="250" stripe>
            <el-table-column prop="token" label="Device Token" />
            <el-table-column prop="reason" label="失败原因" width="180">
              <template #default="{ row }">
                <el-tag size="small" type="danger">{{ row.reason }}</el-tag>
              </template>
            </el-table-column>
          </el-table>
        </div>
      </template>
      <template #footer>
        <el-button @click="showDetail = false">关闭</el-button>
        <el-button type="danger" plain @click="deleteHistory(detail.id)">删除记录</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { pushApi } from '../api'

const loading = ref(false)
const history = ref([])
const stats = ref({})
const total = ref(0)
const currentPage = ref(1)
const pageSize = 15
const filterType = ref('')
const filterStatus = ref('')

const showDetail = ref(false)
const detail = ref(null)
const detailErrors = computed(() => {
  if (!detail.value?.errors) return []
  return typeof detail.value.errors === 'string' ? JSON.parse(detail.value.errors) : detail.value.errors
})

function statusType(s) {
  return s === 'success' ? 'success' : s === 'partial' ? 'warning' : 'danger'
}
function statusText(s) {
  return s === 'success' ? '成功' : s === 'partial' ? '部分成功' : '失败'
}

function formatTime(t) {
  if (!t) return '-'
  return new Date(t).toLocaleString('zh-CN', { month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit' })
}
function formatTimeFull(t) {
  if (!t) return '-'
  return new Date(t).toLocaleString('zh-CN')
}

async function fetchHistory() {
  loading.value = true
  try {
    const params = { page: currentPage.value, limit: pageSize }
    if (filterType.value) params.type = filterType.value
    if (filterStatus.value) params.status = filterStatus.value
    const res = await pushApi.history(params)
    history.value = res.data || []
    total.value = res.total || 0
  } finally { loading.value = false }
}

async function fetchStats() {
  try {
    const res = await pushApi.historyStats()
    stats.value = res.data || {}
  } catch {}
}

async function viewDetail(row) {
  try {
    const res = await pushApi.historyDetail(row.id)
    detail.value = res.data
    showDetail.value = true
  } catch {}
}

async function deleteHistory(id) {
  try {
    await ElMessageBox.confirm('确定删除该推送记录？', '删除确认', { type: 'warning' })
    await pushApi.historyDelete(id)
    ElMessage.success('已删除')
    showDetail.value = false
    fetchHistory()
    fetchStats()
  } catch {}
}

async function handleClear(command) {
  const msg = command === 'all' ? '确定清空全部推送历史？此操作不可撤销。' : `确定清理 ${command} 天前的推送记录？`
  try {
    await ElMessageBox.confirm(msg, '清理确认', { type: 'warning', confirmButtonText: '确认清理', cancelButtonText: '取消' })
    await pushApi.historyClear(command === 'all' ? {} : { before_days: parseInt(command) })
    ElMessage.success('清理完成')
    fetchHistory()
    fetchStats()
  } catch {}
}

onMounted(() => {
  fetchHistory()
  fetchStats()
})
</script>

<style scoped>
.stat-card { text-align: center; padding: 14px 8px !important; }
.stat-value { font-size: 24px; font-weight: 700; color: var(--nask-text); line-height: 1.2; }
.stat-value.today { color: var(--el-color-primary); }
.stat-value.success { color: var(--el-color-success); }
.stat-value.danger { color: var(--el-color-danger); }
.stat-value.broadcast { color: var(--el-color-warning); }
.stat-value.single { color: #8b5cf6; }
.stat-label { font-size: 11px; color: var(--nask-text-muted); margin-top: 3px; }

.title-cell strong { display: block; font-size: 13px; color: var(--nask-text); }
.body-preview { display: block; font-size: 12px; color: var(--nask-text-muted); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; max-width: 300px; }

.delivery-text { font-size: 13px; }
.delivery-success { color: var(--el-color-success); font-weight: 600; }
.delivery-sep { color: var(--nask-text-muted); margin: 0 2px; }
.delivery-failed { color: var(--el-color-danger); font-size: 11px; }

.time-text { font-size: 12px; color: var(--nask-text-secondary); }

.pagination-wrap { display: flex; justify-content: center; padding-top: 16px; }
</style>
