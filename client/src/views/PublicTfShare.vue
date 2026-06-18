<template>
  <div class="tf-public-wrap">
    <div class="tf-public-card">
      <div v-if="loading" class="tf-public-state">
        <el-icon class="is-loading" :size="36"><Loading /></el-icon>
        <p>加载中…</p>
      </div>

      <template v-else-if="errorMsg">
        <el-result icon="error" :title="errorMsg" sub-title="请联系管理员重新获取邀请链接" />
      </template>

      <template v-else-if="info">
        <p class="tf-public-badge">加入测试</p>
        <h1 class="tf-public-title">{{ info.app_name || '应用' }}</h1>
        <p class="tf-public-sub">{{ info.group_name || '测试组' }}</p>
        <p v-if="info.bundle_id" class="tf-public-meta">{{ info.bundle_id }}</p>

        <el-alert
          v-if="info.is_internal"
          type="warning"
          :closable="false"
          show-icon
          title="此为内部测试组，不能通过公开页面直接报名加入"
          class="tf-public-alert"
        >
          内部测试仅支持团队内部成员，请联系管理员手动处理。
        </el-alert>

        <template v-if="submitted">
          <el-result
            icon="success"
            title="提交成功"
            :sub-title="successSubtitle"
          />
        </template>

        <el-form v-else-if="!info.is_internal" label-position="top" class="tf-public-form" @submit.prevent="submit">
          <p class="tf-public-hint">填写邮箱和姓名后，系统会自动把你加入当前 TestFlight 测试组。</p>
          <el-form-item label="姓名" required>
            <el-input v-model="form.full_name" placeholder="例如：张三" maxlength="80" show-word-limit clearable />
          </el-form-item>
          <el-form-item label="邮箱" required>
            <el-input
              v-model="form.email"
              type="email"
              placeholder="用于接收 TestFlight 邀请"
              maxlength="120"
              clearable
            />
          </el-form-item>
          <el-button type="primary" size="large" round class="tf-public-btn" :loading="submitting" native-type="submit">
            提交并加入测试组
          </el-button>
          <p class="tf-public-note">即使管理员没有开启 Apple 的公开链接，也可以直接通过这个表单报名加入。</p>
        </el-form>

        <template v-if="info.public_link_enabled && info.public_link">
          <div class="tf-public-divider"></div>
          <p class="tf-public-hint">如果你正在 iPhone / iPad 上操作，也可以直接使用下面的 TestFlight 公开链接。</p>
          <div class="tf-public-link-box">
            <span class="tf-public-link-text">{{ info.public_link }}</span>
          </div>
          <el-button type="primary" plain size="large" round class="tf-public-btn" @click="copyApple">
            复制 TestFlight 链接
          </el-button>
        </template>

        <p class="tf-public-footer">由 CertVault 生成 · Apple TestFlight</p>
      </template>
    </div>
  </div>
</template>

<script setup>
import { computed, ref, reactive, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { ElMessage } from 'element-plus'
import { Loading } from '@element-plus/icons-vue'

const route = useRoute()
const loading = ref(true)
const errorMsg = ref('')
const info = ref(null)
const submitting = ref(false)
const submitted = ref(false)
const form = reactive({ full_name: '', email: '' })
const submitMessage = ref('')

const successSubtitle = computed(() => {
  if (submitMessage.value) return submitMessage.value
  return '系统已记录你的报名信息。若管理员已分发可用构建，你可以继续使用下方公开链接或等待 TestFlight 侧处理邀请。'
})

async function loadInfo() {
  const slug = route.params.slug
  loading.value = true
  errorMsg.value = ''
  info.value = null
  try {
    const res = await fetch(`/api/public/tf/${encodeURIComponent(slug)}`)
    const json = await res.json()
    if (!res.ok || !json.success) {
      errorMsg.value = json.message || '加载失败'
      return
    }
    info.value = json.data
    submitted.value = false
    submitMessage.value = ''
  } catch {
    errorMsg.value = '网络错误'
  } finally {
    loading.value = false
  }
}

async function submit() {
  const slug = route.params.slug
  const full_name = form.full_name.trim()
  const email = form.email.trim()
  if (!full_name) {
    ElMessage.warning('请填写姓名')
    return
  }
  if (!email) {
    ElMessage.warning('请填写邮箱')
    return
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    ElMessage.warning('邮箱格式不正确')
    return
  }
  submitting.value = true
  try {
    const res = await fetch(`/api/public/tf/${encodeURIComponent(slug)}/join`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ full_name, email }),
    })
    const json = await res.json()
    if (!res.ok || !json.success) {
      ElMessage.error(json.message || '提交失败')
      return
    }
    submitted.value = true
    submitMessage.value = json.message || ''
    info.value = {
      ...info.value,
      public_link_enabled: json.data?.public_link_enabled ?? info.value?.public_link_enabled,
      public_link: json.data?.public_link ?? info.value?.public_link,
    }
    ElMessage.success(json.message || '已提交')
  } catch {
    ElMessage.error('网络错误，请稍后重试')
  } finally {
    submitting.value = false
  }
}

