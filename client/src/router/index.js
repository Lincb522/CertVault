import { createRouter, createWebHistory } from 'vue-router'

const routes = [
  { path: '/login', name: 'Login', component: () => import('../views/Login.vue'), meta: { public: true } },
  { path: '/register', name: 'Register', component: () => import('../views/Register.vue'), meta: { public: true } },
  { path: '/', name: 'Dashboard', component: () => import('../views/Dashboard.vue'), meta: { title: '仪表盘' } },
  { path: '/users', name: 'Users', component: () => import('../views/Users.vue'), meta: { title: '用户管理', requireSuperAdmin: true } },
  { path: '/accounts', name: 'Accounts', component: () => import('../views/Accounts.vue'), meta: { title: '账号管理' } },
  { path: '/devices', name: 'Devices', component: () => import('../views/Devices.vue'), meta: { title: '设备管理' } },
  { path: '/certificates', name: 'Certificates', component: () => import('../views/Certificates.vue'), meta: { title: '证书管理' } },
  { path: '/profiles', name: 'Profiles', component: () => import('../views/Profiles.vue'), meta: { title: '描述文件' } },
  { path: '/capabilities', name: 'Capabilities', component: () => import('../views/Capabilities.vue'), meta: { title: '权限管理' } },
  { path: '/healthcheck', name: 'HealthCheck', component: () => import('../views/HealthCheck.vue'), meta: { title: '健康检查' } },
  { path: '/get-udid', name: 'GetUDID', component: () => import('../views/GetUDID.vue'), meta: { title: '获取 UDID' } },
  { path: '/udid-result', name: 'UDIDResult', component: () => import('../views/UDIDResult.vue'), meta: { title: 'UDID 结果', public: true } },
  { path: '/push-keys', name: 'PushKeys', component: () => import('../views/PushKeys.vue'), meta: { title: '推送密钥' } },
  { path: '/push', name: 'PushTest', component: () => import('../views/PushTest.vue'), meta: { title: '推送测试' } },
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

router.beforeEach((to, from, next) => {
  if (to.meta.public) return next()
  const token = localStorage.getItem('auth_token')
  if (!token) return next('/login')
  if (to.meta.requireSuperAdmin) {
    const user = JSON.parse(localStorage.getItem('auth_user') || '{}')
    if (user.role !== 'superadmin') return next('/')
  }
  next()
})

export default router
