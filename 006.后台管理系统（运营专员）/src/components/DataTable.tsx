import type { ReactNode } from 'react'

export interface DataTableColumn<T> {
  key: string
  label: string
  width?: string   // e.g. '120px' or '20%'
  render?: (row: T, index: number) => ReactNode
}

interface DataTableProps<T> {
  columns: DataTableColumn<T>[]
  data: T[]
  loading?: boolean
  rowKey: (row: T) => string | number
  empty?: string
  current: number
  size: number
  total: number
  onPageChange: (page: number) => void
  onSizeChange?: (size: number) => void
}

/**
 * 通用表格 —— 列定义驱动,内置分页 + 加载/空态。
 *
 * ponytail:不引 react-table / tanstack-table —— admin 列表都是同构的简单表格,
 * 自己写够用。需要复杂功能(排序/筛选/选择/虚拟滚动)再加库。
 */
export function DataTable<T>({
  columns, data, loading = false, rowKey, empty = '暂无数据',
  current, size, total, onPageChange, onSizeChange,
}: DataTableProps<T>) {
  const totalPages = Math.max(1, Math.ceil(total / size))

  return (
    <div className="bg-bg-card border border-divider rounded-lg overflow-hidden">
      <table className="w-full text-sm">
        <thead className="bg-surface border-b border-divider text-on-surface-variant">
          <tr>
            {columns.map((c) => (
              <th key={c.key} className="px-4 py-3 text-left font-medium" style={c.width ? { width: c.width } : undefined}>
                {c.label}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {loading ? (
            <tr>
              <td colSpan={columns.length} className="px-4 py-12 text-center text-on-surface-variant">
                加载中…
              </td>
            </tr>
          ) : data.length === 0 ? (
            <tr>
              <td colSpan={columns.length} className="px-4 py-12 text-center text-on-surface-variant">
                {empty}
              </td>
            </tr>
          ) : (
            data.map((row, i) => (
              <tr key={rowKey(row)} className="border-b border-divider last:border-0 hover:bg-surface">
                {columns.map((c) => (
                  <td key={c.key} className="px-4 py-3">
                    {c.render ? c.render(row, i) : String((row as Record<string, unknown>)[c.key] ?? '')}
                  </td>
                ))}
              </tr>
            ))
          )}
        </tbody>
      </table>

      <div className="flex items-center justify-between px-4 py-3 border-t border-divider text-sm">
        <div className="text-on-surface-variant">
          共 {total} 条 · 第 {current} / {totalPages} 页
        </div>
        <div className="flex items-center gap-2">
          {onSizeChange && (
            <select
              value={size}
              onChange={(e) => onSizeChange(Number(e.target.value))}
              className="border border-divider rounded px-2 py-1"
            >
              {[10, 20, 50, 100].map((s) => (
                <option key={s} value={s}>{s}/页</option>
              ))}
            </select>
          )}
          <button
            onClick={() => onPageChange(Math.max(1, current - 1))}
            disabled={current <= 1}
            className="px-3 py-1 rounded border border-divider disabled:opacity-40"
          >
            上一页
          </button>
          <button
            onClick={() => onPageChange(Math.min(totalPages, current + 1))}
            disabled={current >= totalPages}
            className="px-3 py-1 rounded border border-divider disabled:opacity-40"
          >
            下一页
          </button>
        </div>
      </div>
    </div>
  )
}
