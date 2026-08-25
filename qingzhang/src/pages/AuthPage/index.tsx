import React, { useState } from 'react'
import { useAuthStore } from '../../stores/useAuthStore'

const AuthPage: React.FC = () => {
  const { login, register } = useAuthStore()
  const [mode, setMode] = useState<'login' | 'register'>('login')
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    setLoading(true)

    const result =
      mode === 'login' ? await login(username, password) : await register(username, password)

    if (!result.success) {
      setError(result.message)
    }
    setLoading(false)
  }

  const switchMode = (next: 'login' | 'register') => {
    setMode(next)
    setError('')
    setUsername('')
    setPassword('')
  }

  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-[var(--color-bg-page)] px-6">
      <div className="mb-10 text-center">
        <div className="mx-auto mb-4 flex h-20 w-20 items-center justify-center rounded-3xl bg-[var(--color-primary)] text-5xl text-white shadow-lg">
          ¥
        </div>
        <h1 className="text-2xl font-bold text-[var(--color-text-primary)]">轻账</h1>
        <p className="mt-1 text-sm text-[var(--color-text-secondary)]">记账，轻轻松松</p>
      </div>

      <div className="w-full max-w-sm rounded-3xl bg-[var(--color-bg-card)] p-6 shadow-md">
        <div className="mb-6 flex rounded-full bg-[var(--color-bg-page)] p-1">
          <button
            onClick={() => switchMode('login')}
            className={`flex-1 rounded-full py-2 text-sm font-medium transition-all ${
              mode === 'login'
                ? 'bg-[var(--color-primary)] text-white'
                : 'text-[var(--color-text-secondary)]'
            }`}
          >
            登录
          </button>
          <button
            onClick={() => switchMode('register')}
            className={`flex-1 rounded-full py-2 text-sm font-medium transition-all ${
              mode === 'register'
                ? 'bg-[var(--color-primary)] text-white'
                : 'text-[var(--color-text-secondary)]'
            }`}
          >
            注册
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="mb-1 block text-sm text-[var(--color-text-secondary)]">用户名</label>
            <input
              type="text"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              className="w-full rounded-xl border border-[var(--color-divider)] bg-[var(--color-bg-page)] px-4 py-3 text-[var(--color-text-primary)] outline-none focus:border-[var(--color-primary)]"
              placeholder="请输入用户名"
              autoComplete="username"
            />
          </div>
          <div>
            <label className="mb-1 block text-sm text-[var(--color-text-secondary)]">密码</label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full rounded-xl border border-[var(--color-divider)] bg-[var(--color-bg-page)] px-4 py-3 text-[var(--color-text-primary)] outline-none focus:border-[var(--color-primary)]"
              placeholder="请输入密码"
              autoComplete={mode === 'login' ? 'current-password' : 'new-password'}
            />
          </div>

          {error && (
            <div className="rounded-lg bg-[var(--color-danger)]/10 px-3 py-2 text-sm text-[var(--color-danger)]">
              {error}
            </div>
          )}

          <button
            type="submit"
            disabled={loading || !username || !password}
            className="w-full rounded-xl bg-[var(--color-primary)] py-3 font-medium text-white transition-all disabled:opacity-50"
          >
            {loading ? '处理中...' : mode === 'login' ? '登录' : '注册'}
          </button>
        </form>

        {mode === 'register' && (
          <p className="mt-4 text-center text-xs text-[var(--color-text-secondary)]">
            用户名至少 2 个字符，密码至少 6 位
          </p>
        )}
      </div>

      <p className="mt-6 text-xs text-[var(--color-text-secondary)]">
        数据仅保存在本地浏览器，请勿在公共设备使用
      </p>
    </div>
  )
}

export default AuthPage
