import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { accountApi } from '../api'

export const useAppStore = defineStore('app', () => {
  const accounts = ref([])
  const currentAccountId = ref(localStorage.getItem('currentAccountId') || '')
  const loading = ref(false)

  const currentAccount = computed(() =>
    accounts.value.find(a => a.id === currentAccountId.value) || null
  )

  async function fetchAccounts() {
    loading.value = true
    try {
      const res = await accountApi.list()
      accounts.value = res.data || []
      if (!currentAccountId.value && accounts.value.length > 0) {
        setCurrentAccount(accounts.value[0].id)
      }
      if (currentAccountId.value && !accounts.value.find(a => a.id === currentAccountId.value)) {
        setCurrentAccount(accounts.value[0]?.id || '')
      }
    } finally {
      loading.value = false
    }
  }

  function setCurrentAccount(id) {
    currentAccountId.value = id
    localStorage.setItem('currentAccountId', id)
  }

  return { accounts, currentAccountId, currentAccount, loading, fetchAccounts, setCurrentAccount }
})
