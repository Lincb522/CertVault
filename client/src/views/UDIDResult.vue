<template>
  <div class="result-page">
    <div class="result-card" v-loading="loading">
      <template v-if="deviceInfo">
        <div class="result-icon">
          <el-icon size="48" color="#67c23a"><CircleCheckFilled /></el-icon>
        </div>
        <h2>UDID 获取成功</h2>
        <p class="result-tip">请将以下信息发送给开发者</p>

        <div class="info-block">
          <div class="info-row">
            <span class="info-label">UDID</span>
            <code class="info-value udid">{{ deviceInfo.udid }}</code>
          </div>
          <div class="info-row" v-if="deviceInfo.device_name">
            <span class="info-label">设备名称</span>
            <span class="info-value">{{ deviceInfo.device_name }}</span>
          </div>
          <div class="info-row" v-if="deviceInfo.product">
            <span class="info-label">设备型号</span>
            <span class="info-value">{{ deviceInfo.product }}</span>
          </div>
          <div class="info-row" v-if="deviceInfo.version">
            <span class="info-label">系统版本</span>
            <span class="info-value">{{ deviceInfo.version }}</span>
          </div>
        </div>

        <div class="result-actions">
          <button class="copy-btn" @click="copyAll">复制全部信息</button>
        </div>

        <p class="result-note">
          描述文件可在「设置 → 通用 → VPN与设备管理」中删除
        </p>
      </template>

      <template v-else-if="!loading">
        <div class="result-icon">
          <el-icon size="48" color="#e6a23c"><WarningFilled /></el-icon>
        </div>
        <h2>等待获取中</h2>
        <p>请在设置中完成描述文件的安装</p>
        <button class="copy-btn" @click="fetchResult" style="margin-top: 16px">刷新</button>
      </template>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { udidApi } from '../api'

const route = useRoute()
const loading = ref(true)
const deviceInfo = ref(null)

async function fetchResult() {
  const id = route.query.id
  if (!id) { loading.value = false; return }

  try {
    const res = await udidApi.result(id)
    if (res.data?.status === 'success') {
      deviceInfo.value = res.data
    }
  } catch {}
  loading.value = false
}

function copyAll() {
  if (!deviceInfo.value) return
  const text = [
    `UDID: ${deviceInfo.value.udid}`,
    deviceInfo.value.device_name ? `设备: ${deviceInfo.value.device_name}` : '',
    deviceInfo.value.product ? `型号: ${deviceInfo.value.product}` : '',
    deviceInfo.value.version ? `系统: ${deviceInfo.value.version}` : '',
  ].filter(Boolean).join('\n')

  if (navigator.clipboard) {
    navigator.clipboard.writeText(text)
    alert('已复制到剪贴板')
  } else {
    const ta = document.createElement('textarea')
    ta.value = text
    document.body.appendChild(ta)
    ta.select()
    document.execCommand('copy')
    document.body.removeChild(ta)
    alert('已复制到剪贴板')
  }
}

onMounted(fetchResult)
</script>

<style scoped>
.result-page {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #f0f2f8, #e8ecf4);
  padding: 20px;
}

.result-card {
  width: 100%;
  max-width: 420px;
  background: rgba(255,255,255,0.95);
  backdrop-filter: blur(16px);
  -webkit-backdrop-filter: blur(16px);
  border-radius: 20px;
  padding: 44px 30px;
  text-align: center;
  box-shadow: 0 4px 24px rgba(0,0,0,0.08), 0 0 0 1px rgba(0,0,0,0.03);
}

.result-icon { margin-bottom: 16px; }

h2 { font-size: 22px; color: var(--nask-text); margin: 0 0 8px; font-weight: 700; }

.result-tip { color: var(--nask-text-muted); font-size: 14px; margin: 0 0 24px; }

.info-block {
  background: var(--nask-surface-hover);
  border-radius: var(--nask-radius-sm);
  padding: 16px;
  text-align: left;
  border: 1px solid var(--nask-border);
}

.info-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 8px 0;
  border-bottom: 1px solid var(--nask-border);
}

.info-row:last-child { border-bottom: none; }

.info-label {
  color: var(--nask-text-muted);
  font-size: 13px;
  flex-shrink: 0;
}

.info-value {
  color: var(--nask-text);
  font-size: 13px;
  text-align: right;
  word-break: break-all;
}

.info-value.udid {
  font-family: monospace;
  font-weight: 600;
  font-size: 12px;
  background: linear-gradient(135deg, rgba(64,158,255,0.08), rgba(144,106,252,0.08));
  padding: 4px 8px;
  border-radius: 6px;
  color: var(--nask-blue);
}

.result-actions { margin-top: 24px; }

.copy-btn {
  background: linear-gradient(135deg, #409EFF, #906AFC);
  color: #fff;
  border: none;
  border-radius: var(--nask-radius-sm);
  padding: 14px 32px;
  font-size: 16px;
  font-weight: 600;
  cursor: pointer;
  width: 100%;
  transition: all var(--nask-transition);
}

.copy-btn:hover {
  box-shadow: 0 6px 20px rgba(64,158,255,0.3);
  transform: translateY(-1px);
}

.copy-btn:active { background: linear-gradient(135deg, #3a8ee6, #7c5ce7); }

.result-note {
  color: var(--nask-text-muted);
  font-size: 12px;
  margin-top: 20px;
}
</style>
