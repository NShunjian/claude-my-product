import { create } from 'zustand'
import { persist } from 'zustand/middleware'
import { User } from '../types'
import { db } from '../db'
import { hashPassword, verifyPassword } from '../utils/auth'
import { v4 as uuidv4 } from 'uuid'

interface AuthState {
  currentUser: { id: string; username: string } | null
  isAuthenticated: boolean
  register: (username: string, password: string) => Promise<{ success: boolean; message: string }>
  login: (username: string, password: string) => Promise<{ success: boolean; message: string }>
  logout: () => void
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      currentUser: null,
      isAuthenticated: false,

      register: async (username, password) => {
        const trimmed = username.trim()
        if (trimmed.length < 2) {
          return { success: false, message: '用户名至少 2 个字符' }
        }
        if (password.length < 6) {
          return { success: false, message: '密码至少 6 位' }
        }

        const existing = await db.users.where('username').equals(trimmed).count()
        if (existing > 0) {
          return { success: false, message: '该用户名已被注册' }
        }

        const { hash, salt } = await hashPassword(password)
        const user: User = {
          id: uuidv4(),
          username: trimmed,
          passwordHash: hash,
          salt,
          createdAt: Date.now(),
        }
        await db.users.add(user)
        set({ currentUser: { id: user.id, username: user.username }, isAuthenticated: true })
        return { success: true, message: '注册成功' }
      },

      login: async (username, password) => {
        const trimmed = username.trim()
        const user = await db.users.where('username').equals(trimmed).first()
        if (!user) {
          return { success: false, message: '用户不存在' }
        }

        const valid = await verifyPassword(password, user.salt, user.passwordHash)
        if (!valid) {
          return { success: false, message: '密码错误' }
        }

        set({ currentUser: { id: user.id, username: user.username }, isAuthenticated: true })
        return { success: true, message: '登录成功' }
      },

      logout: () => {
        set({ currentUser: null, isAuthenticated: false })
      },
    }),
    {
      name: 'qingzhang-auth',
    }
  )
)