function copyApple() {
  const link = info.value?.public_link
  if (!link) return
  navigator.clipboard.writeText(link).then(
    () => ElMessage.success('已复制'),
    () => ElMessage.warning('复制失败，请手动长按或选择复制')
  )
}

onMounted(loadInfo)
</script>

<style scoped>
.tf-public-wrap {
  min-height: 100vh;
  display: flex;
  align-items: flex-start;
  justify-content: center;
  padding: 32px 16px 48px;
  background: linear-gradient(165deg, #0f172a 0%, #1e293b 45%, #0f172a 100%);
  box-sizing: border-box;
}
.tf-public-card {
  width: 100%;
  max-width: 440px;
  background: rgba(255, 255, 255, 0.06);
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 20px;
  padding: 28px 22px 22px;
  backdrop-filter: blur(12px);
}
.tf-public-badge {
  margin: 0 0 8px;
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: #38bdf8;
}
.tf-public-title {
  margin: 0;
  font-size: 22px;
  font-weight: 700;
  color: #f8fafc;
  line-height: 1.3;
}
.tf-public-sub {
  margin: 8px 0 0;
  font-size: 15px;
  color: #94a3b8;
}
.tf-public-meta {
  margin: 6px 0 0;
  font-size: 12px;
  font-family: ui-monospace, monospace;
  color: #64748b;
  word-break: break-all;
}
.tf-public-alert {
  margin-top: 16px;
}
.tf-public-hint {
  margin: 0 0 16px;
  font-size: 13px;
  color: #cbd5e1;
  line-height: 1.5;
}
.tf-public-form {
  margin-top: 16px;
}
.tf-public-form :deep(.el-form-item__label) {
  color: #e2e8f0;
}
.tf-public-form :deep(.el-input__wrapper) {
  border-radius: 10px;
  background: rgba(15, 23, 42, 0.55);
  box-shadow: 0 0 0 1px rgba(148, 163, 184, 0.16) inset;
}
.tf-public-form :deep(.el-input__inner) {
  color: #f8fafc;
}
.tf-public-btn {
  width: 100%;
  margin-top: 8px;
}
.tf-public-note {
  margin: 12px 0 0;
  font-size: 12px;
  color: #94a3b8;
  line-height: 1.6;
}
.tf-public-divider {
  height: 1px;
  margin: 22px 0 18px;
  background: linear-gradient(90deg, rgba(125, 211, 252, 0), rgba(125, 211, 252, 0.28), rgba(125, 211, 252, 0));
}
.tf-public-link-box {
  padding: 12px 14px;
  border-radius: 12px;
  background: rgba(0, 0, 0, 0.35);
  border: 1px solid rgba(255, 255, 255, 0.08);
  margin-bottom: 4px;
}
.tf-public-link-text {
  font-size: 12px;
  word-break: break-all;
  color: #7dd3fc;
  line-height: 1.45;
}
.tf-public-footer {
  margin: 24px 0 0;
  font-size: 11px;
  color: #475569;
  text-align: center;
  line-height: 1.4;
}
.tf-public-state {
  text-align: center;
  padding: 40px 16px;
  color: #94a3b8;
}
.tf-public-state p {
  margin: 12px 0 0;
  font-size: 14px;
}
</style>
