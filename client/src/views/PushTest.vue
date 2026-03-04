<template>
  <div>
    <div class="page-header">
      <h1>推送测试</h1>
      <p>自建 APNs 推送服务，使用 .p8 Key 通过 HTTP/2 直连 Apple 推送服务器</p>
    </div>

    <el-row :gutter="20">
      <el-col :xs="24" :sm="14">
        <div class="content-card">
          <div class="card-header"><h3>发送推送</h3></div>

          <el-form :model="form" label-width="100px">
            <el-form-item label="认证方式">
              <el-radio-group v-model="authMode">
                <el-radio-button value="pushkey">已导入的推送密钥</el-radio-button>
                <el-radio-button value="account">API 账号</el-radio-button>
                <el-radio-button value="manual">手动填写</el-radio-button>
              </el-radio-group>
            </el-form-item>

            <template v-if="authMode === 'pushkey'">
              <el-form-item label="选择推送密钥" required>
                <el-select v-model="selectedPushKeyId" style="width: 100%" placeholder="选择已导入的推送密钥" @change="onPushKeySelect">
                  <el-option
                    v-for="pk in pushKeys"
                    :key="pk.id"
                    :label="`${pk.name} (Key: ${pk.key_id})`"
                    :value="pk.id"
                  />
                </el-select>
                <div class="form-tip" v-if="!pushKeys.length">
                  暂无推送密钥，请先到
                  <el-link type="primary" @click="$router.push('/push-keys')">推送密钥管理</el-link>
                  页面导入
                </div>
              </el-form-item>
            </template>

            <template v-if="authMode === 'account'">
              <el-form-item label="选择账号" required>
                <el-select v-model="form.account_id" style="width: 100%" placeholder="选择账号">
                  <el-option
                    v-for="acc in store.accounts"
                    :key="acc.id"
                    :label="acc.name"
                    :value="acc.id"
                  />
                </el-select>
              </el-form-item>
              <el-form-item label="Team ID" required>
                <el-input v-model="form.team_id" placeholder="Apple Developer Team ID（10位字母数字）" />
                <div class="form-tip">在 Apple Developer 账号页面右上角可以找到</div>
              </el-form-item>
            </template>

            <template v-if="authMode === 'manual'">
              <el-form-item label="Key ID" required>
                <el-input v-model="form.key_id" placeholder="APNs Key 的 Key ID" />
              </el-form-item>
              <el-form-item label="Team ID" required>
                <el-input v-model="form.team_id" placeholder="Apple Developer Team ID" />
              </el-form-item>
              <el-form-item label="Private Key" required>
                <el-input v-model="form.private_key" type="textarea" :rows="4" placeholder="粘贴 .p8 文件内容" />
              </el-form-item>
            </template>

            <template v-if="authMode === 'pushkey' && selectedPushKeyId">
              <el-alert type="success" :closable="false" style="margin-bottom: 12px">
                <template #title>
                  密钥已选择：Key ID <el-tag size="small">{{ selectedPushKeyInfo?.key_id }}</el-tag>
                  Team ID <el-tag size="small">{{ selectedPushKeyInfo?.team_id }}</el-tag>
                </template>
                私钥保存在服务端，发送推送时自动使用，无需手动填写
              </el-alert>
            </template>

            <el-divider content-position="left">推送内容</el-divider>

            <el-form-item label="Device Token" required>
              <el-input v-model="form.device_token" placeholder="64位十六进制字符串" />
              <div class="form-tip">在 App 中调用 registerForRemoteNotifications 获取</div>
            </el-form-item>
            <el-form-item label="Bundle ID" required>
              <el-input v-model="form.bundle_id" placeholder="例如：com.example.myapp" />
            </el-form-item>
            <el-form-item label="推送环境">
              <el-radio-group v-model="form.sandbox">
                <el-radio-button :value="true">沙盒 (Sandbox)</el-radio-button>
                <el-radio-button :value="false">生产 (Production)</el-radio-button>
              </el-radio-group>
              <div class="form-tip">
                {{ form.sandbox ? 'api.sandbox.push.apple.com — 开发调试用' : 'api.push.apple.com — 正式发布后使用' }}
              </div>
            </el-form-item>
            <el-form-item label="标题" required>
              <el-input v-model="form.title" placeholder="推送标题" />
            </el-form-item>
            <el-form-item label="内容">
              <el-input v-model="form.body" type="textarea" :rows="2" placeholder="推送正文内容" />
            </el-form-item>
            <el-form-item label="角标数字">
              <el-input-number v-model="form.badge" :min="0" :max="99" />
            </el-form-item>
            <el-form-item label="提示音">
              <el-input v-model="form.sound" placeholder="default" />
            </el-form-item>

            <el-form-item>
              <el-button type="primary" @click="sendPush" :loading="sending" size="large">
                <el-icon><Promotion /></el-icon> 发送推送
              </el-button>
            </el-form-item>
          </el-form>

          <!-- 发送结果 -->
          <div v-if="result" class="push-result" :class="result.success ? 'success' : 'error'">
            <el-icon size="20">
              <CircleCheckFilled v-if="result.success" />
              <CircleCloseFilled v-else />
            </el-icon>
            <div>
              <strong>{{ result.message }}</strong>
              <div v-if="result.data" class="result-detail">
                <span v-if="result.data.apns_id">APNs ID: {{ result.data.apns_id }}</span>
                <span v-if="result.data.reason"> | Reason: {{ result.data.reason }}</span>
                <span v-if="result.data.status"> | HTTP {{ result.data.status }}</span>
              </div>
            </div>
          </div>
        </div>
      </el-col>

      <el-col :xs="24" :sm="10">
        <!-- 自建推送说明 -->
        <div class="content-card">
          <div class="card-header"><h3>自建推送原理</h3></div>
          <div class="guide-content">
            <p>本工具直接通过 <strong>HTTP/2</strong> 连接 Apple APNs 服务器发送推送，无需依赖第三方推送服务。</p>

            <h4>通信流程</h4>
            <div class="flow-steps">
              <div class="flow-step">
                <div class="flow-num">1</div>
                <div>使用 .p8 Key 生成 JWT Token</div>
              </div>
              <div class="flow-arrow">|</div>
              <div class="flow-step">
                <div class="flow-num">2</div>
                <div>通过 HTTP/2 POST 请求发送到 APNs</div>
              </div>
              <div class="flow-arrow">|</div>
              <div class="flow-step">
                <div class="flow-num">3</div>
                <div>APNs 投递到用户设备</div>
              </div>
            </div>

            <h4>APNs 服务器地址</h4>
            <el-descriptions :column="1" size="small" border>
              <el-descriptions-item label="沙盒">api.sandbox.push.apple.com:443</el-descriptions-item>
              <el-descriptions-item label="生产">api.push.apple.com:443</el-descriptions-item>
            </el-descriptions>

            <h4>JWT Token 格式</h4>
            <div class="code-block">
              <code>Header: { alg: "ES256", kid: "KEY_ID" }</code><br/>
              <code>Payload: { iss: "TEAM_ID", iat: 时间戳 }</code><br/>
              <code>Signature: 使用 .p8 私钥签名</code>
            </div>

            <h4>Payload 示例</h4>
            <div class="code-block">
              <code>{</code><br/>
              <code>  "aps": {</code><br/>
              <code>    "alert": {</code><br/>
              <code>      "title": "标题",</code><br/>
              <code>      "body": "内容"</code><br/>
              <code>    },</code><br/>
              <code>    "badge": 1,</code><br/>
              <code>    "sound": "default"</code><br/>
              <code>  }</code><br/>
              <code>}</code>
            </div>

            <h4>注意事项</h4>
            <ul class="note-list">
              <li>JWT Token 有效期最长 <strong>1 小时</strong>，过期需重新生成</li>
              <li>Payload 最大 <strong>4KB</strong></li>
              <li>沙盒 Token 不能用于生产环境，反之亦然</li>
              <li>需要 Node.js 内置的 <strong>http2</strong> 模块（无额外依赖）</li>
            </ul>
          </div>
        </div>

        <!-- 错误码 -->
        <div class="content-card" style="margin-top: 20px">
          <div class="card-header">
            <h3>APNs 错误码参考</h3>
            <el-button size="small" @click="fetchErrorCodes" :loading="loadingCodes">
              <el-icon><Refresh /></el-icon>
            </el-button>
          </div>
          <el-table :data="errorCodes" stripe size="small" max-height="400">
            <el-table-column prop="code" label="状态码" width="70" align="center">
              <template #default="{ row }">
                <el-tag size="small" :type="row.code === 200 ? 'success' : row.code < 500 ? 'danger' : 'warning'">
                  {{ row.code }}
                </el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="reason" label="错误标识" width="180" />
            <el-table-column prop="desc" label="中文说明" />
          </el-table>
        </div>
      </el-col>
    </el-row>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { ElMessage } from 'element-plus'
