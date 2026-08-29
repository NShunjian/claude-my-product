import { useEffect, useRef, useState } from 'react'

export interface MonthPickerProps {
  /** 当前选中值,格式 'YYYY-MM' */
  value: string
  /** 选中值变化回调(只点月份触发,选年份不触发) */
  onChange: (next: string) => void
  /** 可选年份列表(从大到小或小到大均可,组件不排序) */
  yearOptions: number[]
  /** 触发器显示文字本地化(格式 '{y} 年 {m} 月') */
  displayTemplate: string
  /** 触发器 aria-label */
  triggerLabel: string
  /** 各 i18n key 对应文本 */
  labels: {
    yearLabel: string
    clear: string
    thisMonth: string
  }
}

/**
 * 自定义月份选择器:
 * - 触发器:button,显示当前月份
 * - 弹出 popover:
 *   - 顶部:<select> 年份下拉(改年份立即生效,popover 不关)
 *   - 中间:12 个月份格子(点选后关闭 popover)
 *   - 底部:清除 / 本月
 * - 点外部 / ESC 关闭
 */
export function MonthPicker({
  value,
  onChange,
  yearOptions,
  displayTemplate,
  triggerLabel,
  labels,
}: MonthPickerProps) {
  const [open, setOpen] = useState(false)
  const containerRef = useRef<HTMLDivElement>(null)

  const [y, m] = value.split('-').map(Number)
  const isValid = Number.isFinite(y) && Number.isFinite(m)

  // 点外部 / ESC 关闭
  useEffect(() => {
    if (!open) return
    function onDocPointer(e: MouseEvent): void {
      if (containerRef.current && !containerRef.current.contains(e.target as Node)) {
        setOpen(false)
      }
    }
    function onEsc(e: KeyboardEvent): void {
      if (e.key === 'Escape') setOpen(false)
    }
    document.addEventListener('mousedown', onDocPointer)
    document.addEventListener('keydown', onEsc)
    return () => {
      document.removeEventListener('mousedown', onDocPointer)
      document.removeEventListener('keydown', onEsc)
    }
  }, [open])

  function pickYear(newY: number): void {
    if (!isValid) return
    onChange(`${newY}-${String(m).padStart(2, '0')}`)
  }
  function pickMonth(newM: number): void {
    if (!isValid) return
    onChange(`${y}-${String(newM).padStart(2, '0')}`)
    setOpen(false)
  }
  function goThisMonth(): void {
    const d = new Date()
    onChange(`${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`)
    setOpen(false)
  }

  const display = isValid
    ? displayTemplate.replace('{y}', String(y)).replace('{m}', String(m))
    : ''

  return (
    <div ref={containerRef} className="relative">
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        aria-haspopup="dialog"
        aria-expanded={open}
        aria-label={triggerLabel}
        className="flex items-center gap-2 px-1 py-0.5 rounded-md hover:bg-surface-container-low transition-colors"
      >
        <span
          className="material-symbols-outlined text-primary"
          style={{ fontSize: '20px', fontVariationSettings: "'FILL' 1" }}
        >
          calendar_month
        </span>
        <span className="font-body-md text-body-md font-medium text-text-primary min-w-[88px] text-center">
          {display}
        </span>
      </button>

      {open && (
        <div
          role="dialog"
          aria-label={triggerLabel}
          className="absolute top-full right-0 mt-2 z-50 bg-bg-card border border-divider rounded-xl shadow-lg p-4 w-[280px]"
        >
          {/* 年份下拉 */}
          <div className="flex items-center gap-3 mb-4">
            <span className="font-body-md text-body-md text-on-surface-variant shrink-0">
              {labels.yearLabel}
            </span>
            <div className="relative flex-1">
              <select
                value={y}
                onChange={(e) => pickYear(parseInt(e.target.value, 10))}
                className="appearance-none w-full bg-surface-container-lowest border border-divider rounded-lg pl-3 pr-8 py-2 font-body-md text-body-md text-text-primary cursor-pointer hover:border-primary focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary transition-colors"
              >
                {yearOptions.map((yr) => (
                  <option key={yr} value={yr}>
                    {yr}
                  </option>
                ))}
              </select>
              <span
                className="material-symbols-outlined absolute right-2 top-1/2 -translate-y-1/2 pointer-events-none text-on-surface-variant"
                style={{ fontSize: '18px' }}
              >
                expand_more
              </span>
            </div>
          </div>

          {/* 12 个月份格子 */}
          <div className="grid grid-cols-4 gap-2 mb-3">
            {Array.from({ length: 12 }, (_, i) => i + 1).map((month) => {
              const active = month === m
              return (
                <button
                  key={month}
                  type="button"
                  onClick={() => pickMonth(month)}
                  className={
                    'py-2 rounded-lg font-body-md text-body-md transition-colors ' +
                    (active
                      ? 'bg-primary text-on-primary font-semibold'
                      : 'bg-surface-container-lowest text-text-primary hover:bg-primary-light hover:text-primary')
                  }
                >
                  {month}月
                </button>
              )
            })}
          </div>

          {/* 底部 */}
          <div className="flex justify-between border-t border-divider pt-3">
            <button
              type="button"
              onClick={() => setOpen(false)}
              className="font-body-md text-body-md text-primary hover:underline"
            >
              {labels.clear}
            </button>
            <button
              type="button"
              onClick={goThisMonth}
              className="font-body-md text-body-md text-primary hover:underline"
            >
              {labels.thisMonth}
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
