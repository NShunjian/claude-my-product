import { defineStore } from 'pinia'
import { ref } from 'vue'
import * as api from '@/api/auth'
import type { User, Credentials } from '@/api/auth'
import { onAuthInvalid } from '@/api/http'

const TOKEN_KEY = 'qz_token'

export const useAuthStore = defineStore('auth', () => {
  const token = ref<string | null>(uni.getStorageSync(TOKEN_KEY) ?? null)
  const user  = ref<User | null>(null)

  async function login(creds: Credentials) {
    const r = await api.login(creds)
    token.value = r.token
    uni.setStorageSync(TOKEN_KEY, r.token)
    user.value = r.user
    return r
  }

  async function me() {
    const u = await api.me()
    user.value = u
    return u
  }

  async function logout() {
    try { await api.logout() } catch { /* 容忍 */ }
    token.value = null
    user.value = null
    uni.removeStorageSync(TOKEN_KEY)
  }

  function onInvalid() {
    token.value = null
    user.value = null
    uni.removeStorageSync(TOKEN_KEY)
    uni.reLaunch({ url: '/pages/login/index' })
  }

  onAuthInvalid(onInvalid)

  return { token, user, login, me, logout, onInvalid }
})
