import { useState } from 'react'
import type { FormEvent } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../auth/AuthContext'
import type { Credentials } from '../api/auth'

type Mode = 'login' | 'register'

export function Login() {
  const navigate = useNavigate()
  const { login, register } = useAuth()

  const [mode, setMode] = useState<Mode>('login')
  const [username, setUsername] = useState<string>('')
  const [password, setPassword] = useState<string>('')
  const [error, setError] = useState<string | null>(null)
  const [submitting, setSubmitting] = useState<boolean>(false)

  async function onSubmit(e: FormEvent<HTMLFormElement>): Promise<void> {
    e.preventDefault()
    if (!username || !password) {
      setError('请填写用户名和密码')
      return
    }
    setError(null)
    setSubmitting(true)

    try {
      const creds: Credentials = { username, password }
      if (mode === 'login') {
        await login(creds)
      } else {
        await register(creds)
      }
      navigate('/', { replace: true })
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : '操作失败'
      setError(msg)
    } finally {
      setSubmitting(false)
    }
  }

  function switchMode(next: Mode): void {
    setMode(next)
    setError(null)
  }

  const isLogin = mode === 'login'

  return (
    <div className="bg-bg-page text-text-primary min-h-screen flex items-center justify-center font-body-md text-body-md p-4">
      <div className="glass-card rounded-xl p-6 w-full max-w-md relative overflow-hidden">
        <div className="absolute -top-16 -right-16 w-32 h-32 bg-primary-light rounded-full mix-blend-multiply filter blur-2xl opacity-50" />
        <div className="absolute -bottom-16 -left-16 w-32 h-32 bg-surface-variant rounded-full mix-blend-multiply filter blur-2xl opacity-50" />

        <div className="text-center mb-8 relative z-10">
          <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-primary-light text-primary mb-4">
            <span className="material-symbols-outlined" style={{ fontSize: '32px' }}>
              currency_yuan
            </span>
          </div>
          <h1 className="font-display-lg text-display-lg text-primary mb-1">轻账</h1>
          <p className="text-on-surface-variant font-caption-sm text-caption-sm">记账，轻轻松松</p>
        </div>

        <div className="flex border-b border-divider mb-6 relative z-10">
          <button
            type="button"
            onClick={() => switchMode('login')}
            className={`flex-1 pb-2 border-b-2 font-headline-md text-headline-md transition-colors ${
              isLogin
                ? 'border-primary text-primary'
                : 'border-transparent text-on-surface-variant hover:text-text-primary'
            }`}
          >
            {isLogin ? '登录 ◉' : '登录 ○'}
          </button>
          <button
            type="button"
            onClick={() => switchMode('register')}
            className={`flex-1 pb-2 border-b-2 font-headline-md text-headline-md transition-colors ${
              !isLogin
                ? 'border-primary text-primary'
                : 'border-transparent text-on-surface-variant hover:text-text-primary'
            }`}
          >
            {!isLogin ? '注册 ◉' : '注册 ○'}
          </button>
        </div>

        <form onSubmit={onSubmit} className="space-y-4 relative z-10">
          <div>
            <label htmlFor="username" className="sr-only">
              用户名
            </label>
            <div className="relative">
              <span className="material-symbols-outlined absolute left-2 top-1/2 -translate-y-1/2 text-outline">
                person
              </span>
              <input
                id="username"
                type="text"
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                placeholder="用户名"
                autoComplete="username"
                disabled={submitting}
                className="w-full pl-8 pr-4 py-2 bg-surface-bright border-b border-divider focus:border-primary focus:ring-0 transition-colors bg-transparent text-text-primary placeholder-outline font-body-md text-body-md outline-none disabled:opacity-60"
              />
            </div>
          </div>

          <div>
            <label htmlFor="password" className="sr-only">
              密码
            </label>
            <div className="relative">
              <span className="material-symbols-outlined absolute left-2 top-1/2 -translate-y-1/2 text-outline">
                lock
              </span>
              <input
                id="password"
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="密码"
                autoComplete={isLogin ? 'current-password' : 'new-password'}
                disabled={submitting}
                className="w-full pl-8 pr-4 py-2 bg-surface-bright border-b border-divider focus:border-primary focus:ring-0 transition-colors bg-transparent text-text-primary placeholder-outline font-body-md text-body-md outline-none disabled:opacity-60"
              />
            </div>
          </div>

          {error !== null && (
            <p
              role="alert"
              className="font-caption-sm text-caption-sm text-error flex items-center gap-1"
            >
              <span className="material-symbols-outlined" style={{ fontSize: '14px' }}>
                error
              </span>
              {error}
            </p>
          )}

          <button
            type="submit"
            disabled={submitting}
            className="w-full bg-primary text-on-primary py-2 rounded-lg font-headline-md text-headline-md hover:bg-primary-container transition-colors shadow-sm mt-4 flex justify-center items-center gap-2 disabled:opacity-60 disabled:cursor-not-allowed"
          >
            {submitting ? '处理中…' : isLogin ? '登录' : '注册'}
            {isLogin ? (
              <span className="material-symbols-outlined text-sm">arrow_forward</span>
            ) : (
              <span className="material-symbols-outlined text-sm">person_add</span>
            )}
          </button>
        </form>

        <div className="mt-8 text-center relative z-10">
          <p className="font-caption-sm text-caption-sm text-outline flex items-center justify-center gap-1">
            <span className="material-symbols-outlined" style={{ fontSize: '14px' }}>
              info
            </span>
            数据由 QingZhang 后端保存
          </p>
        </div>
      </div>
    </div>
  )
}