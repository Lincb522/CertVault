<template>
  <div>
    <div class="page-header">
      <h1>TestFlight</h1>
      <p>管理测试分组、测试员和构建分发</p>
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
          <el-select v-model="selectedAppId" placeholder="先加载应用列表" filterable style="min-width: 300px" @change="onAppChange">
            <el-option v-for="a in apps" :key="a.id" :label="`${a.name} (${a.bundle_id})`" :value="a.id" />
          </el-select>
          <el-button @click="loadApps" :loading="appsLoading" size="small">
            <el-icon><Refresh /></el-icon> 刷新应用
          </el-button>
        </div>
      </div>

      <!-- Tab 切换 -->
      <el-tabs v-model="activeTab" type="border-card" class="content-card" style="border: none">
        <!-- 测试分组 -->
        <el-tab-pane label="测试分组" name="groups">
          <div class="card-header" style="margin-bottom: 12px">
            <h3 style="margin: 0">测试分组</h3>
            <div>
              <el-button type="primary" size="small" @click="showCreateGroupDialog = true" :disabled="!selectedAppId">
                <el-icon><Plus /></el-icon> 新建分组
              </el-button>
              <el-button size="small" @click="loadGroups" :loading="groupsLoading">
                <el-icon><Refresh /></el-icon>
              </el-button>
            </div>
          </div>
          <el-table :data="groups" stripe v-loading="groupsLoading" empty-text="暂无分组" row-key="id">
            <el-table-column prop="name" label="分组名称" min-width="150">
              <template #default="{ row }">
                <span style="font-weight: 600">{{ row.name }}</span>
              </template>
            </el-table-column>
            <el-table-column prop="is_internal" label="类型" width="90">
              <template #default="{ row }">
                <el-tag :type="row.is_internal ? 'warning' : 'primary'" size="small">
                  {{ row.is_internal ? '内部' : '外部' }}
                </el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="public_link_enabled" label="公开链接" width="90">
              <template #default="{ row }">
                <el-tag :type="row.public_link_enabled ? 'success' : 'info'" size="small">
                  {{ row.public_link_enabled ? '开启' : '关闭' }}
                </el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="created_date" label="创建时间" min-width="160">
              <template #default="{ row }">{{ formatDate(row.created_date) }}</template>
            </el-table-column>
            <el-table-column label="操作" width="340" fixed="right">
              <template #default="{ row }">
                <el-button size="small" @click="viewGroupTesters(row)">
                  <el-icon><User /></el-icon> 测试员
                </el-button>
                <el-button
                  size="small"
                  type="success"
                  plain
                  :loading="shareTargetId === row.id"
                  :disabled="!!shareTargetId && shareTargetId !== row.id"
                  @click="createUserShare(row)"
                >
                  <el-icon><Link /></el-icon> 邀请链接
                </el-button>
                <el-button size="small" type="primary" @click="openDistributeDialog(row)">
                  <el-icon><Promotion /></el-icon> 分发
                </el-button>
                <el-button size="small" type="danger" @click="deleteGroup(row)">
                  <el-icon><Delete /></el-icon>
                </el-button>
              </template>
            </el-table-column>
          </el-table>
        </el-tab-pane>

        <!-- 测试员 -->
        <el-tab-pane label="测试员" name="testers">
          <div class="card-header" style="margin-bottom: 12px">
            <h3 style="margin: 0">测试员列表</h3>
            <div>
              <el-button type="primary" size="small" @click="showAddTesterDialog = true">
                <el-icon><Plus /></el-icon> 添加测试员
              </el-button>
              <el-button size="small" @click="loadTesters" :loading="testersLoading">
                <el-icon><Refresh /></el-icon>
              </el-button>
            </div>
          </div>
          <el-table :data="testers" stripe v-loading="testersLoading" empty-text="暂无测试员" row-key="id">
            <el-table-column prop="email" label="邮箱" min-width="200">
              <template #default="{ row }">
                <el-text style="font-family: monospace">{{ row.email }}</el-text>
              </template>
            </el-table-column>
            <el-table-column label="姓名" min-width="120">
              <template #default="{ row }">{{ [row.first_name, row.last_name].filter(Boolean).join(' ') || '-' }}</template>
            </el-table-column>
            <el-table-column prop="invite_type" label="邀请方式" width="100">
              <template #default="{ row }">
                <el-tag size="small" effect="plain">{{ row.invite_type || '-' }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="state" label="状态" width="100">
              <template #default="{ row }">
                <el-tag :type="row.state === 'ACCEPTED' ? 'success' : row.state === 'INVITED' ? 'warning' : 'info'" size="small">
                  {{ testerStateLabel(row.state) }}
                </el-tag>
              </template>
            </el-table-column>
            <el-table-column label="操作" width="100" fixed="right">
              <template #default="{ row }">
                <el-button size="small" type="danger" @click="deleteTester(row)">
                  <el-icon><Delete /></el-icon>
                </el-button>
              </template>
            </el-table-column>
          </el-table>
        </el-tab-pane>

        <!-- 构建 -->
        <el-tab-pane label="构建版本" name="builds">
          <div class="card-header" style="margin-bottom: 12px">
            <h3 style="margin: 0">构建版本</h3>
            <el-button size="small" @click="loadBuilds" :loading="buildsLoading" :disabled="!selectedAppId">
              <el-icon><Refresh /></el-icon>
            </el-button>
          </div>
          <el-table :data="builds" stripe v-loading="buildsLoading" empty-text="暂无构建版本" row-key="id">
            <el-table-column prop="version" label="版本号" width="100">
              <template #default="{ row }">
                <el-tag effect="plain" size="small">{{ row.version }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="processing_state" label="状态" width="110">
              <template #default="{ row }">
                <el-tag :type="buildStateType(row.processing_state)" size="small">{{ row.processing_state }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="min_os_version" label="最低系统" width="100" />
            <el-table-column prop="uploaded_date" label="上传时间" min-width="160">
              <template #default="{ row }">{{ formatDate(row.uploaded_date) }}</template>
            </el-table-column>
            <el-table-column prop="expired" label="过期" width="70">
              <template #default="{ row }">
                <el-tag :type="row.expired ? 'danger' : 'success'" size="small">{{ row.expired ? '是' : '否' }}</el-tag>
              </template>
            </el-table-column>
          </el-table>
        </el-tab-pane>
      </el-tabs>
    </template>

    <!-- 新建分组弹窗 -->
    <el-dialog v-model="showCreateGroupDialog" title="新建测试分组" width="460px" destroy-on-close>
      <el-form label-width="80px">
        <el-form-item label="分组名称">
          <el-input v-model="newGroupForm.name" placeholder="例如：内部测试组" />
        </el-form-item>
        <el-form-item label="分组类型">
          <el-radio-group v-model="newGroupForm.is_internal">
            <el-radio :value="false">外部测试</el-radio>
            <el-radio :value="true">内部测试</el-radio>
          </el-radio-group>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showCreateGroupDialog = false">取消</el-button>
        <el-button type="primary" @click="createGroup" :loading="groupCreating">创建</el-button>
      </template>
    </el-dialog>

    <!-- 添加测试员弹窗 -->
    <el-dialog v-model="showAddTesterDialog" title="添加测试员" width="460px" destroy-on-close>
      <el-form label-width="80px">
        <el-form-item label="邮箱">
          <el-input v-model="newTesterForm.email" placeholder="tester@example.com" />
        </el-form-item>
        <el-form-item label="名">
          <el-input v-model="newTesterForm.first_name" placeholder="可选" />
        </el-form-item>
        <el-form-item label="姓">
          <el-input v-model="newTesterForm.last_name" placeholder="可选" />
        </el-form-item>
        <el-form-item label="加入分组">
          <el-select v-model="newTesterForm.group_ids" multiple placeholder="可选" style="width: 100%">
            <el-option v-for="g in groups" :key="g.id" :label="g.name" :value="g.id" />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showAddTesterDialog = false">取消</el-button>
        <el-button type="primary" @click="addTester" :loading="testerAdding">添加</el-button>
      </template>
    </el-dialog>

    <!-- 分组测试员弹窗 -->
    <el-dialog v-model="showGroupTestersDialog" :title="`分组测试员 — ${selectedGroup?.name || ''}`" width="600px" destroy-on-close>
      <div style="margin-bottom: 14px; display: flex; align-items: center; gap: 10px">
        <el-tag :type="selectedGroup?.is_internal ? 'warning' : 'primary'" size="small">
          {{ selectedGroup?.is_internal ? '内部测试组' : '外部测试组' }}
        </el-tag>
        <el-tag size="small" effect="plain">{{ groupTesters.length }} 位测试员</el-tag>
      </div>
      <el-table :data="groupTesters" stripe v-loading="groupTestersLoading" empty-text="暂无测试员">
        <el-table-column prop="email" label="邮箱" min-width="200" />
        <el-table-column label="姓名" min-width="120">
          <template #default="{ row }">{{ [row.first_name, row.last_name].filter(Boolean).join(' ') || '-' }}</template>
        </el-table-column>
        <el-table-column prop="state" label="状态" width="100">
          <template #default="{ row }">
            <el-tag :type="row.state === 'ACCEPTED' ? 'success' : 'warning'" size="small">{{ testerStateLabel(row.state) }}</el-tag>
          </template>
        </el-table-column>
      </el-table>
    </el-dialog>

    <!-- 用户端公开页链接（发给测试员，无需登录） -->
    <el-dialog v-model="showShareUrlDialog" title="邀请测试员填写信息" width="520px" destroy-on-close>
      <p style="font-size: 13px; color: var(--nask-text-secondary); margin: 0 0 12px; line-height: 1.55">
        将下方链接发给测试员。对方<strong>无需登录</strong>，在页面填写<strong>姓名与邮箱</strong>即可加入本测试组，Apple 会向其邮箱发送 TestFlight 邀请。
      </p>
      <el-input v-model="shareUrlFull" readonly type="textarea" :rows="2" />
      <template #footer>
        <el-button @click="showShareUrlDialog = false">关闭</el-button>
        <el-button type="primary" @click="copyShareUrl">
          <el-icon><DocumentCopy /></el-icon> 复制链接
        </el-button>
      </template>
    </el-dialog>

    <!-- 分发构建弹窗 -->
    <el-dialog v-model="showDistributeDialog" :title="`分发构建到「${selectedGroup?.name || ''}`" width="560px" destroy-on-close>
      <el-alert v-if="!builds.length" type="info" title="请先在「构建版本」Tab 中加载构建列表" :closable="false" style="margin-bottom: 12px" />
      <el-form label-width="90px">
        <el-form-item label="选择构建" required>
          <el-select v-model="distributeForm.build_ids" multiple placeholder="选择要分发的构建版本" style="width: 100%">
            <el-option v-for="b in builds.filter(b => !b.expired && b.processing_state === 'VALID')" :key="b.id"
              :label="`v${b.version} (${formatDate(b.uploaded_date)})`" :value="b.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="测试内容">
          <el-input v-model="distributeForm.whats_new" type="textarea" :rows="4"
            placeholder="告诉测试员本次需要测试什么内容（What to Test）" />
        </el-form-item>
        <el-form-item label="语言">
          <el-select v-model="distributeForm.locale" style="width: 200px">
            <el-option label="简体中文" value="zh-Hans" />
            <el-option label="English (US)" value="en-US" />
            <el-option label="English (UK)" value="en-GB" />
            <el-option label="繁體中文" value="zh-Hant" />
            <el-option label="日本語" value="ja" />
            <el-option label="한국어" value="ko" />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showDistributeDialog = false">取消</el-button>
        <el-button type="primary" @click="distributeBuild" :loading="distributing">
          <el-icon><Promotion /></el-icon> 分发
        </el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, watch } from 'vue'
import { useAppStore } from '../stores/app'
import { appsApi, testflightApi } from '../api'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Refresh, Warning, Plus, Delete, User, Promotion, Box, Link, DocumentCopy } from '@element-plus/icons-vue'

const store = useAppStore()
const activeTab = ref('groups')

const apps = ref([])
const appsLoading = ref(false)
const selectedAppId = ref('')

const groups = ref([])
const groupsLoading = ref(false)
const testers = ref([])
const testersLoading = ref(false)
const builds = ref([])
const buildsLoading = ref(false)

const showCreateGroupDialog = ref(false)
const groupCreating = ref(false)
const newGroupForm = ref({ name: '', is_internal: false })

const showAddTesterDialog = ref(false)
const testerAdding = ref(false)
const newTesterForm = ref({ email: '', first_name: '', last_name: '', group_ids: [] })

const showGroupTestersDialog = ref(false)
const selectedGroup = ref(null)
const groupTesters = ref([])
const groupTestersLoading = ref(false)

const showDistributeDialog = ref(false)
const distributeForm = ref({ build_ids: [], whats_new: '', locale: 'zh-Hans' })
const distributing = ref(false)

const showShareUrlDialog = ref(false)
const shareUrlFull = ref('')
const shareTargetId = ref(null)

function adminBaseUrl() {
  const base = import.meta.env.BASE_URL || '/admin/'
  return `${window.location.origin}${base.replace(/\/$/, '')}`
}

async function createUserShare(row) {
  if (!store.currentAccountId) return
  shareTargetId.value = row.id
  try {
    const res = await testflightApi.createShareLink({
      account_id: store.currentAccountId,
      group_id: row.id,
    })
    const path = res.data?.path || ''
    shareUrlFull.value = `${adminBaseUrl()}${path}`
    showShareUrlDialog.value = true
    ElMessage.success('已生成邀请链接')
  } catch (e) {
    console.error(e)
  } finally {
    shareTargetId.value = null
  }
}

function copyShareUrl() {
  if (!shareUrlFull.value) return
  navigator.clipboard.writeText(shareUrlFull.value).then(
    () => ElMessage.success('已复制'),
    () => ElMessage.warning('复制失败，请手动选择文本复制')
  )
}

async function loadApps() {
  if (!store.currentAccountId) return
  appsLoading.value = true
  try {
    const res = await appsApi.list(store.currentAccountId)
    apps.value = res.data || []
  } catch (e) { console.error(e) }
  finally { appsLoading.value = false }
}

function onAppChange() {
  groups.value = []
  builds.value = []
  loadGroups()
  loadBuilds()
}

async function loadGroups() {
  if (!store.currentAccountId) return
  groupsLoading.value = true
  try {
    const res = await testflightApi.groups(store.currentAccountId, selectedAppId.value || undefined)
    groups.value = res.data || []
  } catch (e) { console.error(e) }
  finally { groupsLoading.value = false }
}

async function loadTesters() {
  if (!store.currentAccountId) return
  testersLoading.value = true
  try {
    const res = await testflightApi.testers(store.currentAccountId)
    testers.value = res.data || []
  } catch (e) { console.error(e) }
  finally { testersLoading.value = false }
}

async function loadBuilds() {
  if (!store.currentAccountId || !selectedAppId.value) return
  buildsLoading.value = true
  try {
    const res = await testflightApi.builds(store.currentAccountId, selectedAppId.value)
    builds.value = res.data || []
  } catch (e) { console.error(e) }
  finally { buildsLoading.value = false }
}

async function createGroup() {
  if (!newGroupForm.value.name) return ElMessage.warning('请输入分组名称')
  groupCreating.value = true
  try {
    await testflightApi.createGroup({
      account_id: store.currentAccountId,
      app_id: selectedAppId.value,
      name: newGroupForm.value.name,
      is_internal: newGroupForm.value.is_internal,
    })
    ElMessage.success('分组创建成功')
    showCreateGroupDialog.value = false
    newGroupForm.value = { name: '', is_internal: false }
    loadGroups()
  } catch (e) { console.error(e) }
  finally { groupCreating.value = false }
}

async function deleteGroup(row) {
  try {
    await ElMessageBox.confirm(`确定删除分组「${row.name}」？`, '确认删除', { type: 'warning' })
    await testflightApi.deleteGroup(row.id, store.currentAccountId)
    ElMessage.success('分组已删除')
    loadGroups()
  } catch (e) { if (e !== 'cancel') console.error(e) }
}

async function viewGroupTesters(row) {
  selectedGroup.value = row
  showGroupTestersDialog.value = true
  groupTestersLoading.value = true
  try {
    const res = await testflightApi.groupTesters(row.id, store.currentAccountId)
    groupTesters.value = res.data || []
  } catch (e) { console.error(e) }
  finally { groupTestersLoading.value = false }
}

function openDistributeDialog(row) {
  selectedGroup.value = row
  distributeForm.value = { build_ids: [], whats_new: '', locale: 'zh-Hans' }
  showDistributeDialog.value = true
}

async function distributeBuild() {
  if (!distributeForm.value.build_ids.length) return ElMessage.warning('请选择构建版本')
  distributing.value = true
  try {
    const payload = {
      account_id: store.currentAccountId,
      build_ids: distributeForm.value.build_ids,
    }
    if (distributeForm.value.whats_new) {
      payload.whats_new = distributeForm.value.whats_new
      payload.locale = distributeForm.value.locale || 'zh-Hans'
    }
    await testflightApi.addBuildsToGroup(selectedGroup.value.id, payload)
    ElMessage.success('构建已分发到测试分组')
    showDistributeDialog.value = false
  } catch (e) { console.error(e) }
  finally { distributing.value = false }
}

async function addTester() {
  if (!newTesterForm.value.email) return ElMessage.warning('请输入邮箱')
  testerAdding.value = true
  try {
    await testflightApi.createTester({
      account_id: store.currentAccountId,
      ...newTesterForm.value,
    })
    ElMessage.success('测试员已添加')
    showAddTesterDialog.value = false
    newTesterForm.value = { email: '', first_name: '', last_name: '', group_ids: [] }
    loadTesters()
  } catch (e) { console.error(e) }
  finally { testerAdding.value = false }
}

async function deleteTester(row) {
  try {
    await ElMessageBox.confirm(`确定删除测试员「${row.email}」？`, '确认删除', { type: 'warning' })
    await testflightApi.deleteTester(row.id, store.currentAccountId)
    ElMessage.success('测试员已删除')
    loadTesters()
  } catch (e) { if (e !== 'cancel') console.error(e) }
}

function testerStateLabel(state) {
  const map = { ACCEPTED: '已接受', INVITED: '已邀请', NOT_INVITED: '未邀请', REVOKED: '已撤销' }
  return map[state] || state || '-'
}

function buildStateType(state) {
  const map = { VALID: 'success', PROCESSING: 'warning', FAILED: 'danger', INVALID: 'danger' }
  return map[state] || 'info'
}

function formatDate(d) {
  if (!d) return '-'
  return new Date(d).toLocaleString('zh-CN')
}

watch(() => store.currentAccountId, () => {
  apps.value = []
  selectedAppId.value = ''
  groups.value = []
  testers.value = []
  builds.value = []
  loadApps()
  loadTesters()
}, { immediate: true })
</script>