import { pushApi, pushKeyApi } from '../api'
import { useAppStore } from '../stores/app'

const store = useAppStore()
const route = useRoute()
const authMode = ref('pushkey')
const sending = ref(false)
const result = ref(null)
const errorCodes = ref([])
const loadingCodes = ref(false)
const pushKeys = ref([])
const selectedPushKeyId = ref('')

const form = ref({
  account_id: '',
  team_id: '',
  key_id: '',
  private_key: '',
  device_token: '',
  bundle_id: '',
  title: '',
  body: '',
  badge: 1,
  sound: 'default',
  sandbox: true,
})

const selectedPushKeyInfo = ref(null)

function onPushKeySelect(id) {
  const pk = pushKeys.value.find(k => k.id === id)
  selectedPushKeyInfo.value = pk || null
  if (pk) {
    form.value.key_id = pk.key_id
    form.value.team_id = pk.team_id
    if (pk.bundle_ids) {
      const first = pk.bundle_ids.split(',')[0].trim()
      if (first && !form.value.bundle_id) form.value.bundle_id = first
    }
  }
}

async function sendPush() {
  if (!form.value.device_token || !form.value.title || !form.value.bundle_id) {
    return ElMessage.warning('请填写 Device Token、标题和 Bundle ID')
  }

  const data = { ...form.value }
  if (authMode.value === 'pushkey') {
    if (!selectedPushKeyId.value) return ElMessage.warning('请选择推送密钥')
    data.push_key_id = selectedPushKeyId.value
    delete data.account_id
    delete data.key_id
    delete data.private_key
  } else if (authMode.value === 'account') {
    if (!data.account_id || !data.team_id) {
      return ElMessage.warning('请选择账号并填写 Team ID')
    }
    delete data.key_id
    delete data.private_key
  } else {
    if (!data.key_id || !data.team_id || !data.private_key) {
      return ElMessage.warning('请填写 Key ID、Team ID 和 Private Key')
    }
    delete data.account_id
  }

  sending.value = true
  result.value = null
  try {
    const res = await pushApi.send(data)
    result.value = res
    if (res.success) {
      ElMessage.success('推送发送成功')
    } else {
      ElMessage.error(res.message || '推送失败')
    }
  } catch (err) {
    result.value = { success: false, message: err.response?.data?.message || err.message }
  } finally {
    sending.value = false
  }
}

