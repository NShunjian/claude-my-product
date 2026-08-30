import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { ApiError, request } from '../api/client'
import type {
  AdminGrantRoleRequest, AdminResetPasswordResponse, AdminUpdateUserStatusRequest,
  AdminUserDetailResponse, AdminUserListItem, CreateAdminUserRequest, CreateAdminUserResponse,
} from '../api/types'
import type { Page } from '../api/types'
import { DataTable } from '../components/DataTable'
import { RoleBadgeList, roleLabel } from '../components/RoleBadge'
import { usePermissions } from '../auth/usePermissions'
import { useAdminAuth } from '../auth/AdminAuthContext'
import { useToast } from '../components/Toast'
import { confirm } from '../components/ConfirmDialog'

type StatusFilter = '' | '1' | '0'

/** 授权弹窗里的角色选项 —— 按"权限大小"排序
 *  super_admin 不出现在 API 选项里(账号由 DBA 维护,稳定不变)。
 *  副超管不能选 vice_super_admin(只有 super_admin 能授)。 */
const GRANTABLE_ROLES = [
  { code: 'admin',             label: '管理员' },
  { code: 'vice_super_admin',  label: '副超级管理员' },
  { code: 'viewer',            label: '只读审计员' },
]

export function AdminUsers() {
  const { has, roleCodes } = usePermissions()
  const { user: me, logout } = useAdminAuth()
  const { show } = useToast()
  const navigate = useNavigate()
  // 双保险:id 优先,id 缺失/对不上时回退到 username。
  // 防止 /api/admin/auth/me 的 id 字段与 /api/admin/users 的 id 不一致时漏判。
  const isMeRow = (u: AdminUserListItem) =>
    me != null && (me.id === u.id || me.username === u.username)
  const [username, setUsername] = useState('')
  const [statusF, setStatusF] = useState<StatusFilter>('')
  const [page, setPage] = useState(1)
  const [size, setSize] = useState(20)
  const [data, setData] = useState<AdminUserListItem[]>([])
  const [total, setTotal] = useState(0)
  const [loading, setLoading] = useState(true)
  const [detail, setDetail] = useState<AdminUserDetailResponse | null>(null)
  const [grantFor, setGrantFor] = useState<AdminUserListItem | null>(null)
  const [createOpen, setCreateOpen] = useState(false)
  // 重置密码 / 新建账号 → 持久弹窗(自动消失的 toast 用户看不到密码)
  const [pwdResult, setPwdResult] = useState<{ username: string; newPassword: string } | null>(null)

  const isSuperAdmin = roleCodes.includes('super_admin')
  const isViceSuperAdmin = roleCodes.includes('vice_super_admin')
  // 副超管也有 role:revoke 权限,撤销其他账户的非 super_admin 角色也应显示 ×
  const canRevokeRole = isSuperAdmin || isViceSuperAdmin
  // V15 起:super_admin / vice_super_admin 都可 user:create
  const canCreateUser = isSuperAdmin || isViceSuperAdmin

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
    const isSelf = isMeRow(u)
    const ok = await confirm({
      title: next === 0 ? '禁用用户?' : '启用用户?',
      body: isSelf && next === 0
        ? `禁用自己后将被强制登出,再次登录会提示账号已禁用。\n${u.username} (${u.displayName})`
        : `${u.username} (${u.displayName})`,
      danger: next === 0,
    })
    if (!ok) return
    try {
      await request(`/api/admin/users/${u.id}/status`, {
        method: 'PATCH',
        body: { enabled: next === 1 } as AdminUpdateUserStatusRequest,
      })
      // 自禁用 → 后端 admin_users.status=0;前端主动清登录态,踢回登录页
      // 再次登录会落到 loginAdmin 的 ADMIN_USER_DISABLED 分支,Toast 提示"账号已禁用"
      if (isSelf && next === 0) {
        logout()
        show('error', '账号已禁用,请联系超级管理员')
        navigate('/login', { replace: true })
        return
      }
      show('success', next === 1 ? '已启用' : '已禁用')
      load()
    } catch (err) { show('error', err instanceof ApiError ? err.message : '操作失败') }
  }

  async function resetPwd(u: AdminUserListItem) {
    const ok = await confirm({
      title: '重置密码?',
      body: `将生成新密码并显示给操作员(只此一次)。\n${u.username}`,
      danger: true,
    })
    if (!ok) return
    try {
      const res = await request<AdminResetPasswordResponse>(
        `/api/admin/users/${u.id}/reset-password`,
        { method: 'POST' },
      )
      // 持久弹窗 —— Toast 3 秒自动消失,用户来不及复制密码
      setPwdResult({ username: u.username, newPassword: res.newPassword })
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
    const isSelf = isMeRow(u)
    const willHaveNoRole = u.roles.length <= 1   // 撤销后剩 0 个角色
    const ok = await confirm({
      title: '撤销角色?',
      body: isSelf && willHaveNoRole
        ? `撤销自己唯一的角色后将被强制登出,再次登录会提示账号没有权限。\n${u.username} ← ${roleLabel(roleCode)}`
        : `${u.username} ← ${roleLabel(roleCode)}`,
      danger: true,
    })
    if (!ok) return
    try {
      await request(`/api/admin/users/${u.id}/roles/${roleCode}`, { method: 'DELETE' })
      // 自撤、且撤完后无角色 → 强制登出,下次登录 ADMIN_AUTH_REQUIRED 提示"账号没有任何权限"
      if (isSelf && willHaveNoRole) {
        logout()
        show('error', '账号没有任何权限,请联系超级管理员')
        navigate('/login', { replace: true })
        return
      }
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
        {canCreateUser && (
          <button onClick={() => setCreateOpen(true)}
            className="ml-auto px-4 py-2 rounded-lg bg-primary text-on-primary hover:opacity-90">
            + 新建账号
          </button>
        )}
      </div>

      <DataTable<AdminUserListItem>
        rowKey={(u) => u.id}
        columns={[
          { key: 'id', label: 'ID', width: '70px' },
          { key: 'username', label: '用户名',
            render: (u) => (
              <span>
                {u.username}
                {isMeRow(u) && (
                  <span className="ml-2 px-1.5 py-0.5 rounded bg-primary text-on-primary text-xs font-medium">我</span>
                )}
              </span>
            ) },
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
            render: (u) => {
              const isMe = isMeRow(u)
              // 有 user:disable 权限的角色(super / 副超管)任何方向都不能改自己的状态(启/禁)
              const selfStatusBlocked = isMe && canRevokeRole
              return (
                <div className="flex gap-2">
                  <button onClick={() => openDetail(u)} className="text-primary hover:underline">详情</button>
                  {has('user:disable') && (
                    selfStatusBlocked
                      ? <span className="text-on-surface-variant cursor-not-allowed" title="不能修改自己的账号状态">禁用</span>
                      : <button onClick={() => toggleStatus(u)} className={u.status === 1 ? 'text-error hover:underline' : 'text-success hover:underline'}>
                          {u.status === 1 ? '禁用' : '启用'}
                        </button>
                  )}
                  {has('user:reset_password') && (
                    <button onClick={() => resetPwd(u)} className="text-warning hover:underline">重置密码</button>
                  )}
                  {has('role:grant') && (
                    isMe
                      ? <span className="text-on-surface-variant cursor-not-allowed" title="当前账户,禁止授权">授权</span>
                      : <button onClick={() => setGrantFor(u)} className="text-primary hover:underline">授权</button>
                  )}
                </div>
              )
            } },
        ]}
        data={data} loading={loading}
        current={page} size={size} total={total}
        onPageChange={setPage} onSizeChange={(s) => { setSize(s); setPage(1) }}
      />

      {detail && <UserDetailModal user={detail} canRevokeRole={canRevokeRole}
        meId={me?.id ?? null}
        onClose={() => setDetail(null)}
        onRevoke={(rc) => revokeRole({
          id: detail.id, username: detail.username, displayName: detail.displayName,
          status: 1, lastLoginAt: null, createdAt: '',
          recordCount: 0, bookCount: 0, uuid: detail.uuid, roles: detail.roles,
        }, rc)} />}
      {grantFor && <GrantRoleModal user={grantFor} isSuperAdmin={isSuperAdmin}
        onClose={() => setGrantFor(null)} onGrant={(rc) => grantRole(grantFor, rc)} />}
      {pwdResult && <PasswordRevealModal result={pwdResult} onClose={() => setPwdResult(null)} />}
      {createOpen && (
        <CreateUserModal
          isSuperAdmin={isSuperAdmin}
          onClose={() => setCreateOpen(false)}
          onCreated={(res) => {
            setCreateOpen(false)
            setPwdResult({ username: res.username, newPassword: res.initialPassword })
            load()
          }}
        />
      )}
    </div>
  )
}

