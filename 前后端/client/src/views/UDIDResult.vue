<template>
  <div class="udid-result-page">
    <div class="result-container" v-loading="loading">
      <!-- 成功 -->
      <template v-if="deviceInfo">
        <div class="success-header">
          <div class="success-icon">
            <svg width="56" height="56" viewBox="0 0 56 56" fill="none">
              <circle cx="28" cy="28" r="28" fill="url(#grad)" />
              <path d="M18 28.5L24.5 35L38 21.5" stroke="white" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round"/>
              <defs>
                <linearGradient id="grad" x1="0" y1="0" x2="56" y2="56">
                  <stop offset="0%" stop-color="#34d399"/>
                  <stop offset="100%" stop-color="#059669"/>
                </linearGradient>
              </defs>
            </svg>
          </div>
          <h1 class="success-title">设备识别成功</h1>
          <p class="success-subtitle">已获取您的设备信息，请将以下内容发送给开发者</p>
        </div>

        <div class="device-card">
          <div class="device-icon-row">
            <div class="device-icon-bg">
              <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                <rect x="5" y="2" rx="2" width="14" height="20"/>
                <line x1="12" y1="18" x2="12" y2="18.01" stroke-width="2" stroke-linecap="round"/>
              </svg>
            </div>
            <div class="device-name-col">
              <span class="device-primary-name">{{ deviceInfo.device_name || deviceInfo.product || '未知设备' }}</span>
              <span class="device-secondary">iOS {{ deviceInfo.version || '-' }}</span>
            </div>
          </div>

          <div class="info-list">
            <div class="info-item highlight">
              <div class="info-item-label">
                <span class="info-dot blue"></span>
                UDID
              </div>
              <div class="info-item-value mono">{{ deviceInfo.udid }}</div>
              <button class="copy-icon-btn" @click="copyText(deviceInfo.udid, 'UDID')">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <rect x="9" y="9" width="13" height="13" rx="2"/>
                  <path d="M5 15H4a2 2 0 01-2-2V4a2 2 0 012-2h9a2 2 0 012 2v1"/>
                </svg>
              </button>
            </div>

            <div class="info-item" v-if="deviceInfo.device_name">
              <div class="info-item-label">
                <span class="info-dot green"></span>
                设备名称
              </div>
              <div class="info-item-value">{{ deviceInfo.device_name }}</div>
            </div>

            <div class="info-item" v-if="deviceInfo.product">
              <div class="info-item-label">
                <span class="info-dot purple"></span>
                设备型号
              </div>
              <div class="info-item-value">{{ deviceInfo.product }}</div>
            </div>

            <div class="info-item" v-if="deviceInfo.version">
              <div class="info-item-label">
                <span class="info-dot orange"></span>
                系统版本
              </div>
              <div class="info-item-value">iOS {{ deviceInfo.version }}</div>
            </div>

            <div class="info-item" v-if="deviceInfo.serial">
              <div class="info-item-label">
                <span class="info-dot gray"></span>
                序列号
              </div>
              <div class="info-item-value mono">{{ deviceInfo.serial }}</div>
            </div>

            <div class="info-item" v-if="deviceInfo.imei">
              <div class="info-item-label">
                <span class="info-dot gray"></span>
                IMEI
              </div>
              <div class="info-item-value mono">{{ deviceInfo.imei }}</div>
            </div>
          </div>
        </div>

        <div class="action-buttons">
          <button class="btn-primary" @click="copyAll">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <rect x="9" y="9" width="13" height="13" rx="2"/>
              <path d="M5 15H4a2 2 0 01-2-2V4a2 2 0 012-2h9a2 2 0 012 2v1"/>
            </svg>
            {{ copied ? '已复制 ✓' : '复制全部信息' }}
          </button>

          <button class="btn-secondary" @click="shareInfo" v-if="canShare">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M4 12v8a2 2 0 002 2h12a2 2 0 002-2v-8"/>
              <polyline points="16 6 12 2 8 6"/>
              <line x1="12" y1="2" x2="12" y2="15"/>
            </svg>
            分享给开发者
          </button>
        </div>

        <div class="footer-note">
          <div class="note-icon">💡</div>
          <div class="note-text">
            <p>描述文件已自动删除，不会影响您的设备。</p>
            <p>如未自动删除，可前往「设置 → 通用 → VPN与设备管理」手动移除。</p>
          </div>
        </div>
      </template>

      <!-- 等待中 -->
      <template v-else-if="!loading">
        <div class="waiting-section">
          <div class="waiting-icon">
            <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="#f59e0b" stroke-width="1.5">
              <circle cx="12" cy="12" r="10"/>
              <polyline points="12 6 12 12 16 14"/>
            </svg>
          </div>
          <h2>等待安装描述文件</h2>
          <p class="waiting-desc">请在「设置」中完成描述文件的安装，安装后此页面将自动显示结果</p>

          <div class="steps-hint">
            <div class="step-item">
              <span class="step-num">1</span>
              <span>打开 iPhone「设置」</span>
            </div>
            <div class="step-item">
              <span class="step-num">2</span>
              <span>点击顶部「已下载的描述文件」</span>
            </div>
            <div class="step-item">
              <span class="step-num">3</span>
              <span>点击「安装」并输入锁屏密码</span>
            </div>
          </div>

          <button class="btn-primary" @click="fetchResult">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <polyline points="23 4 23 10 17 10"/>
              <path d="M20.49 15a9 9 0 11-2.12-9.36L23 10"/>
            </svg>
            刷新结果
          </button>
        </div>
      </template>
    </div>

    <div class="brand-footer">
      <span>Powered by</span>
      <strong>CertVault</strong>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { useRoute } from 'vue-router'
