import { defineStore } from 'pinia'
import { ref } from 'vue'
import * as api from '@/api/auth'
import type { User, Credentials } from '@/api/auth'
import { onAuthInvalid } from '@/api/http'

const TOKEN_KEY = 'qz_token'
const LAST_USERNAME_KEY = 'qz_last_username'

export const useAuthStore = defineStore('auth', () => {
  const token = ref<string | null>(uni.getStorageSync(TOKEN_KEY) ?? null)
  const user  = ref<User | null>(null)

  async function login(creds: Credentials) {
    const r = await api.login(creds)
    token.value = r.token
    uni.setStorageSync(TOKEN_KEY, r.token)
    // 记住本次登录的用户名,下次回到登录页时回填真实 username(避免浏览器把 displayName 误填到字段里)
    uni.setStorageSync(LAST_USERNAME_KEY, creds.username)
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
    // 退出登录时清掉记住的用户名,下次登录页只剩空字段(让用户从干净状态重新输入)
    uni.removeStorageSync(LAST_USERNAME_KEY)
  }

  function onInvalid() {
    token.value = null
    user.value = null
    uni.removeStorageSync(TOKEN_KEY)
    uni.removeStorageSync(LAST_USERNAME_KEY)
    uni.reLaunch({ url: '/pages/login/index' })
  }

  onAuthInvalid(onInvalid)

  return { token, user, login, me, logout, onInvalid, refreshUser: me, getLastUsername: () => uni.getStorageSync(LAST_USERNAME_KEY) ?? '' }
})
