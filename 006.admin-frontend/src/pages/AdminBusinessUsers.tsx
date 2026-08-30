import { useEffect, useState } from 'react'
import { ApiError, request } from '../api/client'
import type {
  BusinessUserDetailResponse, BusinessUserListItem, Page, AdminResetPasswordResponse,
} from '../api/types'
import { DataTable } from '../components/DataTable'
import { usePermissions } from '../auth/usePermissions'
import { useToast } from '../components/Toast'
import { confirm } from '../components/ConfirmDialog'

type StatusFilter = '' | '1' | '0'

/**
 * 业务用户治理(java-qingzhang.users)
 *
 * 与 AdminUsers.tsx 的差别:
 *   - 不能建账号(没有 /api/admin/business-users POST)
 *   - 不能改角色
 *   - 启停 + 重置密码 = business_user:disable / business_user:reset_password
 *
 * 准入(V9 + V11 之后):
 *   super_admin / vice_super_admin / admin — 全权(列表 / 详情 / 启停 / 重置密码)
 *   viewer                                 — 只读(列表 / 详情)
 */
export function AdminBusinessUsers() {
  const { has } = usePermissions()
  const { show } = useToast()
  const [search, setSearch] = useState('')
  const [statusF, setStatusF] = useState<StatusFilter>('')
  const [page, setPage] = useState(1)
  const [size, setSize] = useState(20)
  const [data, setData] = useState<BusinessUserListItem[]>([])
  const [total, setTotal] = useState(0)
  const [loading, setLoading] = useState(true)
  const [detail, setDetail] = useState<BusinessUserDetailResponse | null>(null)
  const [pwdResult, setPwdResult] = useState<{ username: string; newPassword: string } | null>(null)

  async function load() {
    setLoading(true)
    try {
      const qs = new URLSearchParams({ page: String(page), size: String(size) })
      if (search) qs.set('search', search)
      if (statusF) qs.set('status', statusF)
      const p = await request<Page<BusinessUserListItem>>(`/api/admin/business-users?${qs}`)
      setData(p.records); setTotal(p.total)
    } catch (err) {
      show('error', err instanceof ApiError ? err.message : '加载失败')
    } finally { setLoading(false) }
  }
  useEffect(() => { load() }, [page, size, search, statusF])

  async function toggleStatus(u: BusinessUserListItem) {
    const next = u.status === 1 ? 0 : 1
    const ok = await confirm({
      title: next === 0 ? '禁用业务用户?' : '启用业务用户?',
      body: `${u.username}${u.displayName ? ' (' + u.displayName + ')' : ''}`,
      danger: next === 0,
    })
    if (!ok) return
    try {
      await request(`/api/admin/business-users/${u.id}/status?enabled=${next === 1}`, { method: 'PATCH' })
      show('success', next === 1 ? '已启用' : '已禁用'); load()
    } catch (err) { show('error', err instanceof ApiError ? err.message : '操作失败') }
  }

  async function resetPwd(u: BusinessUserListItem) {
    const ok = await confirm({
      title: '重置密码?',
      body: `将生成新密码并显示给操作员(只此一次)。\n${u.username}`,
      danger: true,
    })
    if (!ok) return
    try {
      const res = await request<AdminResetPasswordResponse>(
        `/api/admin/business-users/${u.id}/reset-password`,
        { method: 'POST' },
      )
      // 持久弹窗 —— Toast 3 秒自动消失,用户来不及复制密码
      // 与 AdminUsers.resetPwd 行为一致(见 AdminUsers.tsx PasswordRevealModal)
      setPwdResult({ username: u.username, newPassword: res.newPassword })
    } catch (err) { show('error', err instanceof ApiError ? err.message : '操作失败') }
  }

  async function openDetail(u: BusinessUserListItem) {
    try {
      setDetail(await request<BusinessUserDetailResponse>(`/api/admin/business-users/${u.id}`))
    } catch (err) { show('error', err instanceof ApiError ? err.message : '加载失败') }
  }

  return (
    <div className="p-8 space-y-4">
      <h1 className="text-2xl font-bold">业务用户</h1>
      <p className="text-sm text-on-surface-variant">
        java-qingzhang.users 的真实用户(super_admin / vice_super_admin / admin 可管理;viewer 只读)
      </p>

      <div className="flex items-end gap-3">
        <label className="block">
          <span className="text-xs text-on-surface-variant">搜索用户名</span>
          <input value={search} onChange={(e) => { setSearch(e.target.value); setPage(1) }}
            placeholder="LIKE 匹配"
            className="block mt-1 rounded border border-divider px-2 py-1" />
        </label>
        <label className="block">
          <span className="text-xs text-on-surface-variant">状态</span>
          <select value={statusF} onChange={(e) => { setStatusF(e.target.value as StatusFilter); setPage(1) }}
            className="block mt-1 rounded border border-divider px-2 py-1">
            <option value="">全部</option>
            <option value="1">启用</option>
            <option value="0">禁用</option>
          </select>
        </label>
      </div>

      <DataTable<BusinessUserListItem>
        rowKey={(u) => u.id}
        columns={[
          { key: 'id', label: 'ID', width: '70px' },
          { key: 'username', label: '用户名' },
          { key: 'displayName', label: '昵称', render: (u) => u.displayName ?? '—' },
          { key: 'status', label: '状态', width: '80px',
            render: (u) => (
              <span className={'px-2 py-0.5 rounded text-xs ' + (u.status === 1 ? 'bg-success-light text-on-primary-container' : 'bg-error-light text-error')}>
                {u.status === 1 ? '启用' : '禁用'}
              </span>
            ) },
          { key: 'lastLoginAt', label: '最后登录', render: (u) => u.lastLoginAt ?? '—' },
          { key: 'createdAt', label: '注册时间' },
          { key: 'ops', label: '操作', width: '260px',
            render: (u) => (
              <div className="flex gap-2">
                <button onClick={() => openDetail(u)} className="text-primary hover:underline">详情</button>
                {has('business_user:disable') && (
                  <button onClick={() => toggleStatus(u)} className={u.status === 1 ? 'text-error hover:underline' : 'text-success hover:underline'}>
                    {u.status === 1 ? '禁用' : '启用'}
                  </button>
                )}
                {has('business_user:reset_password') && (
                  <button onClick={() => resetPwd(u)} className="text-warning hover:underline">重置密码</button>
                )}
              </div>
            ) },
        ]}
        data={data} loading={loading}
        current={page} size={size} total={total}
        onPageChange={setPage} onSizeChange={(s) => { setSize(s); setPage(1) }}
      />

      {detail && <DetailModal user={detail} onClose={() => setDetail(null)} />}
      {pwdResult && <PasswordRevealModal result={pwdResult} onClose={() => setPwdResult(null)} />}
    </div>
  )
}

