import { useEffect, useState } from 'react'
import { ApiError, request } from '../api/client'
import type {
  AdminGrantRoleRequest, AdminResetPasswordResponse, AdminUpdateUserStatusRequest,
  AdminUserDetailResponse, AdminUserListItem,
} from '../api/types'
import type { Page } from '../api/types'
import { DataTable } from '../components/DataTable'
import { RoleBadgeList, roleLabel } from '../components/RoleBadge'
import { usePermissions } from '../auth/usePermissions'
import { useToast } from '../components/Toast'
import { confirm } from '../components/ConfirmDialog'

type StatusFilter = '' | '1' | '0'

/** 授权弹窗里的角色选项 —— 按"权限大小"排序
 *  super_admin 排除(API 不能授),但当 actor 自己就是 super_admin 时显示 */
const GRANTABLE_ROLES = [
  { code: 'admin',            label: '管理员' },
  { code: 'vice_super_admin', label: '副超级管理员' },
  { code: 'vice_admin',       label: '副管理员' },
  { code: 'viewer',           label: '只读审计员' },
]

export function AdminUsers() {
  const { has, roleCodes } = usePermissions()
  const { show } = useToast()
  const [username, setUsername] = useState('')
  const [statusF, setStatusF] = useState<StatusFilter>('')
  const [page, setPage] = useState(1)
  const [size, setSize] = useState(20)
  const [data, setData] = useState<AdminUserListItem[]>([])
  const [total, setTotal] = useState(0)
  const [loading, setLoading] = useState(true)
  const [detail, setDetail] = useState<AdminUserDetailResponse | null>(null)
  const [grantFor, setGrantFor] = useState<AdminUserListItem | null>(null)

  const isSuperAdmin = roleCodes.includes('super_admin')

  async function load() {
    setLoading(true)
    try {
      const qs = new URLSearchParams({ page: String(page), size: String(size) })
      if (username) qs.set('username', username)
      if (statusF) qs.set('status', statusF)
      const p = await request<Page<AdminUserListItem>>(`/api/admin/users?${qs}`)
      setData(p.records); setTotal(p.total)
    } catch (err) {
      show('error', err instanceof ApiError ? err.message : '加载失败')
    } finally { setLoading(false) }
  }
  useEffect(() => { load() }, [page, size, username, statusF])

  async function toggleStatus(u: AdminUserListItem) {
    const next = u.status === 1 ? 0 : 1
    const ok = await confirm({
      title: next === 0 ? '禁用用户?' : '启用用户?',
      body: `${u.username} (${u.displayName})`,
      danger: next === 0,
    })
    if (!ok) return
    try {
      await request(`/api/admin/users/${u.id}/status`, {
        method: 'PATCH',
        body: { enabled: next === 1 } as AdminUpdateUserStatusRequest,
      })
      show('success', next === 1 ? '已启用' : '已禁用'); load()
    } catch (err) { show('error', err instanceof ApiError ? err.message : '操作失败') }
  }

  async function resetPwd(u: AdminUserListItem) {
    const ok = await confirm({
      title: '重置密码?',
      body: `将生成新密码并返回给 ${u.username}`,
      danger: true,
    })
    if (!ok) return
    try {
      const res = await request<AdminResetPasswordResponse>(
        `/api/admin/users/${u.id}/reset-password`,
        { method: 'POST' },
      )
      show('success', `新密码: ${res.newPassword}`)
    } catch (err) { show('error', err instanceof ApiError ? err.message : '操作失败') }
  }

  async function grantRole(u: AdminUserListItem, roleCode: string) {
    try {
      await request(`/api/admin/users/${u.id}/roles`, {
        method: 'POST',
        body: { roleCode } as AdminGrantRoleRequest,
      })
      const tip = roleCode === 'super_admin' ? '已转移超级管理员身份' : '已授予'
      show('success', tip); setGrantFor(null); load()
    } catch (err) { show('error', err instanceof ApiError ? err.message : '操作失败') }
  }

  async function revokeRole(u: AdminUserListItem, roleCode: string) {
    const ok = await confirm({
      title: '撤销角色?',
      body: `${u.username} ← ${roleLabel(roleCode)}`,
      danger: true,
    })
    if (!ok) return
    try {
      await request(`/api/admin/users/${u.id}/roles/${roleCode}`, { method: 'DELETE' })
      show('success', '已撤销'); load()
      if (detail && detail.id === u.id) setDetail(null)
    } catch (err) { show('error', err instanceof ApiError ? err.message : '操作失败') }
  }

  async function openDetail(u: AdminUserListItem) {
    try {
      setDetail(await request<AdminUserDetailResponse>(`/api/admin/users/${u.id}`))
    } catch (err) { show('error', err instanceof ApiError ? err.message : '加载失败') }
  }

  return (
    <div className="p-8 space-y-4">
      <h1 className="text-2xl font-bold">用户管理</h1>

      <div className="flex items-end gap-3">
        <label className="block">
          <span className="text-xs text-on-surface-variant">用户名</span>
          <input value={username} onChange={(e) => { setUsername(e.target.value); setPage(1) }}
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

      <DataTable<AdminUserListItem>
        rowKey={(u) => u.id}
        columns={[
          { key: 'id', label: 'ID', width: '70px' },
          { key: 'username', label: '用户名' },
          { key: 'displayName', label: '昵称' },
          { key: 'roles', label: '角色', width: '280px',
            render: (u) => <RoleBadgeList codes={u.roles} /> },
          { key: 'status', label: '状态', width: '80px',
            render: (u) => (
              <span className={'px-2 py-0.5 rounded text-xs ' + (u.status === 1 ? 'bg-success-light text-on-primary-container' : 'bg-error-light text-error')}>
                {u.status === 1 ? '启用' : '禁用'}
              </span>
            ) },
          { key: 'actions', label: '操作', width: '320px',
            render: (u) => (
              <div className="flex gap-2">
                <button onClick={() => openDetail(u)} className="text-primary hover:underline">详情</button>
                {has('user:disable') && (
                  <button onClick={() => toggleStatus(u)} className={u.status === 1 ? 'text-error hover:underline' : 'text-success hover:underline'}>
                    {u.status === 1 ? '禁用' : '启用'}
                  </button>
                )}
                {has('user:reset_password') && (
                  <button onClick={() => resetPwd(u)} className="text-warning hover:underline">重置密码</button>
                )}
                {has('role:grant') && (
                  <button onClick={() => setGrantFor(u)} className="text-primary hover:underline">授权</button>
                )}
              </div>
            ) },
        ]}
        data={data} loading={loading}
        current={page} size={size} total={total}
        onPageChange={setPage} onSizeChange={(s) => { setSize(s); setPage(1) }}
      />

      {detail && <UserDetailModal user={detail} isSuperAdmin={isSuperAdmin}
        onClose={() => setDetail(null)}
        onRevoke={(rc) => revokeRole({
          id: detail.id, username: detail.username, displayName: detail.displayName,
          status: 1, lastLoginAt: null, createdAt: '',
          recordCount: 0, bookCount: 0, uuid: detail.uuid, roles: detail.roles,
        }, rc)} />}
      {grantFor && <GrantRoleModal user={grantFor} isSuperAdmin={isSuperAdmin}
        onClose={() => setGrantFor(null)} onGrant={(rc) => grantRole(grantFor, rc)} />}
    </div>
  )
}