import { udidApi } from '../api'

const route = useRoute()
const loading = ref(true)
const deviceInfo = ref(null)
const copied = ref(false)
let pollTimer = null

const canShare = ref(!!navigator.share)

async function fetchResult() {
  const id = route.query.id
  if (!id) { loading.value = false; return }

  try {
    const res = await udidApi.result(id)
    if (res.data?.status === 'success' && res.data?.udid) {
      deviceInfo.value = res.data
      if (pollTimer) { clearInterval(pollTimer); pollTimer = null }
    }
  } catch {}
  loading.value = false
}

function buildText() {
  if (!deviceInfo.value) return ''
  return [
    `UDID: ${deviceInfo.value.udid}`,
    deviceInfo.value.device_name ? `设备: ${deviceInfo.value.device_name}` : '',
    deviceInfo.value.product ? `型号: ${deviceInfo.value.product}` : '',
    deviceInfo.value.version ? `系统: iOS ${deviceInfo.value.version}` : '',
    deviceInfo.value.serial ? `序列号: ${deviceInfo.value.serial}` : '',
  ].filter(Boolean).join('\n')
}

function copyAll() {
  const text = buildText()
  copyToClipboard(text)
  copied.value = true
  setTimeout(() => { copied.value = false }, 2000)
}

function copyText(text, label) {
  copyToClipboard(text)
  copied.value = true
  setTimeout(() => { copied.value = false }, 1500)
}

function copyToClipboard(text) {
  if (navigator.clipboard) {
    navigator.clipboard.writeText(text)
  } else {
    const ta = document.createElement('textarea')
    ta.value = text
    ta.style.cssText = 'position:fixed;left:-9999px'
    document.body.appendChild(ta)
    ta.select()
    document.execCommand('copy')
    document.body.removeChild(ta)
  }
}

async function shareInfo() {
  if (!navigator.share) return
  try {
    await navigator.share({
      title: '设备 UDID 信息',
      text: buildText(),
    })
  } catch {}
}

onMounted(() => {
  fetchResult()
  pollTimer = setInterval(fetchResult, 3000)
})

onUnmounted(() => {
  if (pollTimer) clearInterval(pollTimer)
})
</script>