/** 重置密码结果 —— 持久弹窗,等用户复制完密码再关闭。
 *  与 AdminUsers.tsx 的同名组件保持一致:文案内嵌"仅显示一次"提醒,
 *  内含 read-only input + 一键复制按钮。 */
function PasswordRevealModal({ result, onClose }: {
  result: { username: string; newPassword: string }
  onClose: () => void
}) {
  return (
    <div className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center" onClick={onClose}>
      <div className="bg-bg-card rounded-xl shadow-xl max-w-sm w-full mx-4 p-6" onClick={(e) => e.stopPropagation()}>
        <h2 className="text-lg font-bold mb-2">密码已重置</h2>
        <p className="text-xs text-on-surface-variant mb-4">
          请将以下新密码当面转给 <span className="font-medium text-on-surface">{result.username}</span>。
          该密码仅显示一次,关闭弹窗后无法再次查看,可在「重置密码」重新生成。
        </p>
        <div className="flex items-stretch gap-2 mb-4">
          <input
            readOnly
            value={result.newPassword}
            onFocus={(e) => e.currentTarget.select()}
            className="flex-1 rounded border border-divider px-3 py-2 font-mono text-sm bg-bg-page"
          />
          <button
            type="button"
            onClick={() => {
              navigator.clipboard.writeText(result.newPassword).catch(() => { /* noop */ })
            }}
            className="px-3 py-2 rounded border border-divider text-sm hover:bg-bg-page"
          >
            复制
          </button>
        </div>
        <div className="text-right">
          <button onClick={onClose} className="px-4 py-2 rounded-lg bg-primary text-on-primary">关闭</button>
        </div>
      </div>
    </div>
  )
}

function DetailModal({ user, onClose }: {
  user: BusinessUserDetailResponse
  onClose: () => void
}) {
  return (
    <div className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center" onClick={onClose}>
      <div className="bg-bg-card rounded-xl shadow-xl max-w-md w-full mx-4 p-6" onClick={(e) => e.stopPropagation()}>
        <h2 className="text-lg font-bold mb-3">{user.username} · {user.displayName ?? '—'}</h2>
        <dl className="text-sm space-y-1 mb-4">
          <div><dt className="inline text-on-surface-variant">邮箱:</dt> <dd className="inline">{user.email ?? '—'}</dd></div>
          <div><dt className="inline text-on-surface-variant">电话:</dt> <dd className="inline">{user.phone ?? '—'}</dd></div>
          <div><dt className="inline text-on-surface-variant">性别:</dt> <dd className="inline">{user.gender ?? '—'}</dd></div>
          <div><dt className="inline text-on-surface-variant">年龄:</dt> <dd className="inline">{user.age ?? '—'}</dd></div>
          <div><dt className="inline text-on-surface-variant">最后登录 IP:</dt> <dd className="inline">{user.lastLoginIp ?? '—'}</dd></div>
          <div><dt className="inline text-on-surface-variant">最后登录:</dt> <dd className="inline">{user.lastLoginAt ?? '—'}</dd></div>
          <div><dt className="inline text-on-surface-variant">注册:</dt> <dd className="inline">{user.createdAt}</dd></div>
        </dl>
        <div className="text-right"><button onClick={onClose} className="px-4 py-2 rounded-lg border border-divider">关闭</button></div>
      </div>
    </div>
  )
}