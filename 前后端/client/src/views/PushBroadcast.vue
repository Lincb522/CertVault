<template>
  <div>
    <div class="page-header">
      <h1>群发推送</h1>
      <p>向所有已注册设备发送推送通知，支持按环境筛选设备</p>
    </div>

    <el-row :gutter="20">
      <el-col :xs="24" :sm="14">
        <div class="content-card">
          <div class="card-header">
            <h3>编辑推送内容</h3>
            <el-tag type="warning" effect="dark" size="small">
              <el-icon style="margin-right: 2px"><Position /></el-icon>
              广播模式
            </el-tag>
          </div>

          <el-form :model="form" label-width="100px">
            <!-- 推送密钥 -->
            <el-form-item label="推送密钥" required>
              <el-select v-model="form.push_key_id" style="width: 100%" placeholder="选择已导入的推送密钥" @change="onPushKeySelect">
                <el-option v-for="pk in pushKeys" :key="pk.id" :label="`${pk.name} (Key: ${pk.key_id})`" :value="pk.id" />
              </el-select>
              <div class="form-tip" v-if="!pushKeys.length">
                暂无推送密钥，请先到 <el-link type="primary" @click="$router.push('/push-keys')">推送密钥管理</el-link> 页面导入
              </div>
            </el-form-item>

            <el-form-item label="Bundle ID" required>
              <el-input v-model="form.bundle_id" placeholder="例如：zijiu.Aside.com" />
            </el-form-item>

            <!-- 目标设备 -->
            <el-divider content-position="left">目标设备</el-divider>

            <el-form-item label="发送范围">
              <el-radio-group v-model="targetMode" @change="fetchDeviceCount">
                <el-radio-button value="all">全部设备</el-radio-button>
                <el-radio-button value="production">仅 Production</el-radio-button>
                <el-radio-button value="sandbox">仅 Sandbox</el-radio-button>
              </el-radio-group>
              <div class="form-tip">
                <template v-if="deviceCount !== null">
                  将发送到 <strong>{{ deviceCount }}</strong> 台设备
                </template>
                <template v-else>加载中...</template>
              </div>
            </el-form-item>

            <!-- 推送内容 -->
            <el-divider content-position="left">推送内容</el-divider>

            <el-form-item label="标题" required>
              <el-input v-model="form.title" placeholder="推送标题" maxlength="50" show-word-limit />
            </el-form-item>
            <el-form-item label="内容">
              <el-input v-model="form.body" type="textarea" :rows="3" placeholder="推送正文内容" maxlength="200" show-word-limit />
            </el-form-item>

            <el-row :gutter="16">
              <el-col :span="12">
                <el-form-item label="角标">
                  <el-input-number v-model="form.badge" :min="0" :max="99" />
                </el-form-item>
              </el-col>
              <el-col :span="12">
                <el-form-item label="提示音">
                  <el-input v-model="form.sound" placeholder="default" />
                </el-form-item>
              </el-col>
            </el-row>

            <el-form-item>
              <el-button type="warning" size="large" @click="sendBroadcast" :loading="sending" :disabled="!deviceCount">
                <el-icon><Position /></el-icon> 发送群发推送 ({{ deviceCount || 0 }} 台)
              </el-button>
            </el-form-item>
          </el-form>

          <!-- 结果 -->
          <div v-if="result" class="push-result" :class="resultClass">
            <el-icon size="20">
              <CircleCheckFilled v-if="result.success" />
              <WarningFilled v-else-if="result.data?.success > 0" />
              <CircleCloseFilled v-else />
            </el-icon>
            <div style="flex: 1">
              <strong>{{ result.message }}</strong>
              <div v-if="result.data" class="result-stats">
                <div class="result-stat">
                  <span class="stat-num success">{{ result.data.success || 0 }}</span>
                  <span>成功</span>
                </div>
                <div class="result-stat">
                  <span class="stat-num danger">{{ result.data.failed || 0 }}</span>
                  <span>失败</span>
                </div>
                <div class="result-stat" v-if="result.data.unregistered">
                  <span class="stat-num warning">{{ result.data.unregistered }}</span>
                  <span>已注销</span>
                </div>
                <div class="result-stat">
                  <span class="stat-num">{{ result.data.total || 0 }}</span>
                  <span>总计</span>
                </div>
              </div>
              <div v-if="result.data?.errors?.length" style="margin-top: 10px">
                <el-collapse>
                  <el-collapse-item :title="`失败详情 (${result.data.errors.length})`">
                    <div v-for="(e, i) in result.data.errors" :key="i" class="error-item">
                      <code>{{ e.token }}</code>
                      <el-tag size="small" type="danger">{{ e.reason }}</el-tag>
                    </div>
                  </el-collapse-item>
                </el-collapse>
              </div>
            </div>
          </div>
        </div>
      </el-col>

      <el-col :xs="24" :sm="10">
        <!-- 推送预览 -->
        <div class="content-card">
          <div class="card-header"><h3>推送预览</h3></div>
          <div class="preview-phone">
            <div class="preview-notification">
              <div class="preview-app-icon">A</div>
              <div class="preview-content">
                <div class="preview-app-name">AsideMusic · 现在</div>
                <div class="preview-title">{{ form.title || '推送标题' }}</div>
                <div class="preview-body">{{ form.body || '推送内容' }}</div>
              </div>
            </div>
          </div>
        </div>

        <!-- 最近记录 -->
        <div class="content-card" style="margin-top: 20px">
          <div class="card-header">
            <h3>最近群发</h3>
            <el-button link size="small" @click="$router.push('/push-history')">查看全部</el-button>
          </div>
          <div v-if="!recentHistory.length" style="text-align: center; color: var(--nask-text-muted); padding: 20px; font-size: 13px">
            暂无推送记录
          </div>
          <div v-for="item in recentHistory" :key="item.id" class="history-item">
            <div class="history-header">
              <strong>{{ item.title }}</strong>
              <el-tag :type="statusType(item.status)" size="small">{{ statusText(item.status) }}</el-tag>
            </div>
            <div class="history-meta">
              {{ item.success_count }}/{{ item.target_count }} 成功 · {{ formatTime(item.created_at) }}
            </div>
          </div>
        </div>
      </el-col>
    </el-row>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { pushApi, pushKeyApi } from '../api'