function UserDetailModal({ user, isSuperAdmin, onClose, onRevoke }: {
  user: AdminUserDetailResponse
  isSuperAdmin: boolean
  onClose: () => void
  onRevoke: (roleCode: string) => void
}) {
  return (
    <div className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center" onClick={onClose}>
      <div className="bg-bg-card rounded-xl shadow-xl max-w-md w-full mx-4 p-6" onClick={(e) => e.stopPropagation()}>
        <h2 className="text-lg font-bold mb-3">{user.username} · {user.displayName}</h2>
        <dl className="text-sm space-y-1 mb-4">
          <div><dt className="inline text-on-surface-variant">邮箱:</dt> <dd className="inline">{user.email ?? '—'}</dd></div>
          <div><dt className="inline text-on-surface-variant">电话:</dt> <dd className="inline">{user.phone ?? '—'}</dd></div>
          <div><dt className="inline text-on-surface-variant">注册:</dt> <dd className="inline">{user.createdAt}</dd></div>
          <div><dt className="inline text-on-surface-variant">最后登录:</dt> <dd className="inline">{user.lastLoginAt ?? '—'}</dd></div>
        </dl>
        <div className="mb-2 text-sm">
          <span className="text-on-surface-variant mr-2">角色:</span>
          {user.roles.length === 0
            ? <span className="text-on-surface-variant">—</span>
            : user.roles.map((r) => {
              // 不能撤自己的角色
              const canRevoke = isSuperAdmin && r !== 'super_admin'
              return (
                <span key={r} className="inline-flex items-center gap-1 mr-2">
                  <RoleBadgeList codes={[r]} />
                  {canRevoke && (
                    <button onClick={() => onRevoke(r)} className="text-error text-xs" title="撤销该角色">×</button>
                  )}
                </span>
              )
            })}
        </div>
        <div className="text-right"><button onClick={onClose} className="px-4 py-2 rounded-lg border border-divider">关闭</button></div>
      </div>
    </div>
  )
}

function GrantRoleModal({ user, isSuperAdmin, onClose, onGrant }: {
  user: AdminUserListItem
  isSuperAdmin: boolean
  onClose: () => void
  onGrant: (roleCode: string) => void
}) {
  // 只有 super_admin 能选 super_admin(transfer 语义);其它角色 super_admin 和 vice_super_admin 都可授
  // super_admin 不出现在下拉里 —— 它走 transfer,在 detail 里改
  const [rc, setRc] = useState(GRANTABLE_ROLES[0].code)
  const opts = isSuperAdmin
    ? GRANTABLE_ROLES  // 含 super_admin(其实是 transfer)
    : GRANTABLE_ROLES.filter((r) => r.code !== 'super_admin')
  // 副超管授 super_admin 由后端 403,前端只是不显示选项,UX 更干净
  return (
    <div className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center" onClick={onClose}>
      <div className="bg-bg-card rounded-xl shadow-xl max-w-sm w-full mx-4 p-6" onClick={(e) => e.stopPropagation()}>
        <h2 className="text-lg font-bold mb-3">为 {user.username} 授予角色</h2>
        <select value={rc} onChange={(e) => setRc(e.target.value)}
          className="block w-full rounded border border-divider px-2 py-1 mb-2">
          {opts.map((o) => <option key={o.code} value={o.code}>{o.label} ({o.code})</option>)}
        </select>
        <p className="text-xs text-on-surface-variant mb-4">
          {isSuperAdmin
            ? '选择 super_admin 表示把超级管理员身份转移给该用户(你将自动失去该角色)。'
            : '副超级管理员不能授予 super_admin 角色。'}
        </p>
        <div className="flex justify-end gap-2">
          <button onClick={onClose} className="px-4 py-2 rounded-lg border border-divider">取消</button>
          <button onClick={() => onGrant(rc)} className="px-4 py-2 rounded-lg bg-primary text-on-primary">确定</button>
        </div>
      </div>
    </div>
  )
}
