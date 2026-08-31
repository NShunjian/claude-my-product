import { useEffect, useState } from 'react'
import { ApiError, request } from '../api/client'
import type { AdminRecordListItem, Page } from '../api/types'
import { DataTable } from '../components/DataTable'
import { useToast } from '../components/Toast'

type TypeFilter = '' | 'income' | 'expense'

export function AdminRecords() {
  const { show } = useToast()
  const [userId, setUserId] = useState('')
  const [bookUuid, setBookUuid] = useState('')
  const [typeF, setTypeF] = useState<TypeFilter>('')
  const [from, setFrom] = useState('')
  const [to, setTo] = useState('')
  const [page, setPage] = useState(1)
  const [size, setSize] = useState(20)
  const [data, setData] = useState<AdminRecordListItem[]>([])
  const [total, setTotal] = useState(0)
  const [loading, setLoading] = useState(true)

  async function load() {
    setLoading(true)
    try {
      const qs = new URLSearchParams({ page: String(page), size: String(size) })
      if (userId) qs.set('userId', userId)
      if (bookUuid) qs.set('bookUuid', bookUuid)
      if (typeF) qs.set('type', typeF)
      if (from) qs.set('from', from)
      if (to) qs.set('to', to)
      const p = await request<Page<AdminRecordListItem>>(`/api/admin/records?${qs}`)
      setData(p.records); setTotal(p.total)
    } catch (err) { show('error', err instanceof ApiError ? err.message : '加载失败') }
    finally { setLoading(false) }
  }
  useEffect(() => { load() }, [page, size, userId, bookUuid, typeF, from, to])

  return (
    <div className="p-8 space-y-4">
      <h1 className="text-2xl font-bold">流水审计</h1>

      <div className="flex items-end gap-3 flex-wrap">
        <label className="block">
          <span className="text-xs text-on-surface-variant">用户 ID</span>
          <input type="number" value={userId} onChange={(e) => { setUserId(e.target.value); setPage(1) }}
            className="block mt-1 rounded border border-divider px-2 py-1 w-24" />
        </label>
        <label className="block">
          <span className="text-xs text-on-surface-variant">账本 UUID</span>
          <input value={bookUuid} onChange={(e) => { setBookUuid(e.target.value); setPage(1) }}
            className="block mt-1 rounded border border-divider px-2 py-1 w-48" />
        </label>
        <label className="block">
          <span className="text-xs text-on-surface-variant">类型</span>
          <select value={typeF} onChange={(e) => { setTypeF(e.target.value as TypeFilter); setPage(1) }}
            className="block mt-1 rounded border border-divider px-2 py-1">
            <option value="">全部</option>
            <option value="expense">支出</option>
            <option value="income">收入</option>
          </select>
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

      <DataTable<AdminRecordListItem>
        rowKey={(r) => r.uuid}
        columns={[
          { key: 'recordDate', label: '日期', width: '110px' },
          { key: 'type', label: '类型', width: '70px',
            render: (r) => r.type === 'income' ? '收入' : '支出' },
          { key: 'amount', label: '金额', width: '110px',
            render: (r) => `${r.currency} ${r.amount}` },
          { key: 'username', label: '用户', width: '120px' },
          { key: 'bookName', label: '账本', width: '140px',
            render: (r) => r.bookName ?? '—' },
          { key: 'categoryName', label: '分类', width: '120px',
            render: (r) => r.categoryName ?? '—' },
          { key: 'note', label: '备注',
            render: (r) => r.note ?? '—' },
        ]}
        data={data} loading={loading}
        current={page} size={size} total={total}
        onPageChange={setPage} onSizeChange={(s) => { setSize(s); setPage(1) }}
      />
    </div>
  )
}
