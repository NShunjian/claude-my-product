import { useNavigate } from 'react-router-dom'
import { useAuth } from '../auth/AuthContext'

export function Dashboard() {
  const navigate = useNavigate()
  const { user, logout } = useAuth()

  if (!user) {
    return (
      <div className="bg-bg-page text-text-primary min-h-screen flex items-center justify-center font-body-md text-body-md">
        加载中…
      </div>
    )
  }

  function onLogout(): void {
    logout()
    navigate('/login', { replace: true })
  }

  const createdAt = new Date(user.createdAt).toLocaleString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  })

  return (
    <div className="bg-bg-page text-text-primary min-h-screen font-body-md text-body-md p-4">
      <div className="max-w-md mx-auto">
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-primary-light text-primary mb-4">
            <span className="material-symbols-outlined" style={{ fontSize: '32px' }}>
              account_circle
            </span>
          </div>
          <h1 className="font-display-lg text-display-lg text-primary mb-1">你好，{user.username}</h1>
          <p className="text-on-surface-variant font-caption-sm text-caption-sm">
            已登录到 QingZhang
          </p>
        </div>

        <div className="glass-card rounded-xl p-6 relative overflow-hidden">
          <div className="absolute -top-16 -right-16 w-32 h-32 bg-primary-light rounded-full mix-blend-multiply filter blur-2xl opacity-50" />
          <div className="absolute -bottom-16 -left-16 w-32 h-32 bg-surface-variant rounded-full mix-blend-multiply filter blur-2xl opacity-50" />

          <dl className="relative z-10 space-y-4">
            <div>
              <dt className="font-caption-sm text-caption-sm text-on-surface-variant">用户 ID</dt>
              <dd className="font-label-mono text-label-mono text-text-primary">{user.id}</dd>
            </div>
            <div>
              <dt className="font-caption-sm text-caption-sm text-on-surface-variant">UUID</dt>
              <dd className="font-caption-sm text-caption-sm text-text-primary break-all">
                {user.uuid}
              </dd>
            </div>
            <div>
              <dt className="font-caption-sm text-caption-sm text-on-surface-variant">显示名</dt>
              <dd className="font-body-md text-body-md text-text-primary">
                {user.displayName ?? <span className="text-outline">未设置</span>}
              </dd>
            </div>
            <div>
              <dt className="font-caption-sm text-caption-sm text-on-surface-variant">注册时间</dt>
              <dd className="font-body-md text-body-md text-text-primary">{createdAt}</dd>
            </div>
          </dl>
        </div>

        <button
          type="button"
          onClick={onLogout}
          className="w-full mt-6 bg-surface-bright text-text-primary py-2 rounded-lg font-headline-md text-headline-md hover:bg-divider transition-colors shadow-sm flex justify-center items-center gap-2"
        >
          退出登录
          <span className="material-symbols-outlined text-sm">logout</span>
        </button>
      </div>
    </div>
  )
}