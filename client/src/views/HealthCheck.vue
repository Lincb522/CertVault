<template>
  <div>
    <div class="page-header">
      <h1>健康检查</h1>
      <p>检测证书有效性、描述文件状态和 Bundle ID 权限配置</p>
    </div>

    <!-- 操作栏 -->
    <div class="content-card">
      <div class="card-header">
        <h3>检查操作</h3>
        <div>
          <el-button type="primary" @click="runLocalCheck" :loading="localLoading">
            <el-icon><Monitor /></el-icon> 本地检查
          </el-button>
          <el-button type="warning" @click="runRemoteCheck" :loading="remoteLoading" :disabled="!store.currentAccountId">
            <el-icon><Connection /></el-icon> Apple API 远程检查
          </el-button>
        </div>
      </div>
      <el-alert v-if="!store.currentAccountId" type="info" :closable="false">
        本地检查可立即执行；远程检查需先在左侧选择一个账号
      </el-alert>
    </div>

    <!-- 汇总概览 -->
    <div v-if="localResult || remoteResult" class="stat-grid">
      <div class="stat-card">
        <div class="stat-icon red"><HIcon name="warning" /></div>
        <div class="stat-info">
          <div class="stat-value">{{ totalSummary.critical }}</div>
          <div class="stat-label">严重问题</div>
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-icon orange"><HIcon name="danger-circle" /></div>
        <div class="stat-info">
          <div class="stat-value">{{ totalSummary.warning }}</div>
          <div class="stat-label">警告</div>
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-icon blue"><HIcon name="information-circle" /></div>
        <div class="stat-info">
          <div class="stat-value">{{ totalSummary.info }}</div>
          <div class="stat-label">提示</div>
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-icon green"><HIcon name="tick-circle" /></div>
        <div class="stat-info">
          <div class="stat-value">{{ totalSummary.ok }}</div>
          <div class="stat-label">正常</div>
        </div>
      </div>
    </div>

    <!-- 问题列表 -->
    <div v-if="allIssues.length" class="content-card">
      <div class="card-header">
        <h3>发现的问题 ({{ allIssues.length }})</h3>
        <el-radio-group v-model="issueFilter" size="small">
          <el-radio-button value="all">全部</el-radio-button>
          <el-radio-button value="critical">严重</el-radio-button>
          <el-radio-button value="warning">警告</el-radio-button>
          <el-radio-button value="info">提示</el-radio-button>
        </el-radio-group>
      </div>

      <div class="issue-list">
        <div
          v-for="(issue, i) in filteredIssues"
          :key="i"
          class="issue-item"
          :class="issue.severity"
        >
          <div class="issue-icon">
            <el-icon v-if="issue.severity === 'critical'" color="#f56c6c" size="20"><CircleCloseFilled /></el-icon>
            <el-icon v-else-if="issue.severity === 'warning'" color="#e6a23c" size="20"><WarningFilled /></el-icon>
            <el-icon v-else color="#409eff" size="20"><InfoFilled /></el-icon>
          </div>
          <div class="issue-content">
            <div class="issue-header">
              <el-tag size="small" :type="severityTag[issue.severity]">{{ severityLabel[issue.severity] }}</el-tag>
              <el-tag size="small" type="info" effect="plain">{{ typeLabel[issue.type] || issue.type }}</el-tag>
              <span class="issue-name" v-if="issue.name">{{ issue.name }}</span>
            </div>
            <div class="issue-message">{{ issue.message }}</div>
            <div class="issue-suggestion">
              <el-icon size="14"><Promotion /></el-icon>
              {{ issue.suggestion }}
            </div>
          </div>
          <div class="issue-action">
            <el-button
              v-if="issue.type === 'certificate' || issue.type === 'remote_certificate'"
              size="small" type="primary"
              @click="$router.push('/certificates')"
            >
              去处理
            </el-button>
            <el-button
              v-else-if="issue.type === 'profile' || issue.type === 'remote_profile'"
              size="small" type="primary"
              @click="$router.push('/profiles')"
            >
              去处理
            </el-button>
            <el-button
              v-else-if="issue.type === 'capability'"
              size="small" type="primary"
              @click="$router.push(`/capabilities?bundle_id=${issue.bundle_id}`)"
            >
              去配置
            </el-button>
            <el-button
              v-else-if="issue.type === 'account'"
              size="small" type="primary"
              @click="$router.push('/accounts')"
            >
              去处理
            </el-button>
          </div>
        </div>
      </div>
    </div>

    <!-- 证书有效期看板 -->
    <el-row :gutter="20" v-if="localResult || remoteResult">
      <el-col :xs="24" :sm="12">
        <div class="content-card">
          <div class="card-header"><h3>证书有效期</h3></div>
          <el-table :data="allCerts" stripe size="small" empty-text="暂无证书">
            <el-table-column prop="name" label="名称" min-width="150" show-overflow-tooltip />
            <el-table-column prop="type" label="类型" width="140" show-overflow-tooltip />
            <el-table-column label="状态" width="140">
              <template #default="{ row }">
                <el-tag size="small" :color="row.color" style="color:#fff; border:none">
                  {{ row.label }}
                </el-tag>
              </template>
            </el-table-column>
            <el-table-column label="过期日期" width="110">
              <template #default="{ row }">
                {{ row.expires_at ? new Date(row.expires_at).toLocaleDateString() : '-' }}
              </template>
            </el-table-column>
          </el-table>
        </div>
      </el-col>

      <el-col :xs="24" :sm="12">
        <div class="content-card">
          <div class="card-header"><h3>描述文件有效期</h3></div>
          <el-table :data="allProfiles" stripe size="small" empty-text="暂无描述文件">
            <el-table-column prop="name" label="名称" min-width="150" show-overflow-tooltip />
            <el-table-column prop="type" label="类型" width="140" show-overflow-tooltip />
            <el-table-column label="状态" width="140">
              <template #default="{ row }">
                <el-tag size="small" :color="row.color" style="color:#fff; border:none">
                  {{ row.label }}
                </el-tag>
              </template>
            </el-table-column>
            <el-table-column label="过期日期" width="110">
              <template #default="{ row }">
                {{ row.expires_at ? new Date(row.expires_at).toLocaleDateString() : '-' }}
              </template>
            </el-table-column>
          </el-table>
        </div>
      </el-col>
    </el-row>

    <!-- Bundle ID 权限检查结果 -->
    <div v-if="remoteResult?.capabilities?.length" class="content-card">
      <div class="card-header">
        <h3>Bundle ID 权限概览</h3>
      </div>
      <el-table :data="remoteResult.capabilities" stripe size="small">
        <el-table-column prop="identifier" label="Bundle Identifier" min-width="250">
          <template #default="{ row }">
            <el-text style="font-family: monospace">{{ row.identifier }}</el-text>
          </template>
        </el-table-column>
        <el-table-column prop="name" label="名称" width="150" />
        <el-table-column prop="enabled_count" label="已开启权限数" width="120" align="center" />
        <el-table-column label="推送" width="80" align="center">
          <template #default="{ row }">
            <el-icon v-if="row.has_push" color="#67c23a"><CircleCheckFilled /></el-icon>
            <el-icon v-else color="var(--nask-text-muted)"><CircleCloseFilled /></el-icon>
          </template>
        </el-table-column>
        <el-table-column label="Apple登录" width="100" align="center">
          <template #default="{ row }">
            <el-icon v-if="row.has_sign_in" color="#67c23a"><CircleCheckFilled /></el-icon>
            <el-icon v-else color="var(--nask-text-muted)"><CircleCloseFilled /></el-icon>
          </template>
        </el-table-column>
        <el-table-column label="已开启权限" min-width="300">
          <template #default="{ row }">
            <el-space wrap :size="4">
              <el-tag v-for="cap in row.capabilities" :key="cap" size="small" effect="plain" type="success">
                {{ cap }}
              </el-tag>
              <el-tag v-if="!row.capabilities.length" size="small" type="info">无</el-tag>
            </el-space>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="80">
          <template #default="{ row }">
            <el-button size="small" link type="primary" @click="$router.push(`/capabilities?bundle_id=${row.bundle_id}`)">
              管理
            </el-button>
          </template>
        </el-table-column>
      </el-table>
    </div>

    <!-- 空状态 -->
    <div v-if="!localResult && !remoteResult" class="content-card">
      <div class="empty-state">
        <HIcon name="tick-circle" :size="48" />
        <p style="margin-top: 12px; font-size: 15px">点击上方按钮开始检查</p>
        <p style="color: var(--nask-text-secondary); font-size: 13px">本地检查：扫描数据库中的证书和描述文件有效期</p>
        <p style="color: var(--nask-text-secondary); font-size: 13px">远程检查：通过 Apple API 验证证书、描述文件和 Bundle ID 权限状态</p>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'
