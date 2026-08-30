import { useEffect, useState } from 'react'
import { ApiError, request } from '../api/client'
import type { AdminBookListItem, Page } from '../api/types'
import { DataTable } from '../components/DataTable'
import { useToast } from '../components/Toast'

type TypeFilter = '' | 'personal' | 'shared'

export function AdminBooks() {
  const { show } = useToast()
  const [owner, setOwner] = useState('')
  const [typeF, setTypeF] = useState<TypeFilter>('')
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(1)
  const [size, setSize] = useState(20)
  const [data, setData] = useState<AdminBookListItem[]>([])
  const [total, setTotal] = useState(0)
  const [loading, setLoading] = useState(true)

  async function load() {
    setLoading(true)
    try {
      const qs = new URLSearchParams({ page: String(page), size: String(size) })
      if (owner) qs.set('owner', owner)
      if (typeF) qs.set('type', typeF)
      if (search) qs.set('search', search)
      const p = await request<Page<AdminBookListItem>>(`/api/admin/books?${qs}`)
      setData(p.records); setTotal(p.total)
    } catch (err) { show('error', err instanceof ApiError ? err.message : '加载失败') }
    finally { setLoading(false) }
  }
  useEffect(() => { load() }, [page, size, owner, typeF, search])

  return (
    <div className="p-8 space-y-4">
      <h1 className="text-2xl font-bold">账本审计</h1>

      <div className="flex items-end gap-3 flex-wrap">
        <label className="block">
          <span className="text-xs text-on-surface-variant">所有者用户名</span>
          <input value={owner} onChange={(e) => { setOwner(e.target.value); setPage(1) }}
            className="block mt-1 rounded border border-divider px-2 py-1" />
        </label>
        <label className="block">
          <span className="text-xs text-on-surface-variant">类型</span>
          <select value={typeF} onChange={(e) => { setTypeF(e.target.value as TypeFilter); setPage(1) }}
            className="block mt-1 rounded border border-divider px-2 py-1">
            <option value="">全部</option>
            <option value="personal">个人</option>
            <option value="shared">共享</option>
          </select>
        </label>
        <label className="block">
          <span className="text-xs text-on-surface-variant">名称搜索</span>
          <input value={search} onChange={(e) => { setSearch(e.target.value); setPage(1) }}
            className="block mt-1 rounded border border-divider px-2 py-1" />
        </label>
      </div>

      <DataTable<AdminBookListItem>
        rowKey={(b) => b.uuid}
        columns={[
          { key: 'name', label: '账本名' },
          { key: 'type', label: '类型', width: '80px',
            render: (b) => b.type === 'personal' ? '个人' : '共享' },
          { key: 'ownerUsername', label: '所有者', width: '140px' },
          { key: 'currency', label: '币种', width: '80px' },
          { key: 'recordCount', label: '流水数', width: '90px' },
          { key: 'createdAt', label: '创建时间', width: '180px' },
        ]}
        data={data} loading={loading}
        current={page} size={size} total={total}
        onPageChange={setPage} onSizeChange={(s) => { setSize(s); setPage(1) }}
      />
    </div>
  )
}
