import axios from 'axios'
import { ElMessage } from 'element-plus'

const api = axios.create({
  baseURL: '/api',
  timeout: 30000,
})

api.interceptors.request.use(config => {
  const token = localStorage.getItem('auth_token')
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

api.interceptors.response.use(
  response => response.data,
  error => {
    if (error.response?.status === 401) {
      localStorage.removeItem('auth_token')
      localStorage.removeItem('auth_user')
      window.location.href = '/login'
      return Promise.reject(error)
    }
    const msg = error.response?.data?.message || error.message || '请求失败'
    ElMessage.error(msg)
    return Promise.reject(error)
  }
)

export const authApi = {
  login: (data) => api.post('/auth/login', data),
  register: (data) => api.post('/auth/register', data),
  sendCode: (email, type) => api.post('/auth/send-code', { email, type }),
  logout: () => api.post('/auth/logout'),
  me: () => api.get('/auth/me'),
  changePassword: (data) => api.post('/auth/change-password', data),
  getUsers: () => api.get('/auth/users'),
  updateRole: (id, role) => api.put(`/auth/users/${id}/role`, { role }),
  deleteUser: (id) => api.delete(`/auth/users/${id}`),
  resetPassword: (id, new_password) => api.post(`/auth/users/${id}/reset-password`, { new_password }),
}

function downloadUrl(path) {
  const token = localStorage.getItem('auth_token') || ''
  const sep = path.includes('?') ? '&' : '?'
  return `/api${path}${sep}token=${token}`
}

export const accountApi = {
  list: () => api.get('/accounts'),
  get: (id) => api.get(`/accounts/${id}`),
  create: (data) => api.post('/accounts', data),
  update: (id, data) => api.put(`/accounts/${id}`, data),
  delete: (id) => api.delete(`/accounts/${id}`),
  test: (id) => api.post(`/accounts/${id}/test`),
  downloadP8: (id) => downloadUrl(`/accounts/${id}/download-p8`),
  uploadP8: (file) => {
    const formData = new FormData()
    formData.append('file', file)
    return api.post('/accounts/upload-p8', formData, { headers: { 'Content-Type': 'multipart/form-data' } })
  },
  validateP8: (content) => api.post('/accounts/validate-p8', { content }),
  importP8: (data) => {
    if (data.file) {
      const formData = new FormData()
      formData.append('file', data.file)
      formData.append('name', data.name)
      formData.append('issuer_id', data.issuer_id)
      formData.append('key_id', data.key_id)
      return api.post('/accounts/import-p8', formData, { headers: { 'Content-Type': 'multipart/form-data' } })
    }
    return api.post('/accounts/import-p8', data)
  },
}

export const dashboardApi = {
  stats: () => api.get('/dashboard'),
}

export const deviceApi = {
  list: (accountId) => api.get('/devices', { params: { account_id: accountId } }),
  detail: (deviceId) => api.get(`/devices/${deviceId}/detail`),
  register: (data) => api.post('/devices', data),
  batchRegister: (data) => api.post('/devices/batch', data),
  autoBindAll: (data) => api.post('/devices/auto-bindall', data),
  resources: (deviceId) => api.get(`/devices/${deviceId}/resources`),
  downloadBundle: (deviceId, certId, profileId) => {
    const params = new URLSearchParams()
    if (certId) params.set('cert_id', certId)
    if (profileId) params.set('profile_id', profileId)
    params.set('token', localStorage.getItem('auth_token') || '')
    return `/api/devices/${deviceId}/download-bundle?${params.toString()}`
  },
}

export const certApi = {
  list: (accountId) => api.get('/certificates', { params: { account_id: accountId } }),
  types: () => api.get('/certificates/types'),
  quota: (accountId) => api.get('/certificates/quota', { params: { account_id: accountId } }),
  create: (data) => api.post('/certificates/create', data),
  selfSign: (data) => api.post('/certificates/self-sign', data),
  generateCA: (data) => api.post('/certificates/generate-ca', data),
  detail: (id) => api.get(`/certificates/${id}/detail`),
  relations: (accountId) => api.get('/certificates/relations', { params: { account_id: accountId } }),
  download: (id) => downloadUrl(`/certificates/${id}/download`),
  downloadCer: (id) => downloadUrl(`/certificates/${id}/download-cer`),
  delete: (id) => api.delete(`/certificates/${id}`),
  pushGuide: () => api.get('/certificates/push-guide'),
}

export const profileApi = {
  list: (accountId) => api.get('/profiles', { params: { account_id: accountId } }),
  types: () => api.get('/profiles/types'),
  bundleIds: (accountId) => api.get('/profiles/bundle-ids', { params: { account_id: accountId } }),
  createBundleId: (data) => api.post('/profiles/bundle-ids', data),
  deleteBundleId: (id) => api.delete(`/profiles/bundle-ids/${id}`),
  create: (data) => api.post('/profiles/create', data),
  download: (id) => downloadUrl(`/profiles/${id}/download`),
  delete: (id) => api.delete(`/profiles/${id}`),
}

export const capabilityApi = {
  available: () => api.get('/capabilities/available'),
  list: (bundleId, accountId) => api.get(`/capabilities/${bundleId}`, { params: { account_id: accountId } }),
  enable: (data) => api.post('/capabilities/enable', data),
  disable: (data) => api.post('/capabilities/disable', data),
  batchEnable: (data) => api.post('/capabilities/batch-enable', data),
  batchDisable: (data) => api.post('/capabilities/batch-disable', data),
}

export const pushKeyApi = {
  list: () => api.get('/push-keys'),
  create: (data) => {
    if (data.file) {
      const formData = new FormData()
      formData.append('file', data.file)
      formData.append('name', data.name)
      formData.append('key_id', data.key_id)
      formData.append('team_id', data.team_id)
      if (data.bundle_ids) formData.append('bundle_ids', data.bundle_ids)
      return api.post('/push-keys', formData, { headers: { 'Content-Type': 'multipart/form-data' } })
    }
    return api.post('/push-keys', data)
  },
  update: (id, data) => api.put(`/push-keys/${id}`, data),
  delete: (id) => api.delete(`/push-keys/${id}`),
  download: (id) => downloadUrl(`/push-keys/${id}/download`),
}

export const pushApi = {
  send: (data) => api.post('/push/send', data),
  errorCodes: () => api.get('/push/error-codes'),
}

export const udidApi = {
  createRequest: () => api.post('/udid/create-request'),
  enrollUrl: (requestId, host) => `/api/udid/enroll/${requestId}?host=${encodeURIComponent(host)}`,
  result: (requestId) => api.get(`/udid/result/${requestId}`),
}

export const healthApi = {
  local: () => api.get('/healthcheck/local'),
  remote: (accountId) => api.get('/healthcheck/remote', { params: { account_id: accountId } }),
}

export default api
