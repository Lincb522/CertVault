<template>
  <div>
    <div class="page-header">
      <h1>推送设置</h1>
      <p>管理推送服务全局配置，包括总开关、默认参数和自动化设置</p>
    </div>

    <div v-if="loading" style="text-align: center; padding: 60px 0">
      <el-icon class="is-loading" :size="32"><Loading /></el-icon>
    </div>

    <template v-else>
      <!-- 服务状态卡片 -->
      <div class="content-card status-card">
        <div class="card-header">
          <h3>服务状态</h3>
          <el-switch
            v-model="form.push_enabled"
            active-text="已启用"
            inactive-text="已关闭"
            :active-value="'true'"
            :inactive-value="'false'"
            size="large"
            style="--el-switch-on-color: var(--el-color-success)"
            @change="saveSettings"
          />
        </div>

        <el-row :gutter="16" class="status-grid">
          <el-col :xs="12" :sm="6">
            <div class="status-item">
              <div class="status-label">Production</div>
              <div class="status-dot" :class="connStatus.production">
                {{ connLabel(connStatus.production) }}
              </div>
            </div>
          </el-col>
          <el-col :xs="12" :sm="6">
            <div class="status-item">
              <div class="status-label">Sandbox</div>
              <div class="status-dot" :class="connStatus.sandbox">
                {{ connLabel(connStatus.sandbox) }}
              </div>
            </div>
          </el-col>
          <el-col :xs="12" :sm="6">
            <div class="status-item">
              <div class="status-label">已注册设备</div>
              <div class="status-value">{{ statusData.device_count ?? '-' }}</div>
            </div>
          </el-col>
          <el-col :xs="12" :sm="6">
            <div class="status-item">
              <div class="status-label">推送密钥</div>
              <div class="status-value">{{ statusData.key_count ?? '-' }}</div>
            </div>
          </el-col>
        </el-row>
      </div>

      <el-row :gutter="20">
        <!-- 基本设置 -->
        <el-col :xs="24" :sm="12">
          <div class="content-card">
            <div class="card-header"><h3>基本设置</h3></div>
            <el-form label-width="130px" label-position="left">
              <el-form-item label="默认推送密钥">
                <el-select v-model="form.default_push_key_id" clearable placeholder="选择默认密钥" style="width: 100%">
                  <el-option v-for="pk in pushKeys" :key="pk.id" :label="`${pk.name} (${pk.key_id})`" :value="pk.id" />
                </el-select>
              </el-form-item>
              <el-form-item label="默认 Bundle ID">
                <el-input v-model="form.default_bundle_id" placeholder="例如：com.example.yourapp" />
              </el-form-item>
              <el-form-item label="默认环境">
                <el-radio-group v-model="form.default_sandbox">
                  <el-radio value="false">Production</el-radio>
                  <el-radio value="true">Sandbox</el-radio>
                </el-radio-group>
              </el-form-item>
            </el-form>
          </div>
        </el-col>

        <!-- APNs 设置 -->
        <el-col :xs="24" :sm="12">
          <div class="content-card">
            <div class="card-header"><h3>APNs 设置</h3></div>
            <el-form label-width="130px" label-position="left">
              <el-form-item label="默认优先级">
                <el-select v-model="form.apns_priority" style="width: 100%">
                  <el-option label="10 — 立即 (alert)" value="10" />
                  <el-option label="5 — 节能 (background)" value="5" />
                  <el-option label="1 — 低优先级" value="1" />
                </el-select>
                <div class="form-tip">Apple 建议 alert 推送使用 10，background 推送使用 5</div>
              </el-form-item>
              <el-form-item label="过期时间 (秒)">
                <el-input-number v-model.number="expirationNum" :min="0" :max="2592000" :step="3600" style="width: 100%" />
                <div class="form-tip">0 = 立即过期（不重试），最大 30 天 (2592000 秒)</div>
              </el-form-item>
              <el-form-item label="广播并发数">
                <el-input-number v-model.number="concurrencyNum" :min="1" :max="100" style="width: 100%" />
                <div class="form-tip">同时向 APNs 发送请求的数量，建议 5-20</div>
              </el-form-item>
            </el-form>
          </div>
        </el-col>
      </el-row>

      <!-- 自动化设置 -->
      <div class="content-card">
        <div class="card-header"><h3>自动化设置</h3></div>
        <el-form label-width="130px" label-position="left">
          <el-row :gutter="20">
            <el-col :xs="24" :sm="12">
              <el-form-item label="自动清理设备">
                <el-switch
                  v-model="form.auto_cleanup_enabled"
                  :active-value="'true'"
                  :inactive-value="'false'"
                />
                <div class="form-tip">启用后，广播推送时自动清除 APNs 返回 410 (Unregistered) 的设备 Token</div>
              </el-form-item>
            </el-col>
            <el-col :xs="24" :sm="12">
              <el-form-item label="历史保留天数">
                <el-input-number v-model.number="retentionNum" :min="1" :max="365" style="width: 100%" />
                <div class="form-tip">超过此天数的推送历史记录将被自动清理</div>
              </el-form-item>
            </el-col>
          </el-row>
        </el-form>
      </div>

      <!-- 保存按钮 -->
      <div style="text-align: right; margin-top: 20px">
        <el-button @click="fetchAll">重置</el-button>
        <el-button type="primary" size="large" @click="saveSettings" :loading="saving">
          保存设置
        </el-button>
      </div>
    </template>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { Loading } from '@element-plus/icons-vue'
