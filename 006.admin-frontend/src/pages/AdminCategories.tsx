import { useEffect, useState } from 'react'
import { ApiError, request } from '../api/client'
import type {
  AdminCategoryListItem, AdminPresetCategoryRequest, AdminUpdateUserStatusRequest, Page,
} from '../api/types'
import { DataTable } from '../components/DataTable'
import { usePermissions } from '../auth/usePermissions'
import { useToast } from '../components/Toast'
import { confirm } from '../components/ConfirmDialog'

type TypeFilter = '' | 'expense' | 'income'

export function AdminCategories() {
  const { has } = usePermissions()
  const { show } = useToast()
  const [name, setName] = useState('')
  const [typeF, setTypeF] = useState<TypeFilter>('')
  const [page, setPage] = useState(1)
  const [size, setSize] = useState(20)
  const [data, setData] = useState<AdminCategoryListItem[]>([])
  const [total, setTotal] = useState(0)
  const [loading, setLoading] = useState(true)
  const [editing, setEditing] = useState<AdminCategoryListItem | null>(null)
  const [creating, setCreating] = useState(false)

  async function load() {
    setLoading(true)
    try {
      const qs = new URLSearchParams({ page: String(page), size: String(size) })
      if (name) qs.set('name', name)
      if (typeF) qs.set('type', typeF)
      const p = await request<Page<AdminCategoryListItem>>(`/api/admin/categories/preset?${qs}`)
      setData(p.records); setTotal(p.total)
    } catch (err) { show('error', err instanceof ApiError ? err.message : '加载失败') }
    finally { setLoading(false) }
  }
  useEffect(() => { load() }, [page, size, name, typeF])

  async function del(c: AdminCategoryListItem) {
    const ok = await confirm({ title: '删除分类?', body: `${c.name} (${c.type})`, danger: true })
    if (!ok) return
    try {
      await request(`/api/admin/categories/preset/${c.id}`, { method: 'DELETE' })
      show('success', '已删除'); load()
    } catch (err) { show('error', err instanceof ApiError ? err.message : '删除失败') }
  }

  async function toggleActive(c: AdminCategoryListItem) {
    try {
      await request(`/api/admin/categories/preset/${c.id}/status`, {
        method: 'PATCH',
        body: { enabled: !c.isActive } as AdminUpdateUserStatusRequest,
      })
      show('success', !c.isActive ? '已启用' : '已禁用'); load()
    } catch (err) { show('error', err instanceof ApiError ? err.message : '操作失败') }
  }

  return (
    <div className="p-8 space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">预设分类</h1>
        {has('category:preset:create') && (
          <button onClick={() => setCreating(true)} className="px-4 py-2 rounded-lg bg-primary text-on-primary text-sm">+ 新建</button>
        )}
      </div>

      <div className="flex items-end gap-3">
        <label className="block">
          <span className="text-xs text-on-surface-variant">名称</span>
          <input value={name} onChange={(e) => { setName(e.target.value); setPage(1) }}
            className="block mt-1 rounded border border-divider px-2 py-1" />
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
      </div>

      <DataTable<AdminCategoryListItem>
        rowKey={(c) => c.id}
        columns={[
          { key: 'id', label: 'ID', width: '70px' },
          { key: 'type', label: '类型', width: '80px',
            render: (c) => c.type === 'income' ? '收入' : '支出' },
          { key: 'name', label: '名称' },
          { key: 'icon', label: '图标', width: '60px',
            render: (c) => c.icon ?? '—' },
          { key: 'usageCount', label: '使用次数', width: '90px' },
          { key: 'isActive', label: '状态', width: '80px',
            render: (c) => (
              <span className={'px-2 py-0.5 rounded text-xs ' + (c.isActive ? 'bg-primary-container' : 'bg-error-light text-error')}>
                {c.isActive ? '启用' : '禁用'}
              </span>
            ) },
          { key: 'op', label: '操作', width: '220px',
            render: (c) => (
              <div className="flex gap-2">
                {has('category:preset:update') && (
                  <button onClick={() => setEditing(c)} className="text-primary hover:underline">编辑</button>
                )}
                {has('category:preset:update') && (
                  <button onClick={() => toggleActive(c)} className="text-on-surface-variant hover:underline">
                    {c.isActive ? '禁用' : '启用'}
                  </button>
                )}
                {has('category:preset:delete') && (
                  <button onClick={() => del(c)} className="text-error hover:underline">删除</button>
                )}
              </div>
            ) },
        ]}
        data={data} loading={loading}
        current={page} size={size} total={total}
        onPageChange={setPage} onSizeChange={(s) => { setSize(s); setPage(1) }}
      />

      {creating && <CategoryForm onClose={() => setCreating(false)} onSaved={() => { setCreating(false); load() }} />}
      {editing && <CategoryForm existing={editing} onClose={() => setEditing(null)} onSaved={() => { setEditing(null); load() }} />}
    </div>
  )
}

