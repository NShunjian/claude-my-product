import { useState, type FormEvent } from 'react'
import { Navigate, useNavigate, useLocation } from 'react-router-dom'
import { ApiError } from '../api/client'
import { useAdminAuth } from '../auth/AdminAuthContext'
import { useToast } from '../components/Toast'

export function AdminLogin() {
  const { login, isAuthenticated, isLoading } = useAdminAuth()
  const navigate = useNavigate()
  const location = useLocation()
  const { show } = useToast()

  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const from = (location.state as { from?: string } | null)?.from ?? '/dashboard'

  if (isLoading) return <div className="min-h-screen flex items-center justify-center text-on-surface-variant">正在校验登录态…</div>
  if (isAuthenticated) return <Navigate to={from} replace />

  async function onSubmit(e: FormEvent) {
    e.preventDefault()
    if (!username || !password) return
    setSubmitting(true)
    try {
      await login(username, password)
      show('success', '登录成功')
      navigate(from, { replace: true })
    } catch (err) {
      const msg = err instanceof ApiError ? err.message : '登录失败'
      show('error', msg)
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-bg-page">
      <form
        onSubmit={onSubmit}
        className="w-full max-w-sm bg-bg-card rounded-xl shadow-md p-8 border border-divider"
      >
        <h1 className="text-2xl font-bold text-primary mb-1">QingZhang Admin</h1>
        <p className="text-sm text-on-surface-variant mb-6">管理员登录</p>

        <label className="block mb-3">
          <span className="text-sm text-on-surface-variant">用户名</span>
          <input
            type="text"
            autoComplete="username"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            className="mt-1 w-full rounded-lg border border-divider px-3 py-2 focus:outline-none focus:border-primary"
            disabled={submitting}
          />
        </label>

        <label className="block mb-5">
          <span className="text-sm text-on-surface-variant">密码</span>
          <input
            type="password"
            autoComplete="current-password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="mt-1 w-full rounded-lg border border-divider px-3 py-2 focus:outline-none focus:border-primary"
            disabled={submitting}
          />
        </label>

        <button
          type="submit"
          disabled={submitting || !username || !password}
          className="w-full bg-primary text-on-primary rounded-lg py-2 font-medium disabled:opacity-50"
        >
          {submitting ? '登录中…' : '登录'}
        </button>
      </form>
    </div>
  )
}