<style scoped>
.udid-result-page {
  min-height: 100vh;
  min-height: 100dvh;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  background: linear-gradient(160deg, #f8fafc 0%, #e2e8f0 50%, #ddd6fe 100%);
  padding: 20px;
  -webkit-font-smoothing: antialiased;
}

.result-container {
  width: 100%;
  max-width: 400px;
  min-height: 200px;
}

.success-header {
  text-align: center;
  margin-bottom: 24px;
}

.success-icon { margin-bottom: 16px; }

.success-title {
  font-size: 24px;
  font-weight: 800;
  color: #1e293b;
  margin: 0 0 8px;
  letter-spacing: -0.5px;
}

.success-subtitle {
  font-size: 14px;
  color: #64748b;
  margin: 0;
  line-height: 1.5;
}

.device-card {
  background: rgba(255,255,255,0.92);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  border-radius: 20px;
  padding: 20px;
  box-shadow: 0 4px 24px rgba(0,0,0,0.06), 0 0 0 1px rgba(255,255,255,0.8) inset;
}

.device-icon-row {
  display: flex;
  align-items: center;
  gap: 14px;
  padding-bottom: 16px;
  border-bottom: 1px solid rgba(0,0,0,0.06);
  margin-bottom: 4px;
}

.device-icon-bg {
  width: 48px;
  height: 48px;
  border-radius: 14px;
  background: linear-gradient(135deg, #6366f1, #8b5cf6);
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  flex-shrink: 0;
}

.device-name-col {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.device-primary-name {
  font-size: 16px;
  font-weight: 700;
  color: #1e293b;
}

.device-secondary {
  font-size: 13px;
  color: #94a3b8;
}

.info-list { margin-top: 4px; }

.info-item {
  display: flex;
  align-items: center;
  padding: 14px 0;
  border-bottom: 1px solid rgba(0,0,0,0.04);
  position: relative;
}

.info-item:last-child { border-bottom: none; }

.info-item.highlight {
  background: linear-gradient(135deg, rgba(59,130,246,0.04), rgba(139,92,246,0.04));
  margin: 8px -12px 0;
  padding: 14px 12px;
  border-radius: 12px;
  border-bottom: none;
}

.info-item-label {
  font-size: 13px;
  color: #94a3b8;
  flex-shrink: 0;
  display: flex;
  align-items: center;
  gap: 6px;
  min-width: 72px;
}

.info-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  flex-shrink: 0;
}
.info-dot.blue { background: #3b82f6; }
.info-dot.green { background: #22c55e; }
.info-dot.purple { background: #8b5cf6; }
.info-dot.orange { background: #f59e0b; }
.info-dot.gray { background: #94a3b8; }

.info-item-value {
  flex: 1;
  font-size: 14px;
  font-weight: 600;
  color: #1e293b;
  text-align: right;
  word-break: break-all;
  line-height: 1.4;
}

.info-item-value.mono {
  font-family: 'SF Mono', ui-monospace, monospace;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.3px;
}

.copy-icon-btn {
  background: none;
  border: none;
  padding: 6px;
  cursor: pointer;
  color: #3b82f6;
  border-radius: 6px;
  flex-shrink: 0;
  margin-left: 4px;
  transition: background 0.15s;
}
.copy-icon-btn:active { background: rgba(59,130,246,0.1); }

.action-buttons {
  margin-top: 20px;
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.btn-primary, .btn-secondary {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  width: 100%;
  padding: 15px;
  border: none;
  border-radius: 14px;
  font-size: 16px;
  font-weight: 700;
  cursor: pointer;
  transition: all 0.2s;
  -webkit-tap-highlight-color: transparent;
}

.btn-primary {
  background: linear-gradient(135deg, #3b82f6, #6366f1);
  color: white;
  box-shadow: 0 4px 14px rgba(59,130,246,0.3);
}
.btn-primary:active {
  transform: scale(0.98);
  box-shadow: 0 2px 8px rgba(59,130,246,0.2);
}

.btn-secondary {
  background: rgba(255,255,255,0.8);
  color: #3b82f6;
  border: 1.5px solid rgba(59,130,246,0.2);
}
.btn-secondary:active {
  background: rgba(59,130,246,0.05);
}

.footer-note {
  margin-top: 20px;
  display: flex;
  gap: 10px;
  padding: 14px 16px;
  background: rgba(255,255,255,0.6);
  border-radius: 14px;
  border: 1px solid rgba(0,0,0,0.04);
}

.note-icon { font-size: 18px; flex-shrink: 0; margin-top: 1px; }

.note-text p {
  font-size: 12px;
  color: #64748b;
  margin: 0;
  line-height: 1.6;
}

/* Waiting */
.waiting-section { text-align: center; }

.waiting-icon { margin-bottom: 20px; }

.waiting-section h2 {
  font-size: 22px;
  font-weight: 800;
  color: #1e293b;
  margin: 0 0 8px;
}

.waiting-desc {
  font-size: 14px;
  color: #64748b;
  margin: 0 0 24px;
  line-height: 1.5;
}

.steps-hint {
  background: rgba(255,255,255,0.85);
  backdrop-filter: blur(16px);
  border-radius: 16px;
  padding: 16px;
  margin-bottom: 24px;
  text-align: left;
}

.step-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px 0;
  font-size: 14px;
  color: #334155;
}

.step-item + .step-item {
  border-top: 1px solid rgba(0,0,0,0.04);
}

.step-num {
  width: 24px;
  height: 24px;
  border-radius: 50%;
  background: linear-gradient(135deg, #3b82f6, #6366f1);
  color: white;
  font-size: 12px;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.brand-footer {
  margin-top: 32px;
  text-align: center;
  font-size: 12px;
  color: #94a3b8;
}
.brand-footer strong {
  color: #6366f1;
  font-weight: 700;
  margin-left: 4px;
}

@media (prefers-color-scheme: dark) {
  .udid-result-page {
    background: linear-gradient(160deg, #0f172a 0%, #1e1b4b 100%);
  }
  .success-title, .device-primary-name, .info-item-value, .waiting-section h2 { color: #f1f5f9; }
  .success-subtitle, .waiting-desc, .note-text p, .info-item-label { color: #94a3b8; }
  .device-card, .steps-hint {
    background: rgba(30,41,59,0.8);
    box-shadow: 0 4px 24px rgba(0,0,0,0.2), 0 0 0 1px rgba(255,255,255,0.05) inset;
  }
  .info-item { border-bottom-color: rgba(255,255,255,0.06); }
  .info-item.highlight { background: rgba(59,130,246,0.08); }
  .device-icon-row { border-bottom-color: rgba(255,255,255,0.06); }
  .device-secondary { color: #64748b; }
  .step-item { color: #cbd5e1; border-top-color: rgba(255,255,255,0.06); }
  .footer-note { background: rgba(30,41,59,0.5); border-color: rgba(255,255,255,0.05); }
  .btn-secondary { background: rgba(30,41,59,0.6); border-color: rgba(99,102,241,0.3); }
  .copy-icon-btn { color: #818cf8; }
}
</style>
