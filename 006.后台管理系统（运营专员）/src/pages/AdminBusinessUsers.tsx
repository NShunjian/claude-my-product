import { useEffect, useState } from 'react'
import { ApiError, request } from '../api/client'
import type {
  BatchDeleteBusinessUsersRequest, BatchDeleteBusinessUsersResponse,
  BusinessUserDetailResponse, BusinessUserListItem, HardDeleteBusinessUserPreview, Page, AdminResetPasswordResponse,
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
  // 批量删除:只追踪当前页可见 id(避免跨页"以为选了 100 项实际 20 项"的坑)
  const [selectedIds, setSelectedIds] = useState<Set<number>>(new Set())

  async function load() {
    setLoading(true)
    try {
      const qs = new URLSearchParams({ page: String(page), size: String(size) })
      if (search) qs.set('search', search)
      if (statusF) qs.set('status', statusF)
      const p = await request<Page<BusinessUserListItem>>(`/api/admin/business-users?${qs}`)
      setData(p.records); setTotal(p.total)
      // 软删后,留在 selectedIds 里的 id 已经从列表里消失,清空避免下次误选
      setSelectedIds(new Set())
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

  // 批量勾选 helper —— 切换某行的 checkbox
  function toggleOne(id: number) {
    setSelectedIds((prev) => {
      const next = new Set(prev)
      if (next.has(id)) next.delete(id); else next.add(id)
      return next
    })
  }
  // 全选 / 反选当前页
  function togglePageAll() {
    setSelectedIds((prev) => {
      const pageIds = data.map((u) => u.id)
      const allSelected = pageIds.every((id) => prev.has(id))
      if (allSelected) return new Set()  // 全取消
      return new Set([...prev, ...pageIds])  // 全选(累加其他已选项)
    })
  }

  async function batchDelete() {
    const ids = Array.from(selectedIds)
    if (ids.length === 0) return
    const ok = await confirm({
      title: `彻底删除 ${ids.length} 个业务用户?`,
      // ponytail:不可逆操作的 confirm 文案要包含「破坏范围」,不能只说"删除"。
      body: `将彻底销毁(不可恢复,真 DELETE FROM):\n· 用户记录\n· 该用户的账本 + 成员 + 预算(FK CASCADE)\n· 该用户的全部流水 + 账户 + 分类 + 导出记录\n\n${ids.length > 20 ? `本次前 100 个 id:` : '本次 id:'}\n${ids.slice(0, 20).join(', ')}${ids.length > 20 ? ', …' : ''}\n\n点击「确定」后无法撤销。`,
      danger: true,
      confirmWord: '我已知晓,彻底删除',
    })
    if (!ok) return
    try {
      const res = await request<BatchDeleteBusinessUsersResponse>(
        '/api/admin/business-users/batch-delete',
        { method: 'POST', body: { ids } as BatchDeleteBusinessUsersRequest },
      )
      const detail = `用户 ${res.usersDeleted} · 账本 ${res.booksDeleted} · 流水 ${res.recordsDeleted} · 账户 ${res.accountsDeleted} · 分类 ${res.categoriesDeleted}`
      show('success', `已彻底删除: ${detail}${res.skipped > 0 ? `,跳过 ${res.skipped} 个` : ''}`)
      setSelectedIds(new Set())
      load()
    } catch (err) { show('error', err instanceof ApiError ? err.message : '操作失败') }
  }

  /** 单硬删 —— 先调 preview 拿真实销毁规模,塞进 confirm 文案,最后调 DELETE。 */
  async function singleDelete(u: BusinessUserListItem) {
    let preview: HardDeleteBusinessUserPreview | null = null
    try {
      preview = await request<HardDeleteBusinessUserPreview>(
        `/api/admin/business-users/${u.id}/hard-delete-preview`)
    } catch (err) {
      show('error', err instanceof ApiError ? err.message : '预览失败')
      return
    }
    const ok = await confirm({
      title: `彻底删除 ${u.username}?`,
      body: `将不可恢复地销毁:\n· 用户记录\n· 账本 ${preview.books} 本 + 成员 + 预算\n· 流水 ${preview.records} 条\n· 账户 ${preview.accounts} 个\n· 分类 ${preview.categories} 个\n\n点击「确定」后无法撤销。`,
      danger: true,
      confirmWord: '我已知晓,彻底删除',
    })
    if (!ok) return
    try {
      const res = await request<BatchDeleteBusinessUsersResponse>(
        `/api/admin/business-users/${u.id}`,
        { method: 'DELETE' },
      )
      show('success', `已彻底删除 ${u.username} (账本 ${res.booksDeleted} · 流水 ${res.recordsDeleted} · 账户 ${res.accountsDeleted} · 分类 ${res.categoriesDeleted})`)
      load()
    } catch (err) { show('error', err instanceof ApiError ? err.message : '操作失败') }
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
        {has('business_user:delete') && data.length > 0 && (
          selectedIds.size > 0 ? (
            <div className="ml-auto flex items-center gap-3 px-3 py-1.5 rounded-lg bg-primary-light text-on-primary-container">
              <span className="text-sm font-medium">已选 {selectedIds.size} 项</span>
              <button
                onClick={() => setSelectedIds(new Set())}
                className="px-3 py-1.5 rounded-lg border-2 border-error text-error hover:bg-error-light font-medium"
              >
                取消选择
              </button>
              <button
                onClick={batchDelete}
                className="px-3 py-1.5 rounded-lg bg-error text-on-primary text-sm font-medium hover:opacity-90"
              >
                批量彻底删除
              </button>
            </div>
          ) : (
            <button
              onClick={togglePageAll}
              className="ml-auto text-xs px-3 py-1.5 rounded border border-divider hover:bg-bg-page"
            >
              全选当前页 ({data.length})
            </button>
          )
        )}
      </div>

      <DataTable<BusinessUserListItem>
        rowKey={(u) => u.id}
        columns={[
          // 仅当有删除权限才渲染 checkbox 列 —— viewer / 普通账号看不到这一列
          ...(has('business_user:delete')
            ? [{ key: '_select', label: '', width: '40px',
                 render: (u: BusinessUserListItem) => (
                   <input
                     type="checkbox"
                     checked={selectedIds.has(u.id)}
                     onChange={() => toggleOne(u.id)}
                     aria-label={`选择 ${u.username}`}
                     onClick={(e) => e.stopPropagation()}
                   />
                 ) }]
            : []),
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
          { key: 'ops', label: '操作', width: '320px',
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
                {has('business_user:delete') && (
                  <button onClick={() => singleDelete(u)} className="text-error hover:underline">彻底删除</button>
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
  const [copied, setCopied] = useState(false)
  async function copy() {
    try {
      await navigator.clipboard.writeText(result.newPassword)
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    } catch {
      // 剪贴板被浏览器拒绝(HTTP / 无权限)—— 用户可手动长按选择
    }
  }
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
            onClick={copy}
            disabled={copied}
            className={
              'px-3 py-2 rounded border text-sm transition-colors ' +
              (copied
                ? 'border-success text-success bg-success-light'
                : 'border-divider hover:bg-bg-page')
            }
          >
            {copied ? '✓ 已复制' : '复制'}
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