import { ElMessage } from 'element-plus'
import HIcon from '../components/HIcon.vue'
import { healthApi } from '../api'
import { useAppStore } from '../stores/app'

const store = useAppStore()
const localLoading = ref(false)
const remoteLoading = ref(false)
const localResult = ref(null)
const remoteResult = ref(null)
const issueFilter = ref('all')

const severityTag = { critical: 'danger', warning: 'warning', info: '' }
const severityLabel = { critical: '严重', warning: '警告', info: '提示' }
const typeLabel = {
  certificate: '本地证书',
  profile: '本地描述文件',
  account: '账号配置',
  api: 'API 连接',
  remote_certificate: 'Apple 证书',
  remote_profile: 'Apple 描述文件',
  capability: '权限配置',
}

const totalSummary = computed(() => {
  const s = { critical: 0, warning: 0, info: 0, ok: 0 }
  if (localResult.value?.summary) {
    s.critical += localResult.value.summary.critical
    s.warning += localResult.value.summary.warning
    s.info += localResult.value.summary.info
    s.ok += localResult.value.summary.ok
  }
  if (remoteResult.value) {
    const remoteCerts = remoteResult.value.certificates || []
    const remoteProfiles = remoteResult.value.profiles || []
    ;[...remoteCerts, ...remoteProfiles].forEach(item => {
      s[item.severity]++
    })
  }
  return s
})