const pushKeys = ref([])
const deviceCount = ref(null)
const sending = ref(false)
const result = ref(null)
const recentHistory = ref([])
const targetMode = ref('all')

const form = ref({
  push_key_id: '',
  bundle_id: '',
  title: '',
  body: '',
  badge: 1,
  sound: 'default',
})

const resultClass = computed(() => {
  if (!result.value) return ''
  if (result.value.success && result.value.data?.failed === 0) return 'success'
  if (result.value.data?.success > 0) return 'partial'
  return 'error'
})

function statusType(s) {
  return s === 'success' ? 'success' : s === 'partial' ? 'warning' : 'danger'
}
function statusText(s) {
  return s === 'success' ? '全部成功' : s === 'partial' ? '部分成功' : '失败'
}

function formatTime(t) {
  if (!t) return ''
  const d = new Date(t)
  const now = new Date()
  const diff = (now - d) / 1000
  if (diff < 60) return '刚刚'
  if (diff < 3600) return `${Math.floor(diff / 60)} 分钟前`
  if (diff < 86400) return `${Math.floor(diff / 3600)} 小时前`
  return d.toLocaleDateString('zh-CN', { month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' })
}

function onPushKeySelect(id) {
  const pk = pushKeys.value.find(k => k.id === id)
  if (pk?.bundle_ids) {
    const first = pk.bundle_ids.split(',')[0].trim()
    if (first && !form.value.bundle_id) form.value.bundle_id = first
  }
}

async function fetchDeviceCount() {
  try {
    const res = await pushApi.devicesStats()
    const stats = res.data || {}
    if (targetMode.value === 'production') deviceCount.value = stats.production || 0
    else if (targetMode.value === 'sandbox') deviceCount.value = stats.sandbox || 0
    else deviceCount.value = stats.total || 0
  } catch { deviceCount.value = null }
}

async function fetchPushKeys() {
  try {
    const res = await pushKeyApi.list()
    pushKeys.value = res.data || []
    if (pushKeys.value.length) {
      form.value.push_key_id = pushKeys.value[0].id
      onPushKeySelect(pushKeys.value[0].id)
    }
  } catch {}
}

async function fetchRecentHistory() {
  try {
    const res = await pushApi.history({ page: 1, limit: 5, type: 'broadcast' })
    recentHistory.value = res.data || []
  } catch {}
}

async function sendBroadcast() {
  if (!form.value.push_key_id) return ElMessage.warning('请选择推送密钥')
  if (!form.value.title) return ElMessage.warning('请填写标题')
  if (!form.value.bundle_id) return ElMessage.warning('请填写 Bundle ID')

  try {
    await ElMessageBox.confirm(
      `确定向 ${deviceCount.value} 台设备发送群发推送？\n\n标题：${form.value.title}\n内容：${form.value.body || '(空)'}`,
      '确认群发',
      { type: 'warning', confirmButtonText: '发送', cancelButtonText: '取消' }
    )
  } catch { return }

  const data = { ...form.value }
  if (targetMode.value === 'production') data.sandbox = false
  else if (targetMode.value === 'sandbox') data.sandbox = true

  sending.value = true
  result.value = null
  try {
    const res = await pushApi.broadcast(data)
    result.value = res
    if (res.success) {
      ElMessage.success(res.message || '广播完成')
      fetchDeviceCount()
      fetchRecentHistory()
    } else {
      ElMessage.error(res.message || '广播失败')
    }
  } catch (err) {
    result.value = { success: false, message: err.response?.data?.message || err.message }
  } finally { sending.value = false }
}

onMounted(() => {
  fetchPushKeys()
  fetchDeviceCount()
  fetchRecentHistory()
})
</script>

<style scoped>
.form-tip { color: var(--nask-text-muted); font-size: 12px; margin-top: 4px; }
.form-tip strong { color: var(--el-color-primary); }

.push-result {
  display: flex; align-items: flex-start; gap: 12px;
  padding: 16px; border-radius: var(--nask-radius-sm); margin-top: 16px;
}
.push-result.success { background: rgba(34,197,94,0.06); border: 1px solid var(--nask-green, #22c55e); color: var(--nask-green); }
.push-result.partial { background: rgba(245,158,11,0.06); border: 1px solid var(--el-color-warning); color: var(--el-color-warning); }
.push-result.error { background: rgba(239,68,68,0.06); border: 1px solid var(--nask-red, #ef4444); color: var(--nask-red); }
.push-result strong { color: var(--nask-text); }

.result-stats { display: flex; gap: 20px; margin-top: 10px; }
.result-stat { display: flex; flex-direction: column; align-items: center; }
.stat-num { font-size: 22px; font-weight: 700; color: var(--nask-text); line-height: 1; }
.stat-num.success { color: var(--el-color-success); }
.stat-num.danger { color: var(--el-color-danger); }
.stat-num.warning { color: var(--el-color-warning); }
.result-stat span:last-child { font-size: 11px; color: var(--nask-text-muted); margin-top: 2px; }

.error-item { display: flex; align-items: center; gap: 8px; padding: 3px 0; font-size: 12px; }
.error-item code { color: var(--nask-text-muted); }

.preview-phone {
  background: var(--nask-surface-hover, #f5f5f5);
  border-radius: 16px; padding: 16px; min-height: 80px;
}
.preview-notification {
  background: var(--nask-surface, #fff);
  border-radius: 14px; padding: 12px; display: flex; gap: 10px;
  box-shadow: 0 1px 4px rgba(0,0,0,0.06);
}
.preview-app-icon {
  width: 36px; height: 36px; border-radius: 8px; flex-shrink: 0;
  background: linear-gradient(135deg, #667eea, #764ba2); color: #fff;
  display: flex; align-items: center; justify-content: center;
  font-weight: 700; font-size: 14px;
}
.preview-content { flex: 1; min-width: 0; }
.preview-app-name { font-size: 11px; color: var(--nask-text-muted); text-transform: uppercase; letter-spacing: 0.3px; }
.preview-title { font-size: 13px; font-weight: 600; color: var(--nask-text); margin-top: 2px; }
.preview-body { font-size: 13px; color: var(--nask-text-secondary); margin-top: 1px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }

.history-item { padding: 10px 0; border-bottom: 1px solid var(--nask-border, #eee); }
.history-item:last-child { border-bottom: none; }
.history-header { display: flex; align-items: center; justify-content: space-between; gap: 8px; }
.history-header strong { font-size: 13px; color: var(--nask-text); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.history-meta { font-size: 12px; color: var(--nask-text-muted); margin-top: 3px; }
</style>
