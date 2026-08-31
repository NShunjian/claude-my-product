import { useEffect, useState } from 'react'
import { request } from '../api/client'
import { ApiError } from '../api/client'
import type { AdminDashboardStats } from '../api/types'
import { KpiCard } from '../components/KpiCard'
import { useToast } from '../components/Toast'

function TrendBars({ title, items }: { title: string; items: { date: string; count: number }[] }) {
  const max = Math.max(1, ...items.map((i) => i.count))
  return (
    <div className="bg-bg-card border border-divider rounded-xl p-5">
      <div className="text-sm text-on-surface-variant mb-3">{title}</div>
      <div className="space-y-2">
        {items.map((i) => (
          <div key={i.date} className="flex items-center gap-3 text-sm">
            <span className="w-20 text-on-surface-variant tabular-nums">{i.date.slice(5)}</span>
            <div className="flex-1 bg-surface rounded h-5 overflow-hidden">
              <div
                className="h-full bg-primary-container"
                style={{ width: `${(i.count / max) * 100}%` }}
              />
            </div>
            <span className="w-8 text-right tabular-nums">{i.count}</span>
          </div>
        ))}
      </div>
    </div>
  )
}

export function AdminDashboard() {
  const [stats, setStats] = useState<AdminDashboardStats | null>(null)
  const [loading, setLoading] = useState(true)
  const { show } = useToast()

  useEffect(() => {
    request<AdminDashboardStats>('/api/admin/dashboard')
      .then(setStats)
      .catch((err: unknown) => {
        const msg = err instanceof ApiError ? err.message : '加载 Dashboard 失败'
        show('error', msg)
      })
      .finally(() => setLoading(false))
  }, [show])

  if (loading) return <div className="p-8 text-on-surface-variant">加载中…</div>
  if (!stats) return <div className="p-8 text-on-surface-variant">暂无数据</div>

  return (
    <div className="p-8 space-y-6">
      <h1 className="text-2xl font-bold">Dashboard</h1>

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <KpiCard label="总用户" value={stats.userCount} hint={`今日新增 ${stats.userNewToday}`} />
        <KpiCard label="总账本" value={stats.bookCount} />
        <KpiCard label="总流水" value={stats.recordCount} hint={`今日新增 ${stats.recordToday}`} />
        <KpiCard label="7 日活跃" value={stats.userActive7d} hint="按 records 估算" />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <TrendBars title="最近 7 日新增用户" items={stats.newUsersLast7Days} />
        <TrendBars title="最近 7 日新增流水" items={stats.newRecordsLast7Days} />
      </div>
    </div>
  )
}
