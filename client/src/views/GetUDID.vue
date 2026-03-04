<template>
  <div>
    <div class="page-header">
      <h1>获取设备 UDID</h1>
      <p>通过网页描述文件自动获取 iPhone / iPad 的 UDID，无需连接电脑</p>
    </div>

    <el-row :gutter="20">
      <el-col :xs="24" :sm="14">
        <div class="content-card">
          <div class="card-header">
            <h3>生成获取链接</h3>
            <el-button type="primary" @click="createRequest" :loading="creating">
              <el-icon><Link /></el-icon> 生成新链接
            </el-button>
          </div>

          <!-- 未生成 -->
          <div v-if="!requestId" class="empty-state">
            <el-icon size="48" color="#c0c4cc"><Iphone /></el-icon>
            <p style="margin-top: 12px">点击「生成新链接」创建 UDID 获取链接</p>
            <p style="color: #909399; font-size: 13px">生成后用 iPhone Safari 扫码或打开链接即可</p>
          </div>

          <!-- 已生成 -->
          <div v-else>
            <el-steps :active="stepActive" style="margin-bottom: 24px">
              <el-step title="生成链接" />
              <el-step title="手机安装" />
              <el-step title="获取 UDID" />
            </el-steps>

            <!-- 二维码和链接 -->
            <div v-if="stepActive < 2" class="qr-section">
              <div class="qr-code" ref="qrContainer"></div>
              <div class="qr-info">
                <p><strong>用 iPhone Safari 扫描二维码</strong></p>
                <p style="color: #909399; font-size: 13px; margin-top: 4px">或复制链接在 Safari 中打开（不支持微信/Chrome 内打开）</p>

                <div class="link-box">
                  <el-input :model-value="enrollUrl" readonly size="small">
                    <template #append>
                      <el-button @click="copyLink">复制</el-button>
                    </template>
                  </el-input>
                </div>

                <el-alert type="warning" :closable="false" style="margin-top: 12px">
                  <template #title>必须使用 Safari 浏览器打开</template>
                  微信、Chrome 等浏览器无法安装描述文件
                </el-alert>

                <div style="margin-top: 16px">
                  <el-button type="success" @click="checkResult" :loading="checking">
                    <el-icon><Refresh /></el-icon> 检查结果
                  </el-button>
                  <el-text v-if="pollCount > 0" type="info" size="small" style="margin-left: 8px">
                    已检查 {{ pollCount }} 次...
                  </el-text>
                </div>
              </div>
            </div>

            <!-- 获取成功 -->
            <div v-if="deviceInfo" class="result-section">
              <el-result icon="success" title="UDID 获取成功" />

              <el-descriptions :column="1" border size="small" style="max-width: 500px; margin: 0 auto">
                <el-descriptions-item label="UDID">
                  <div style="display: flex; align-items: center; gap: 8px">
                    <code class="udid-text">{{ deviceInfo.udid }}</code>
                    <el-button size="small" text type="primary" @click="copyText(deviceInfo.udid)">
                      <el-icon><CopyDocument /></el-icon>
                    </el-button>
                  </div>
                </el-descriptions-item>
                <el-descriptions-item label="设备名称">{{ deviceInfo.device_name || '-' }}</el-descriptions-item>
                <el-descriptions-item label="设备型号">{{ deviceInfo.product || '-' }}</el-descriptions-item>
                <el-descriptions-item label="系统版本">{{ deviceInfo.version || '-' }}</el-descriptions-item>
                <el-descriptions-item label="序列号">{{ deviceInfo.serial || '-' }}</el-descriptions-item>
              </el-descriptions>

              <div style="text-align: center; margin-top: 20px">
                <el-button type="primary" @click="goBindDevice">
                  <el-icon><Plus /></el-icon> 直接绑定此设备
                </el-button>
                <el-button @click="createRequest">
                  <el-icon><Refresh /></el-icon> 获取另一台设备
                </el-button>
              </div>
            </div>
          </div>
        </div>
      </el-col>

      <el-col :xs="24" :sm="10">
        <div class="content-card">
          <div class="card-header"><h3>使用说明</h3></div>
          <el-timeline>
            <el-timeline-item type="primary" timestamp="第 1 步">
              点击「生成新链接」，得到二维码和链接
            </el-timeline-item>
            <el-timeline-item type="primary" timestamp="第 2 步">
              在 iPhone 上用 <strong>Safari</strong> 扫码或打开链接
            </el-timeline-item>
            <el-timeline-item type="warning" timestamp="第 3 步">
              点击「允许」下载描述文件
            </el-timeline-item>
            <el-timeline-item type="warning" timestamp="第 4 步">
              前往 <strong>设置 → 已下载描述文件</strong>，点击「安装」
            </el-timeline-item>
            <el-timeline-item type="success" timestamp="第 5 步">
              安装完成后自动跳转，UDID 将显示在本页面
            </el-timeline-item>
          </el-timeline>
        </div>

        <div class="content-card" style="margin-top: 20px">
          <div class="card-header"><h3>常见问题</h3></div>
          <el-collapse>
            <el-collapse-item title="安全吗？会不会泄露隐私？">
              描述文件仅用于获取 UDID，不会修改手机任何设置，安装后可在「设置 → 通用 → VPN与设备管理」中删除。
            </el-collapse-item>
            <el-collapse-item title="为什么必须用 Safari？">
              iOS 只允许 Safari 浏览器安装描述文件，微信、Chrome 等第三方浏览器会被系统拦截。
            </el-collapse-item>
            <el-collapse-item title="安装后没有跳转怎么办？">
              请回到本页面点击「检查结果」按钮手动查询。
            </el-collapse-item>
            <el-collapse-item title="链接有效期多久？">
              链接 10 分钟内有效，过期后请重新生成。
            </el-collapse-item>
          </el-collapse>
        </div>
      </el-col>
    </el-row>
  </div>