function UserDetailModal({ user, canRevokeRole, meId, onClose, onRevoke }: {
  user: AdminUserDetailResponse
  canRevokeRole: boolean
  meId: number | null
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
              // 自己行永远不出现 × —— UI 不提供自撤入口,避免误操作把自己变成普通账号
              // 后端 revokeRole 仍允许自撤(供 DBA / 工具调用),前端 force-logout 流程保留作兜底
              const isSelf = meId === user.id
              const canRevoke = canRevokeRole && !isSelf && r !== 'super_admin'
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
  // super_admin 永远不出现在 API 选项里(账号由 DBA 维护)
  // 副超管也不能选 vice_super_admin(后端会拒)
  const [rc, setRc] = useState(GRANTABLE_ROLES[0].code)
  const opts = isSuperAdmin
    ? GRANTABLE_ROLES  // super_admin 选 admin / vice_super_admin / viewer
    : GRANTABLE_ROLES.filter((r) => r.code !== 'vice_super_admin')  // 副超管只能授 admin / viewer
  return (
    <div className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center" onClick={onClose}>
      <div className="bg-bg-card rounded-xl shadow-xl max-w-sm w-full mx-4 p-6" onClick={(e) => e.stopPropagation()}>
        <h2 className="text-lg font-bold mb-3">为 {user.username} 授予角色</h2>
        <p className="text-xs text-on-surface-variant mb-2">
          每个账号只能有 1 个角色,授权时会自动撤销该用户现有角色。
        </p>
        <select value={rc} onChange={(e) => setRc(e.target.value)}
          className="block w-full rounded border border-divider px-2 py-1 mb-4">
          {opts.map((o) => <option key={o.code} value={o.code}>{o.label} ({o.code})</option>)}
        </select>
        <div className="flex justify-end gap-2">
          <button onClick={onClose} className="px-4 py-2 rounded-lg border border-divider">取消</button>
          <button onClick={() => onGrant(rc)} className="px-4 py-2 rounded-lg bg-primary text-on-primary">确定</button>
        </div>
      </div>
    </div>
  )
}

/** 重置密码结果 —— 持久弹窗,等用户复制完密码再关闭。
 *  用 Toast 3 秒会自动消失,密码看不见。 */
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

/** 新建账号弹窗 —— V15 起 super_admin / vice_super_admin 都可调。
 *  角色下拉按当前 actor 角色过滤白名单(后端 AdminUserService.create 也会再校一遍)。 */
function CreateUserModal({ isSuperAdmin, onClose, onCreated }: {
  isSuperAdmin: boolean
  onClose: () => void
  onCreated: (res: CreateAdminUserResponse) => void
}) {
  const [username, setUsername] = useState('')
  const [displayName, setDisplayName] = useState('')
  // V15 白名单:
  //   super_admin      → admin / vice_super_admin / viewer
  //   vice_super_admin → admin / viewer
  //   super_admin 永不出现(V7 + V13)
  const roleOptions = isSuperAdmin
    ? GRANTABLE_ROLES
    : GRANTABLE_ROLES.filter((r) => r.code !== 'vice_super_admin')
  const [roleCode, setRoleCode] = useState<string>(roleOptions[0]?.code ?? '')
  const [submitting, setSubmitting] = useState(false)
  const { show } = useToast()

  async function submit() {
    if (!username.trim()) {
      show('error', '请输入用户名')
      return
    }
    setSubmitting(true)
    try {
      const body: CreateAdminUserRequest = {
        username: username.trim(),
        displayName: displayName.trim() || undefined,
        roleCode: roleCode || undefined,
      }
      const res = await request<CreateAdminUserResponse>('/api/admin/users', {
        method: 'POST', body,
      })
      onCreated(res)
    } catch (err) {
      show('error', err instanceof ApiError ? err.message : '创建失败')
    } finally { setSubmitting(false) }
  }

  return (
    <div className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center" onClick={onClose}>
      <div className="bg-bg-card rounded-xl shadow-xl max-w-md w-full mx-4 p-6" onClick={(e) => e.stopPropagation()}>
        <h2 className="text-lg font-bold mb-3">新建管理员账号</h2>
        <p className="text-xs text-on-surface-variant mb-4">
          密码将自动生成并在确认后显示一次,请当面转给新账号。
          创建后账号状态默认为「启用」。
        </p>
        <label className="block mb-3">
          <span className="text-xs text-on-surface-variant">用户名 (字母/数字/_-.)</span>
          <input
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            placeholder="3-50 位"
            className="block mt-1 w-full rounded border border-divider px-2 py-1"
          />
        </label>
        <label className="block mb-3">
          <span className="text-xs text-on-surface-variant">昵称 (可选)</span>
          <input
            value={displayName}
            onChange={(e) => setDisplayName(e.target.value)}
            placeholder="留空则用用户名"
            className="block mt-1 w-full rounded border border-divider px-2 py-1"
          />
        </label>
        <label className="block mb-4">
          <span className="text-xs text-on-surface-variant">角色</span>
          <select
            value={roleCode}
            onChange={(e) => setRoleCode(e.target.value)}
            className="block mt-1 w-full rounded border border-divider px-2 py-1"
          >
            {roleOptions.map((o) => (
              <option key={o.code} value={o.code}>{o.label} ({o.code})</option>
            ))}
          </select>
          <span className="text-[10px] text-on-surface-variant mt-1 block">
            每个账号只能有 1 个角色。后续可在「授权」中调整。
          </span>
        </label>
        <div className="flex justify-end gap-2">
          <button onClick={onClose} disabled={submitting}
            className="px-4 py-2 rounded-lg border border-divider disabled:opacity-50">取消</button>
          <button onClick={submit} disabled={submitting || !username.trim()}
            className="px-4 py-2 rounded-lg bg-primary text-on-primary disabled:opacity-50">
            {submitting ? '创建中…' : '创建'}
          </button>
        </div>
      </div>
    </div>
  )
}
