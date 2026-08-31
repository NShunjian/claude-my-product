import { useEffect, useState } from 'react'
import { Navigate } from 'react-router-dom'
import { ApiError, request } from '../api/client'
import type { AdminAuditLogListItem, Page } from '../api/types'
import { DataTable } from '../components/DataTable'
import { useAdminAuth } from '../auth/AdminAuthContext'
import { useToast } from '../components/Toast'

export function AdminAuditLogs() {
  const { isSuperAdmin } = useAdminAuth()
  const { show } = useToast()
  const [actor, setActor] = useState('')
  const [action, setAction] = useState('')
  const [targetType, setTargetType] = useState('')
  const [from, setFrom] = useState('')
  const [to, setTo] = useState('')
  const [page, setPage] = useState(1)
  const [size, setSize] = useState(20)
  const [data, setData] = useState<AdminAuditLogListItem[]>([])
  const [total, setTotal] = useState(0)
  const [loading, setLoading] = useState(true)

  if (!isSuperAdmin) return <Navigate to="/dashboard" replace />

  async function load() {
    setLoading(true)
    try {
      const qs = new URLSearchParams({ page: String(page), size: String(size) })
      if (actor) qs.set('actor', actor)
      if (action) qs.set('action', action)
      if (targetType) qs.set('targetType', targetType)
      if (from) qs.set('from', from)
      if (to) qs.set('to', to)
      const p = await request<Page<AdminAuditLogListItem>>(`/api/admin/audit-logs?${qs}`)
      setData(p.records); setTotal(p.total)
    } catch (err) { show('error', err instanceof ApiError ? err.message : '加载失败') }
    finally { setLoading(false) }
  }
  useEffect(() => { load() }, [page, size, actor, action, targetType, from, to])

  return (
    <div className="p-8 space-y-4">
      <h1 className="text-2xl font-bold">审计日志</h1>

      <div className="flex items-end gap-3 flex-wrap">
        <label className="block">
          <span className="text-xs text-on-surface-variant">操作者</span>
          <input value={actor} onChange={(e) => { setActor(e.target.value); setPage(1) }}
            className="block mt-1 rounded border border-divider px-2 py-1" />
        </label>
        <label className="block">
          <span className="text-xs text-on-surface-variant">动作</span>
          <input value={action} onChange={(e) => { setAction(e.target.value); setPage(1) }}
            className="block mt-1 rounded border border-divider px-2 py-1" />
        </label>
        <label className="block">
          <span className="text-xs text-on-surface-variant">资源类型</span>
          <input value={targetType} onChange={(e) => { setTargetType(e.target.value); setPage(1) }}
            className="block mt-1 rounded border border-divider px-2 py-1" />
        </label>
        <label className="block">
          <span className="text-xs text-on-surface-variant">起始日</span>
          <input type="date" value={from} onChange={(e) => { setFrom(e.target.value); setPage(1) }}
            className="block mt-1 rounded border border-divider px-2 py-1" />
        </label>
        <label className="block">
          <span className="text-xs text-on-surface-variant">结束日</span>
          <input type="date" value={to} onChange={(e) => { setTo(e.target.value); setPage(1) }}
            className="block mt-1 rounded border border-divider px-2 py-1" />
        </label>
      </div>

      <DataTable<AdminAuditLogListItem>
        rowKey={(l) => l.uuid}
        columns={[
          { key: 'createdAt', label: '时间', width: '180px' },
          { key: 'actorUsername', label: '操作者', width: '140px' },
          { key: 'action', label: '动作', width: '180px' },
          { key: 'targetType', label: '资源类型', width: '140px',
            render: (l) => l.targetType ?? '—' },
          { key: 'targetId', label: '资源 ID', width: '90px',
            render: (l) => l.targetId ?? '—' },
          { key: 'result', label: '结果', width: '90px',
            render: (l) => (
              <span className={'px-2 py-0.5 rounded text-xs ' + (l.result === 'success' ? 'bg-primary-container' : 'bg-error-light text-error')}>
                {l.result === 'success' ? '成功' : '失败'}
              </span>
            ) },
        ]}
        data={data} loading={loading}
        current={page} size={size} total={total}
        onPageChange={setPage} onSizeChange={(s) => { setSize(s); setPage(1) }}
      />
    </div>
  )
}