function CategoryForm({ existing, onClose, onSaved }: {
  existing?: AdminCategoryListItem
  onClose: () => void
  onSaved: () => void
}) {
  const { show } = useToast()
  const [type, setType] = useState<'expense' | 'income'>(existing?.type ?? 'expense')
  const [name, setName] = useState(existing?.name ?? '')
  const [icon, setIcon] = useState(existing?.icon ?? '')
  const [sortOrder, setSortOrder] = useState<string>(existing?.sortOrder?.toString() ?? '')
  const [busy, setBusy] = useState(false)

  async function save() {
    setBusy(true)
    try {
      const body: AdminPresetCategoryRequest = {
        type, name, icon: icon || undefined,
        sortOrder: sortOrder ? Number(sortOrder) : undefined,
      }
      if (existing) {
        await request(`/api/admin/categories/preset/${existing.id}`, { method: 'PATCH', body })
      } else {
        await request(`/api/admin/categories/preset`, { method: 'POST', body })
      }
      show('success', '已保存'); onSaved()
    } catch (err) { show('error', err instanceof ApiError ? err.message : '保存失败') }
    finally { setBusy(false) }
  }

  return (
    <div className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center" onClick={onClose}>
      <div className="bg-bg-card rounded-xl shadow-xl max-w-sm w-full mx-4 p-6" onClick={(e) => e.stopPropagation()}>
        <h2 className="text-lg font-bold mb-3">{existing ? '编辑' : '新建'}分类</h2>
        <label className="block mb-2">
          <span className="text-sm text-on-surface-variant">类型</span>
          <select value={type} onChange={(e) => setType(e.target.value as 'expense' | 'income')}
            disabled={!!existing}
            className="block w-full mt-1 rounded border border-divider px-2 py-1 disabled:opacity-50">
            <option value="expense">支出</option>
            <option value="income">收入</option>
          </select>
        </label>
        <label className="block mb-2">
          <span className="text-sm text-on-surface-variant">名称</span>
          <input value={name} onChange={(e) => setName(e.target.value)}
            className="block w-full mt-1 rounded border border-divider px-2 py-1" />
        </label>
        <label className="block mb-2">
          <span className="text-sm text-on-surface-variant">图标</span>
          <input value={icon} onChange={(e) => setIcon(e.target.value)}
            className="block w-full mt-1 rounded border border-divider px-2 py-1" />
        </label>
        <label className="block mb-4">
          <span className="text-sm text-on-surface-variant">排序</span>
          <input type="number" value={sortOrder} onChange={(e) => setSortOrder(e.target.value)}
            className="block w-full mt-1 rounded border border-divider px-2 py-1" />
        </label>
        <div className="flex justify-end gap-2">
          <button onClick={onClose} className="px-4 py-2 rounded-lg border border-divider">取消</button>
          <button onClick={save} disabled={busy || !name}
            className="px-4 py-2 rounded-lg bg-primary text-on-primary disabled:opacity-50">保存</button>
        </div>
      </div>
    </div>
  )
}
