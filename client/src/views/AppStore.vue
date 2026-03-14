<template>
  <div>
    <div class="page-header">
      <h1>App Store 版本</h1>
      <p>管理应用版本、审核状态、本地化信息，支持提交审核</p>
    </div>

    <div v-if="!store.currentAccountId" class="content-card">
      <div class="empty-state">
        <el-icon><Warning /></el-icon>
        <p>请先在左侧选择一个账号</p>
      </div>
    </div>

    <template v-else>
      <!-- App 选择 -->
      <div class="content-card" style="margin-bottom: 20px; padding: 12px 20px">
        <div style="display: flex; align-items: center; gap: 12px; flex-wrap: wrap">
          <span style="font-weight: 600; white-space: nowrap">选择 App：</span>
          <el-select v-model="selectedAppId" placeholder="先加载应用列表" filterable style="min-width: 300px" @change="loadVersions">
            <el-option v-for="a in apps" :key="a.id" :label="`${a.name} (${a.bundle_id})`" :value="a.id" />
          </el-select>
          <el-button @click="loadApps" :loading="appsLoading" size="small">
            <el-icon><Refresh /></el-icon> 刷新应用
          </el-button>
        </div>
      </div>

      <!-- 版本列表 -->
      <div class="content-card">
        <div class="card-header">
          <h3>版本列表</h3>
          <div>
            <el-button type="primary" size="small" @click="showCreateVersionDialog = true" :disabled="!selectedAppId">
              <el-icon><Plus /></el-icon> 新建版本
            </el-button>
            <el-button size="small" @click="loadVersions" :loading="versionsLoading" :disabled="!selectedAppId">
              <el-icon><Refresh /></el-icon>
            </el-button>
          </div>
        </div>

        <el-table :data="versions" stripe v-loading="versionsLoading" empty-text="请选择应用查看版本" row-key="id">
          <el-table-column prop="version" label="版本号" width="100">
            <template #default="{ row }">
              <strong>{{ row.version }}</strong>
            </template>
          </el-table-column>
          <el-table-column prop="state" label="状态" min-width="150">
            <template #default="{ row }">
              <el-tag :type="stateType(row.state)" size="small">{{ row.state_label || row.state }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="platform" label="平台" width="80">
            <template #default="{ row }">
              <el-tag size="small" effect="plain">{{ row.platform }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="release_type" label="发布方式" width="110">
            <template #default="{ row }">{{ releaseTypeLabel(row.release_type) }}</template>
          </el-table-column>
          <el-table-column prop="created_date" label="创建时间" min-width="160">
            <template #default="{ row }">{{ formatDate(row.created_date) }}</template>
          </el-table-column>
          <el-table-column label="操作" width="260" fixed="right">
            <template #default="{ row }">
              <el-button size="small" @click="viewVersionDetail(row)">
                <el-icon><View /></el-icon> 详情
              </el-button>
              <el-button size="small" type="warning" @click="submitReview(row)"
                :disabled="!canSubmit(row.state)">
                <el-icon><Check /></el-icon> 提交审核
              </el-button>
            </template>
          </el-table-column>
        </el-table>
      </div>
    </template>

    <!-- 新建版本弹窗 -->
    <el-dialog v-model="showCreateVersionDialog" title="新建 App Store 版本" width="460px" destroy-on-close>
      <el-form label-width="90px">
        <el-form-item label="版本号">
          <el-input v-model="newVersionForm.version_string" placeholder="例如：1.2.0" />
        </el-form-item>
        <el-form-item label="平台">
          <el-select v-model="newVersionForm.platform" style="width: 100%">
            <el-option label="iOS" value="IOS" />
            <el-option label="macOS" value="MAC_OS" />
            <el-option label="tvOS" value="TV_OS" />
            <el-option label="visionOS" value="VISION_OS" />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showCreateVersionDialog = false">取消</el-button>
        <el-button type="primary" @click="createVersion" :loading="versionCreating">创建</el-button>
      </template>
    </el-dialog>

    <!-- 版本详情弹窗 -->
    <el-dialog v-model="showDetailDialog" :title="`版本详情 — v${versionDetail?.version || ''}`" width="640px" destroy-on-close>
      <div v-if="versionDetail" v-loading="detailLoading">
        <div style="display: flex; align-items: center; gap: 10px; margin-bottom: 20px; flex-wrap: wrap">
          <el-tag :type="stateType(versionDetail.state)" size="default" effect="dark" round>
            {{ versionDetail.state_label || versionDetail.state }}
          </el-tag>
          <el-tag size="small" effect="plain">{{ versionDetail.platform }}</el-tag>
          <el-tag size="small" effect="plain">{{ releaseTypeLabel(versionDetail.release_type) }}</el-tag>
          <span v-if="versionDetail.created_date" style="font-size: 12px; color: var(--nask-text-secondary); margin-left: auto">
            创建于 {{ formatDate(versionDetail.created_date) }}
          </span>
        </div>

        <!-- 构建版本 -->
        <div style="margin-bottom: 16px; padding: 12px 16px; background: var(--el-fill-color-lighter); border-radius: 8px">
          <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 8px">
            <span style="font-weight: 600; font-size: 14px">构建版本</span>
            <el-button size="small" type="primary" link @click="showBuildPicker = true" :disabled="!canEditBuild(versionDetail.state)">
              <el-icon><Link /></el-icon> {{ currentBuild ? '更换构建' : '关联构建' }}
            </el-button>
          </div>
          <div v-if="currentBuild">
            <el-descriptions :column="2" size="small" border>
              <el-descriptions-item label="版本号">{{ currentBuild.version }}</el-descriptions-item>
              <el-descriptions-item label="处理状态">
                <el-tag :type="currentBuild.processing_state === 'VALID' ? 'success' : 'warning'" size="small">
                  {{ currentBuild.processing_state }}
                </el-tag>
              </el-descriptions-item>
              <el-descriptions-item label="上传时间">{{ formatDate(currentBuild.uploaded_date) }}</el-descriptions-item>
            </el-descriptions>
          </div>
          <div v-else style="color: var(--nask-text-muted); font-size: 13px">
            尚未关联构建版本
          </div>
        </div>

        <!-- 分阶段发布 -->
        <div style="margin-bottom: 16px; padding: 12px 16px; background: var(--el-fill-color-lighter); border-radius: 8px">
          <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 8px">
            <span style="font-weight: 600; font-size: 14px">分阶段发布</span>
          </div>
          <div v-if="phasedRelease">
            <el-descriptions :column="2" size="small" border style="margin-bottom: 10px">
              <el-descriptions-item label="状态">
                <el-tag :type="phasedStateType(phasedRelease.state)" size="small">{{ phasedStateLabel(phasedRelease.state) }}</el-tag>
              </el-descriptions-item>
              <el-descriptions-item label="当前天数">第 {{ phasedRelease.current_day_number || 0 }} 天 / 7 天</el-descriptions-item>
              <el-descriptions-item label="开始时间">{{ formatDate(phasedRelease.start_date) }}</el-descriptions-item>
              <el-descriptions-item label="暂停时长">{{ phasedRelease.total_pause_duration || 0 }} 天</el-descriptions-item>
            </el-descriptions>
            <div style="display: flex; gap: 8px">
              <el-button v-if="phasedRelease.state === 'ACTIVE'" size="small" type="warning" @click="updatePhasedRelease('PAUSE')" :loading="phasedLoading">
                暂停发布
              </el-button>
              <el-button v-if="phasedRelease.state === 'PAUSED'" size="small" type="success" @click="updatePhasedRelease('RESUME')" :loading="phasedLoading">
                恢复发布
              </el-button>
              <el-button v-if="phasedRelease.state === 'ACTIVE' || phasedRelease.state === 'PAUSED'" size="small" type="primary" @click="updatePhasedRelease('COMPLETE')" :loading="phasedLoading">
                立即全量发布
              </el-button>
              <el-button size="small" type="danger" plain @click="removePhasedRelease" :loading="phasedLoading">
                取消分阶段
              </el-button>
            </div>
          </div>
          <div v-else>
            <div style="color: var(--nask-text-muted); font-size: 13px; margin-bottom: 8px">未启用分阶段发布</div>
            <el-button size="small" type="primary" @click="createPhasedRelease" :loading="phasedLoading"
              :disabled="versionDetail?.state !== 'PENDING_DEVELOPER_RELEASE'">
              启用分阶段发布
            </el-button>
          </div>
        </div>

        <template v-for="loc in (versionDetail.localizations || [])" :key="loc.id">
          <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 12px; padding-top: 8px; border-top: 1px solid var(--nask-border)">
            <div style="display: flex; align-items: center; gap: 8px">
              <span style="font-weight: 600; font-size: 14px">本地化 — {{ loc.locale }}</span>
            </div>
            <el-button size="small" type="primary" link @click="editLocalization(loc)">
              <el-icon><Edit /></el-icon> 编辑
            </el-button>
          </div>
          <el-descriptions :column="1" border size="small" style="margin-bottom: 16px">
            <el-descriptions-item label="更新说明">
              <span style="white-space: pre-wrap">{{ loc.whats_new || '-' }}</span>
            </el-descriptions-item>
            <el-descriptions-item label="描述">
              <span style="white-space: pre-wrap; max-height: 100px; overflow-y: auto; display: block">{{ loc.description || '-' }}</span>
            </el-descriptions-item>
            <el-descriptions-item label="关键词">{{ loc.keywords || '-' }}</el-descriptions-item>
            <el-descriptions-item label="营销 URL">{{ loc.marketing_url || '-' }}</el-descriptions-item>
            <el-descriptions-item label="支持 URL">{{ loc.support_url || '-' }}</el-descriptions-item>
          </el-descriptions>
        </template>
      </div>
    </el-dialog>

    <!-- 编辑本地化弹窗 -->
    <el-dialog v-model="showLocEditDialog" title="编辑本地化信息" width="600px" destroy-on-close>
      <el-form label-width="90px" v-if="locEditForm">
        <el-form-item label="更新说明">
          <el-input v-model="locEditForm.whats_new" type="textarea" :rows="4" placeholder="本次更新的内容" />
        </el-form-item>
        <el-form-item label="描述">
          <el-input v-model="locEditForm.description" type="textarea" :rows="5" placeholder="应用描述" />
        </el-form-item>
        <el-form-item label="关键词">
          <el-input v-model="locEditForm.keywords" placeholder="用逗号分隔" />
        </el-form-item>
        <el-form-item label="宣传文本">
          <el-input v-model="locEditForm.promotional_text" type="textarea" :rows="2" />
        </el-form-item>
        <el-form-item label="营销 URL">
          <el-input v-model="locEditForm.marketing_url" placeholder="https://..." />
        </el-form-item>
        <el-form-item label="支持 URL">
          <el-input v-model="locEditForm.support_url" placeholder="https://..." />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showLocEditDialog = false">取消</el-button>
        <el-button type="primary" @click="saveLocalization" :loading="locSaving">保存</el-button>
      </template>
    </el-dialog>

    <!-- 选择构建版本弹窗 -->
    <el-dialog v-model="showBuildPicker" title="选择构建版本" width="520" destroy-on-close>
      <el-table :data="availableBuilds" stripe size="small" v-loading="buildsLoading" empty-text="暂无可用构建">
        <el-table-column prop="version" label="版本号" width="100" />
        <el-table-column prop="processing_state" label="状态" width="100">
          <template #default="{ row }">
            <el-tag :type="row.processing_state === 'VALID' ? 'success' : 'warning'" size="small">{{ row.processing_state }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="上传时间" min-width="160">
          <template #default="{ row }">{{ formatDate(row.uploaded_date) }}</template>
        </el-table-column>
        <el-table-column label="" width="80">
          <template #default="{ row }">
            <el-button size="small" type="primary" @click="selectBuild(row)">选择</el-button>
          </template>
        </el-table-column>
      </el-table>
      <template #footer>
        <el-button @click="showBuildPicker = false">取消</el-button>
        <el-button v-if="currentBuild" type="danger" plain @click="unlinkBuild">取消关联</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, watch } from 'vue'
import { useAppStore } from '../stores/app'
import { appsApi, appstoreApi } from '../api'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Refresh, Warning, Plus, View, Check, Document, Edit, Link } from '@element-plus/icons-vue'

const store = useAppStore()

const apps = ref([])
const appsLoading = ref(false)
const selectedAppId = ref('')
const versions = ref([])
const versionsLoading = ref(false)

const showCreateVersionDialog = ref(false)
const versionCreating = ref(false)
const newVersionForm = ref({ version_string: '', platform: 'IOS' })

const showDetailDialog = ref(false)
const versionDetail = ref(null)
const detailLoading = ref(false)

const showLocEditDialog = ref(false)
const locEditForm = ref(null)
const locEditId = ref('')
const locSaving = ref(false)

const currentBuild = ref(null)
const showBuildPicker = ref(false)
const availableBuilds = ref([])
const buildsLoading = ref(false)
const phasedRelease = ref(null)
const phasedLoading = ref(false)

async function loadApps() {
  if (!store.currentAccountId) return
  appsLoading.value = true
  try {
    const res = await appsApi.list(store.currentAccountId)
    apps.value = res.data || []
  } catch (e) { console.error(e) }
  finally { appsLoading.value = false }
}

async function loadVersions() {
  if (!store.currentAccountId || !selectedAppId.value) {
    versions.value = []
    return
  }
  versionsLoading.value = true
  try {
    const res = await appstoreApi.versions(store.currentAccountId, selectedAppId.value)
    versions.value = res.data || []
  } catch (e) { console.error(e) }
  finally { versionsLoading.value = false }
}

async function createVersion() {
  if (!newVersionForm.value.version_string) return ElMessage.warning('请输入版本号')
  versionCreating.value = true
  try {
    await appstoreApi.createVersion({
      account_id: store.currentAccountId,
      app_id: selectedAppId.value,
      ...newVersionForm.value,
    })
    ElMessage.success('版本创建成功')
    showCreateVersionDialog.value = false
    newVersionForm.value = { version_string: '', platform: 'IOS' }
    loadVersions()
  } catch (e) { console.error(e) }
  finally { versionCreating.value = false }
}

async function viewVersionDetail(row) {
  versionDetail.value = row
  showDetailDialog.value = true
  detailLoading.value = true
  currentBuild.value = null
  phasedRelease.value = null
  try {
    const res = await appstoreApi.versionDetail(row.id, store.currentAccountId)
    versionDetail.value = res.data
    await Promise.all([
      loadVersionBuild(row.id),
      loadPhasedRelease(row.id),
    ])
  } catch (e) { console.error(e) }
  finally { detailLoading.value = false }
}

async function submitReview(row) {
  try {
    await ElMessageBox.confirm(`确定提交 v${row.version} 进行审核？`, '提交审核', { type: 'warning' })
    await appstoreApi.submitForReview(row.id, store.currentAccountId)
    ElMessage.success('已提交审核')
    loadVersions()
  } catch (e) { if (e !== 'cancel') console.error(e) }
}

function editLocalization(loc) {
  locEditId.value = loc.id
  locEditForm.value = {
    whats_new: loc.whats_new || '',
    description: loc.description || '',
    keywords: loc.keywords || '',
    promotional_text: loc.promotional_text || '',
    marketing_url: loc.marketing_url || '',
    support_url: loc.support_url || '',
  }
  showLocEditDialog.value = true
}

async function saveLocalization() {
  locSaving.value = true
  try {
    await appstoreApi.updateLocalization(locEditId.value, {
      account_id: store.currentAccountId,
      ...locEditForm.value,
    })
    ElMessage.success('本地化信息已更新')
    showLocEditDialog.value = false
    if (versionDetail.value) viewVersionDetail(versionDetail.value)
  } catch (e) { console.error(e) }
  finally { locSaving.value = false }
}

function canEditBuild(state) {
  return ['PREPARE_FOR_SUBMISSION', 'READY_FOR_REVIEW'].includes(state)
}

async function loadVersionBuild(versionId) {
  try {
    const res = await appstoreApi.versionBuild(versionId, store.currentAccountId)
    currentBuild.value = res.data || null
  } catch { currentBuild.value = null }
}

async function loadPhasedRelease(versionId) {
  try {
    const res = await appstoreApi.phasedRelease(versionId, store.currentAccountId)
    phasedRelease.value = res.data || null
  } catch { phasedRelease.value = null }
}

async function loadBuilds() {
  if (!selectedAppId.value) return
  buildsLoading.value = true
  try {
    const res = await appsApi.builds(selectedAppId.value, store.currentAccountId)
    availableBuilds.value = (res.data || []).filter(b => b.processing_state === 'VALID')
  } catch { availableBuilds.value = [] }
  finally { buildsLoading.value = false }
}

async function selectBuild(build) {
  try {
    await appstoreApi.setVersionBuild(versionDetail.value.id, {
      account_id: store.currentAccountId,
      build_id: build.id,
    })
    ElMessage.success('构建版本已关联')
    currentBuild.value = build
    showBuildPicker.value = false
  } catch {}
}

async function unlinkBuild() {
  try {
    await appstoreApi.setVersionBuild(versionDetail.value.id, {
      account_id: store.currentAccountId,
      build_id: null,
    })
    ElMessage.success('已取消关联')
    currentBuild.value = null
    showBuildPicker.value = false
  } catch {}
}

async function createPhasedRelease() {
  phasedLoading.value = true
  try {
    await appstoreApi.createPhasedRelease(versionDetail.value.id, store.currentAccountId)
    ElMessage.success('已启用分阶段发布')
    await loadPhasedRelease(versionDetail.value.id)
  } catch {} finally { phasedLoading.value = false }
}

async function updatePhasedRelease(state) {
  phasedLoading.value = true
  try {
    await appstoreApi.updatePhasedRelease(phasedRelease.value.id, {
      account_id: store.currentAccountId,
      state,
    })
    ElMessage.success('分阶段发布状态已更新')
    await loadPhasedRelease(versionDetail.value.id)
  } catch {} finally { phasedLoading.value = false }
}

async function removePhasedRelease() {
  try {
    await ElMessageBox.confirm('确定取消分阶段发布？', '取消确认', { type: 'warning' })
    phasedLoading.value = true
    await appstoreApi.deletePhasedRelease(phasedRelease.value.id, store.currentAccountId)
    ElMessage.success('已取消分阶段发布')
    phasedRelease.value = null
  } catch {} finally { phasedLoading.value = false }
}

function phasedStateLabel(state) {
  const map = { INACTIVE: '未激活', ACTIVE: '发布中', PAUSED: '已暂停', COMPLETE: '已完成' }
  return map[state] || state || '-'
}

function phasedStateType(state) {
  const map = { INACTIVE: 'info', ACTIVE: 'success', PAUSED: 'warning', COMPLETE: 'primary' }
  return map[state] || 'info'
}

function canSubmit(state) {
  return ['PREPARE_FOR_SUBMISSION', 'READY_FOR_REVIEW'].includes(state)
}

function stateType(state) {
  const map = {
    READY_FOR_SALE: 'success', ACCEPTED: 'success', PREPARE_FOR_SUBMISSION: 'info',
    WAITING_FOR_REVIEW: 'warning', IN_REVIEW: 'warning', READY_FOR_REVIEW: 'warning',
    REJECTED: 'danger', METADATA_REJECTED: 'danger', DEVELOPER_REJECTED: 'danger',
    DEVELOPER_REMOVED_FROM_SALE: 'info', REMOVED_FROM_SALE: 'danger',
    PENDING_DEVELOPER_RELEASE: 'warning', PENDING_APPLE_RELEASE: 'warning',
  }
  return map[state] || 'info'
}


function releaseTypeLabel(type) {
  const map = { MANUAL: '手动发布', AFTER_APPROVAL: '审核通过后自动', SCHEDULED: '定时发布' }
  return map[type] || type || '-'
}

function formatDate(d) {
  if (!d) return '-'
  return new Date(d).toLocaleString('zh-CN')
}

watch(showBuildPicker, (val) => {
  if (val) loadBuilds()
})

watch(() => store.currentAccountId, () => {
  apps.value = []
  selectedAppId.value = ''
  versions.value = []
  loadApps()
}, { immediate: true })
</script>