async function fetchErrorCodes() {
  loadingCodes.value = true
  try {
    const res = await pushApi.errorCodes()
    errorCodes.value = res.data || []
  } finally {
    loadingCodes.value = false
  }
}

async function fetchPushKeys() {
  try {
    const res = await pushKeyApi.list()
    pushKeys.value = res.data || []
  } catch {}
}

onMounted(async () => {
  fetchErrorCodes()
  await fetchPushKeys()

  if (route.query.push_key_id) {
    selectedPushKeyId.value = route.query.push_key_id
    authMode.value = 'pushkey'
    onPushKeySelect(route.query.push_key_id)
  } else if (pushKeys.value.length > 0) {
    authMode.value = 'pushkey'
  }

  if (store.currentAccountId) {
    form.value.account_id = store.currentAccountId
  }
})
</script>

<style scoped>
.form-tip {
  color: var(--cv-text-muted);
  font-size: 12px;
  margin-top: 4px;
}

.push-result {
  display: flex;
  align-items: flex-start;
  gap: 10px;
  padding: 14px 16px;
  border-radius: var(--cv-radius-sm);
  margin-top: 16px;
}

.push-result.success {
  background: rgba(34,197,94,0.06);
  border: 1px solid var(--cv-green);
  color: var(--cv-green);
}

.push-result.error {
  background: rgba(239,68,68,0.06);
  border: 1px solid var(--cv-red);
  color: var(--cv-red);
}

.push-result strong {
  color: var(--cv-text);
}

.result-detail {
  font-size: 12px;
  color: var(--cv-text-muted);
  margin-top: 4px;
  font-family: monospace;
}

.guide-content {
  font-size: 14px;
  line-height: 1.7;
  color: var(--cv-text);
}

.guide-content h4 {
  font-size: 14px;
  font-weight: 600;
  margin: 16px 0 8px;
  color: var(--cv-text);
}

.guide-content p {
  margin: 0 0 8px;
  color: var(--cv-text-secondary);
}

.code-block {
  background: var(--cv-surface-hover);
  border: 1px solid var(--cv-border-light);
  border-radius: var(--cv-radius-xs);
  padding: 10px 14px;
  font-family: 'SF Mono', Monaco, Menlo, Consolas, monospace;
  font-size: 12px;
  line-height: 1.8;
  color: var(--cv-text);
  overflow-x: auto;
}

.flow-steps {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 4px;
  margin: 8px 0;
}

.flow-step {
  display: flex;
  align-items: center;
  gap: 10px;
  font-size: 13px;
}

.flow-num {
  width: 24px;
  height: 24px;
  border-radius: 50%;
  background: var(--cv-gradient);
  color: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 12px;
  font-weight: 600;
  flex-shrink: 0;
}

.flow-arrow {
  color: var(--cv-text-muted);
  padding-left: 8px;
  font-size: 12px;
}

.note-list {
  padding-left: 18px;
  margin: 0;
  font-size: 13px;
  color: var(--cv-text-secondary);
  line-height: 1.8;
}
</style>