import { pushApi, pushKeyApi } from '../api'

const loading = ref(true)
const saving = ref(false)
const pushKeys = ref([])
const statusData = ref({})

const form = ref({
  push_enabled: 'true',
  default_push_key_id: '',
  default_bundle_id: '',
  default_sandbox: 'false',
  apns_priority: '10',
  apns_expiration: '0',
  max_concurrency: '10',
  auto_cleanup_enabled: 'false',
  history_retention_days: '30',
})

const expirationNum = computed({
  get: () => parseInt(form.value.apns_expiration || '0', 10),
  set: (v) => { form.value.apns_expiration = String(v) },
})
const concurrencyNum = computed({
  get: () => parseInt(form.value.max_concurrency || '10', 10),
  set: (v) => { form.value.max_concurrency = String(v) },
})
const retentionNum = computed({
  get: () => parseInt(form.value.history_retention_days || '30', 10),
  set: (v) => { form.value.history_retention_days = String(v) },
})

const connStatus = computed(() => {
  const conns = statusData.value.connections || {}
  return {
    production: conns['https://api.push.apple.com'] || 'disconnected',
    sandbox: conns['https://api.sandbox.push.apple.com'] || 'disconnected',
  }
})

function connLabel(s) {
  return s === 'connected' ? '已连接' : '未连接'
}

async function fetchSettings() {
  try {
    const res = await pushApi.settings()
    if (res.data) {
      for (const [k, v] of Object.entries(res.data)) {
        if (form.value[k] !== undefined) form.value[k] = v || form.value[k]
      }
    }
  } catch {}
}

async function fetchStatus() {
  try {
    const res = await pushApi.status()
    statusData.value = res.data || {}
  } catch {}
}

async function fetchPushKeys() {
  try {
    const res = await pushKeyApi.list()
    pushKeys.value = res.data || []
  } catch {}
}

async function fetchAll() {
  loading.value = true
  await Promise.all([fetchSettings(), fetchStatus(), fetchPushKeys()])
  loading.value = false
}

async function saveSettings() {
  saving.value = true
  try {
    await pushApi.updateSettings(form.value)
    ElMessage.success('设置已保存')
    await fetchStatus()
  } catch (err) {
    ElMessage.error(err.response?.data?.message || '保存失败')
  } finally {
    saving.value = false
  }
}

onMounted(fetchAll)
</script>

<style scoped>
.status-card {
  margin-bottom: 20px;
}
.status-grid {
  margin-top: 16px;
}
.status-item {
  text-align: center;
  padding: 12px 0;
}
.status-label {
  font-size: 12px;
  color: var(--nask-text-muted);
  margin-bottom: 6px;
}
.status-value {
  font-size: 24px;
  font-weight: 700;
  color: var(--nask-text);
}
.status-dot {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 13px;
  font-weight: 500;
}
.status-dot::before {
  content: '';
  width: 8px;
  height: 8px;
  border-radius: 50%;
  display: inline-block;
}
.status-dot.connected {
  color: var(--el-color-success);
}
.status-dot.connected::before {
  background: var(--el-color-success);
  box-shadow: 0 0 6px var(--el-color-success);
}
.status-dot.disconnected {
  color: var(--nask-text-muted);
}
.status-dot.disconnected::before {
  background: var(--nask-text-muted);
}
.form-tip {
  color: var(--nask-text-muted);
  font-size: 12px;
  margin-top: 4px;
  line-height: 1.4;
}
</style>