const allIssues = computed(() => {
  const local = localResult.value?.issues || []
  const remote = remoteResult.value?.issues || []
  return [...local, ...remote]
})

const filteredIssues = computed(() => {
  if (issueFilter.value === 'all') return allIssues.value
  return allIssues.value.filter(i => i.severity === issueFilter.value)
})

const allCerts = computed(() => {
  const local = localResult.value?.certificates || []
  const remote = remoteResult.value?.certificates || []
  if (remote.length) return remote
  return local
})

const allProfiles = computed(() => {
  const local = localResult.value?.profiles || []
  const remote = remoteResult.value?.profiles || []
  if (remote.length) return remote
  return local
})

async function runLocalCheck() {
  localLoading.value = true
  try {
    const res = await healthApi.local()
    localResult.value = res.data
    const s = res.data.summary
    if (s.critical > 0) {
      ElMessage.error(`发现 ${s.critical} 个严重问题，请及时处理`)
    } else if (s.warning > 0) {
      ElMessage.warning(`发现 ${s.warning} 个警告`)
    } else {
      ElMessage.success('本地检查通过，一切正常')
    }
  } finally {
    localLoading.value = false
  }
}

async function runRemoteCheck() {
  remoteLoading.value = true
  try {
    const res = await healthApi.remote(store.currentAccountId)
    remoteResult.value = res.data
    if (res.data.api_status === 'failed') {
      ElMessage.error('Apple API 连接失败')
    } else {
      const issues = res.data.issues || []
      const critical = issues.filter(i => i.severity === 'critical').length
      if (critical > 0) {
        ElMessage.error(`远程检查发现 ${critical} 个严重问题`)
      } else if (issues.length > 0) {
        ElMessage.warning(`远程检查发现 ${issues.length} 个问题`)
      } else {
        ElMessage.success('远程检查通过，一切正常')
      }
    }
  } finally {
    remoteLoading.value = false
  }
}
</script>

<style scoped>
.issue-list {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.issue-item {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  padding: 14px 16px;
  border-radius: var(--nask-radius-sm);
  border: 1px solid var(--nask-border);
  transition: all var(--nask-transition);
}

.issue-item:hover {
  box-shadow: var(--nask-shadow-sm);
}

.issue-item.critical {
  border-left: 4px solid var(--nask-red);
  background: rgba(239,68,68,0.04);
}

.issue-item.warning {
  border-left: 4px solid var(--nask-orange);
  background: rgba(245,158,11,0.04);
}

.issue-item.info {
  border-left: 4px solid var(--nask-blue);
  background: rgba(64,158,255,0.04);
}

.issue-icon {
  flex-shrink: 0;
  padding-top: 2px;
}

.issue-content {
  flex: 1;
  min-width: 0;
}

.issue-header {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-bottom: 4px;
}

.issue-name {
  font-weight: 600;
  font-size: 13px;
  color: var(--nask-text);
}

.issue-message {
  font-size: 14px;
  color: var(--nask-text);
  line-height: 1.5;
}

.issue-suggestion {
  display: flex;
  align-items: center;
  gap: 4px;
  font-size: 12px;
  color: var(--nask-text-muted);
  margin-top: 4px;
}

.issue-action {
  flex-shrink: 0;
  align-self: center;
}

@media (max-width: 768px) {
  .issue-item {
    flex-direction: column;
    gap: 8px;
  }
  .issue-action {
    align-self: flex-start;
  }
  .issue-header {
    flex-wrap: wrap;
  }
}
</style>
