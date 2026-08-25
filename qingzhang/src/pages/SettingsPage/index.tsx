import React, { useMemo } from 'react'
import { useRecordStore } from '../../stores/useRecordStore'
import { useAppStore } from '../../stores/useAppStore'
import { useAuthStore } from '../../stores/useAuthStore'
import * as XLSX from 'xlsx'
import dayjs from 'dayjs'
import { Moon, Sun } from '../../components/Icons'

const SettingsPage: React.FC = () => {
  const { records } = useRecordStore()
  const { isDark, toggleTheme } = useAppStore()
  const { currentUser, logout } = useAuthStore()

  const months = useMemo(() => {
    const set = new Set<string>()
    records.forEach((r) => set.add(r.recordDate.slice(0, 7)))
    return Array.from(set).sort()
  }, [records])

  const exportExcel = (mode: 'month' | 'all') => {
    let data = records
    if (mode === 'month' && months.length > 0) {
      const latestMonth = months[months.length - 1]
      data = records.filter((r) => r.recordDate.startsWith(latestMonth))
    }

    const sorted = [...data].sort((a, b) => a.recordDate.localeCompare(b.recordDate))
    const rows = sorted.map((r) => ({
      日期: r.recordDate,
      类型: r.type === 'expense' ? '支出' : '收入',
      分类: r.category?.name || '',
      金额: r.amount,
      账户: r.account?.name || '',
      备注: r.note,
    }))

    const ws = XLSX.utils.json_to_sheet(rows)
    const wb = XLSX.utils.book_new()
    XLSX.utils.book_append_sheet(wb, ws, '账目')
    const filename = `轻账_${mode === 'month' ? '月度' : '全量'}_${dayjs().format('YYYYMM')}.xlsx`
    XLSX.writeFile(wb, filename)
  }

  return (
    <div className="min-h-full pb-20">
      <header className="sticky top-0 z-10 bg-[var(--color-bg-page)] px-4 py-4">
        <h1 className="text-xl font-bold text-[var(--color-text-primary)]">我的</h1>
      </header>

      <div className="space-y-4 px-4">
        <div className="rounded-2xl bg-[var(--color-bg-card)] p-2 shadow-sm">
          <button
            onClick={toggleTheme}
            className="flex w-full items-center justify-between px-4 py-3"
          >
            <span className="text-[var(--color-text-primary)]">暗色模式</span>
            <div className="flex items-center gap-2 text-[var(--color-text-secondary)]">
              {isDark ? <Moon size={20} /> : <Sun size={20} />}
              <span className="text-sm">{isDark ? '开启' : '关闭'}</span>
            </div>
          </button>
        </div>

        <div className="rounded-2xl bg-[var(--color-bg-card)] p-4 shadow-sm">
          <h3 className="mb-3 text-base font-semibold text-[var(--color-text-primary)]">导出 Excel</h3>
          <div className="flex flex-col gap-3">
            <button
              onClick={() => exportExcel('month')}
              disabled={months.length === 0}
              className="w-full rounded-xl bg-[var(--color-primary)] py-3 text-white transition-all disabled:opacity-50"
            >
              导出最近一个月
            </button>
            <button
              onClick={() => exportExcel('all')}
              disabled={records.length === 0}
              className="w-full rounded-xl border border-[var(--color-primary)] bg-transparent py-3 text-[var(--color-primary)] transition-all disabled:opacity-50"
            >
              导出全部数据
            </button>
          </div>
        </div>

        <div className="rounded-2xl bg-[var(--color-bg-card)] p-4 shadow-sm">
          <h3 className="mb-2 text-base font-semibold text-[var(--color-text-primary)]">关于轻账</h3>
          <p className="text-sm leading-relaxed text-[var(--color-text-secondary)]">
            轻账 V1.0.1 —— 最轻的账本，最快的记账。让记账像发朋友圈一样简单。
          </p>
        </div>

        <div className="rounded-2xl bg-[var(--color-bg-card)] p-4 shadow-sm">
          <div className="mb-3 flex items-center justify-between">
            <span className="text-sm text-[var(--color-text-secondary)]">当前用户</span>
            <span className="font-medium text-[var(--color-text-primary)]">
              {currentUser?.username}
            </span>
          </div>
          <button
            onClick={logout}
            className="w-full rounded-xl border border-[var(--color-danger)] py-3 text-[var(--color-danger)] transition-all"
          >
            退出登录
          </button>
        </div>
      </div>
    </div>
  )
}

export default SettingsPage