</template>

<script setup>
import { ref, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { udidApi } from '../api'

const router = useRouter()
const requestId = ref('')
const enrollUrl = ref('')
const creating = ref(false)
const checking = ref(false)
const pollCount = ref(0)
const deviceInfo = ref(null)
const stepActive = ref(0)
const qrContainer = ref(null)
let pollTimer = null

async function createRequest() {
  creating.value = true
  deviceInfo.value = null
  pollCount.value = 0
  stepActive.value = 0
  if (pollTimer) clearInterval(pollTimer)

  try {
    const res = await udidApi.createRequest()
    requestId.value = res.data.request_id
    const host = window.location.origin
    enrollUrl.value = `${host}/api/udid/enroll/${requestId.value}?host=${encodeURIComponent(host)}`
    stepActive.value = 1

    await nextTick()
    renderQR()

    pollTimer = setInterval(checkResult, 3000)
  } finally {
    creating.value = false
  }
}

async function renderQR() {
  if (!qrContainer.value) return
  qrContainer.value.innerHTML = ''

  const { default: QRCode } = await import('qrcode')
  const canvas = document.createElement('canvas')
  await QRCode.toCanvas(canvas, enrollUrl.value, { width: 200, margin: 2 })
  qrContainer.value.appendChild(canvas)
}

async function checkResult() {
  if (!requestId.value) return
  checking.value = true
  pollCount.value++
  try {
    const res = await udidApi.result(requestId.value)
    if (res.data?.status === 'success' && res.data?.udid) {
      deviceInfo.value = res.data
      stepActive.value = 2
      if (pollTimer) clearInterval(pollTimer)
      ElMessage.success('UDID 获取成功！')
    }
  } finally {
    checking.value = false
  }

  if (pollCount.value > 60 && pollTimer) {
    clearInterval(pollTimer)
  }
}

function copyLink() {
  navigator.clipboard.writeText(enrollUrl.value)
  ElMessage.success('链接已复制')
}

function copyText(text) {
  navigator.clipboard.writeText(text)
  ElMessage.success('已复制到剪贴板')
}

function goBindDevice() {
  router.push({
    path: '/devices',
    query: {
      auto_bind: '1',
      udid: deviceInfo.value.udid,
      name: deviceInfo.value.device_name || deviceInfo.value.product || ''
    }
  })
}
</script>

<style scoped>
.qr-section {
  display: flex;
  gap: 24px;
  align-items: flex-start;
}

.qr-code {
  flex-shrink: 0;
  padding: 12px;
  background: var(--cv-surface);
  border: 1px solid var(--cv-border-light);
  border-radius: var(--cv-radius-sm);
}

.qr-info {
  flex: 1;
}

.link-box {
  margin-top: 12px;
}

.udid-text {
  font-family: 'SF Mono', Monaco, Menlo, Consolas, monospace;
  font-size: 14px;
  font-weight: 600;
  color: var(--cv-text);
  background: var(--cv-surface-hover);
  padding: 4px 10px;
  border-radius: 6px;
  letter-spacing: 0.5px;
}

.result-section {
  text-align: center;
}

@media (max-width: 768px) {
  .qr-section {
    flex-direction: column;
    align-items: center;
  }
  .qr-info {
    width: 100%;
  }
}
</style>
