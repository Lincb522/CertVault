<template>
  <div>
    <div class="page-header">
      <h1>用户管理</h1>
      <p>管理系统中所有注册用户</p>
    </div>

    <div class="content-card">
      <el-table :data="users" v-loading="loading" style="width: 100%" :header-cell-style="{ background: 'var(--nask-surface-hover)', fontWeight: 600 }">
        <el-table-column prop="username" label="用户名" min-width="120">
          <template #default="{ row }">
            <div style="display: flex; align-items: center; gap: 10px">
              <div class="user-avatar">{{ row.username?.charAt(0).toUpperCase() }}</div>
              <span style="font-weight: 550">{{ row.username }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column prop="email" label="邮箱" min-width="200">
          <template #default="{ row }">
            <span>{{ row.email || '-' }}</span>
            <el-tag v-if="row.email && row.email_verified" type="success" size="small" style="margin-left: 6px">已验证</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="role" label="角色" width="140">
          <template #default="{ row }">
            <el-tag
              :type="row.role === 'superadmin' ? 'danger' : 'info'"
              effect="plain"
              round
            >
              {{ roleLabel(row.role) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="created_at" label="创建时间" width="180">
          <template #default="{ row }">
            <span style="color: var(--nask-text-secondary); font-size: 13px">{{ formatDate(row.created_at) }}</span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="150" fixed="right">
          <template #default="{ row }">
            <el-dropdown trigger="click">
              <el-button size="small" type="primary">
                操作 <el-icon style="margin-left:4px"><ArrowDown /></el-icon>
              </el-button>
              <template #dropdown>
                <el-dropdown-menu>
                  <el-dropdown-item @click="openRoleDialog(row)" :disabled="row.id === currentUserId">修改角色</el-dropdown-item>
                  <el-dropdown-item @click="openResetPwd(row)">重置密码</el-dropdown-item>
                  <el-dropdown-item divided @click="handleDelete(row)" :disabled="row.id === currentUserId" style="color: var(--nask-red)">删除用户</el-dropdown-item>
                </el-dropdown-menu>
              </template>
            </el-dropdown>
          </template>
        </el-table-column>
      </el-table>
    </div>

    <el-dialog v-model="showRoleDialog" title="修改角色" width="420px" destroy-on-close>
      <el-form label-width="80px">
        <el-form-item label="用户名">
          <span style="font-weight: 550">{{ editingUser?.username }}</span>
        </el-form-item>
        <el-form-item label="角色">
          <el-select v-model="newRole" style="width: 100%">
            <el-option label="普通用户" value="user" />
            <el-option label="超级管理员" value="superadmin" />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showRoleDialog = false">取消</el-button>
        <el-button type="primary" @click="handleUpdateRole" :loading="saving">确认</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="showResetPwd" title="重置密码" width="420px" destroy-on-close>
      <el-form label-width="80px">
        <el-form-item label="用户名">
          <span style="font-weight: 550">{{ editingUser?.username }}</span>
        </el-form-item>
        <el-form-item label="新密码" required>
          <el-input v-model="resetPwd" type="password" show-password placeholder="至少 6 位" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showResetPwd = false">取消</el-button>
        <el-button type="primary" @click="handleResetPwd" :loading="saving">确认重置</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { authApi } from '../api'

const users = ref([])
const loading = ref(false)
const saving = ref(false)
const showRoleDialog = ref(false)
const showResetPwd = ref(false)
const editingUser = ref(null)
const newRole = ref('')
const resetPwd = ref('')
const userInfo = JSON.parse(localStorage.getItem('auth_user') || '{}')
const currentUserId = ref('')

function roleLabel(role) {
  const map = { superadmin: '超级管理员', user: '普通用户' }
  return map[role] || role
}

function formatDate(d) {
  return d ? new Date(d).toLocaleString('zh-CN') : '-'
}

async function fetchUsers() {
  loading.value = true
  try {
    const res = await authApi.getUsers()
    users.value = res.data || []
    const me = users.value.find(u => u.username === userInfo.username)
    if (me) currentUserId.value = me.id
  } finally {
    loading.value = false
  }
}

function openRoleDialog(user) {
  editingUser.value = user
  newRole.value = user.role
  showRoleDialog.value = true
}

function openResetPwd(user) {
  editingUser.value = user
  resetPwd.value = ''
  showResetPwd.value = true
}

async function handleUpdateRole() {
  saving.value = true
  try {
    await authApi.updateRole(editingUser.value.id, newRole.value)
    ElMessage.success('角色修改成功')
    showRoleDialog.value = false
    fetchUsers()
  } finally {
    saving.value = false
  }
}

async function handleResetPwd() {
  if (!resetPwd.value || resetPwd.value.length < 6) {
    return ElMessage.warning('新密码至少 6 位')
  }
  saving.value = true
  try {
    await authApi.resetPassword(editingUser.value.id, resetPwd.value)
    ElMessage.success('密码重置成功')
    showResetPwd.value = false
  } finally {
    saving.value = false
  }
}

async function handleDelete(user) {
  try {
    await authApi.deleteUser(user.id)
    ElMessage.success('用户已删除')
    fetchUsers()
  } catch {}
}

onMounted(fetchUsers)
</script>

<style scoped>
.user-avatar {
  width: 32px;
  height: 32px;
  border-radius: 10px;
  background: linear-gradient(135deg, #409EFF, #906AFC);
  display: flex;
  align-items: center;
  justify-content: center;
  color: #fff;
  font-size: 14px;
  font-weight: 600;
  flex-shrink: 0;
}
</style>
