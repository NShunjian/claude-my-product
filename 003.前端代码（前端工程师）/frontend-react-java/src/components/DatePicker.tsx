import { useEffect, useMemo, useRef, useState } from 'react'

export interface DatePickerProps {
  /** 当前选中值,格式 'YYYY-MM-DD' */
  value: string
  /** 选中值变化回调(只点日期触发,翻月份不触发) */
  onChange: (next: string) => void
  /** 触发器显示文字本地化(格式 '{y} 年 {m} 月 {d} 日') */
  displayTemplate: string
  /** 触发器 aria-label */
  triggerLabel: string
  /** 各 i18n key 对应文本 */
  labels: {
    prevMonth: string
    nextMonth: string
    prevYear: string
    nextYear: string
    yearLabel: string
    clear: string
    thisMonth: string
    /** 当天显示文案,如 '今天';非当天才走 displayTemplate */
    todayLabel: string
    /** 周标题文本,以逗号分隔的 7 个标签,如 '日,一,二,三,四,五,六' */
    weekdays: string
  }
}

/** 把 Date 转成 'YYYY-MM-DD'。 */
function toISO(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

/** 从 'YYYY-MM-DD' 解析出 Date(本地时区)。解析失败返回 null。 */
function fromISO(iso: string): Date | null {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso)
  if (!m) return null
  const y = parseInt(m[1], 10)
  const mo = parseInt(m[2], 10) - 1
  const d = parseInt(m[3], 10)
  const dt = new Date(y, mo, d)
  return Number.isFinite(dt.getTime()) ? dt : null
}

/**
 * 自定义日期选择器(快速记账用):
  - 触发器:button,显示当前日期
  - 弹出 popover:
    - 顶部:年/月标题 + 上/下个月按钮(跨年自动更新)
    - 中间:7×6 日历网格(日 一 二 …)
    - 底部:清除 / 今天
  - 点外部 / ESC 关闭
 */
export function DatePicker({ value, onChange, displayTemplate, triggerLabel, labels }: DatePickerProps) {
  const [open, setOpen] = useState(false)
  const [mode, setMode] = useState<'days' | 'months'>('days')
  const containerRef = useRef<HTMLDivElement>(null)

  const selected = useMemo(() => fromISO(value), [value])

  // 弹层里显示的月份独立于选中值,这样翻页不会丢选中
  const initialView = selected ?? new Date()
  const [viewY, setViewY] = useState(initialView.getFullYear())
  const [viewM, setViewM] = useState(initialView.getMonth()) // 0-based

  // 年份可选范围:当前年 ±5
  const yearOptions = useMemo(() => {
    const cur = new Date().getFullYear()
    const yrs: number[] = []
    for (let y = cur - 5; y <= cur + 5; y++) yrs.push(y)
    return yrs
  }, [])

  // 每次打开,同步 view 到当前选中(或今天),并切回 days 模式
  useEffect(() => {
    if (!open) return
    const v = selected ?? new Date()
    setViewY(v.getFullYear())
    setViewM(v.getMonth())
    setMode('days')
  }, [open]) // eslint-disable-line react-hooks/exhaustive-deps

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

  function goPrevMonth(): void {
    const d = new Date(viewY, viewM - 1, 1)
    setViewY(d.getFullYear())
    setViewM(d.getMonth())
  }
  function goNextMonth(): void {
    const d = new Date(viewY, viewM + 1, 1)
    setViewY(d.getFullYear())
    setViewM(d.getMonth())
  }
  function goPrevYear(): void {
    setViewY(viewY - 1)
  }
  function goNextYear(): void {
    setViewY(viewY + 1)
  }
  function pickYear(newY: number): void {
    setViewY(newY)
  }
  function pickMonth(newM: number): void {
    setViewM(newM)
    setMode('days')
  }
  function pickDay(d: number): void {
    const dt = new Date(viewY, viewM, d)
    onChange(toISO(dt))
    setOpen(false)
  }
  function goToday(): void {
    const now = new Date()
    onChange(toISO(now))
    setViewY(now.getFullYear())
    setViewM(now.getMonth())
    setMode('days')
    setOpen(false)
  }
  function clearSelection(): void {
    // 保留 view,只关闭弹层;值清空由外层决定(这里不主动 reset,避免破坏外层语义)
    setOpen(false)
  }

  // 日历网格:6 行 × 7 列,每格携带真实 Date(方便跨月点击直接定位)
  const cells: Array<{ date: Date; outOfMonth: boolean }> = []
  const firstWeekday = new Date(viewY, viewM, 1).getDay() // 0=Sun
  const prevMonthLastDay = new Date(viewY, viewM, 0).getDate()
  // 上个月垫底
  for (let i = firstWeekday - 1; i >= 0; i--) {
    cells.push({ date: new Date(viewY, viewM - 1, prevMonthLastDay - i), outOfMonth: true })
  }
  // 当月
  const daysInMonth = new Date(viewY, viewM + 1, 0).getDate()
  for (let d = 1; d <= daysInMonth; d++) {
    cells.push({ date: new Date(viewY, viewM, d), outOfMonth: false })
  }
  // 下个月补齐到 42 格
  let nextD = 1
  while (cells.length < 42) {
    cells.push({ date: new Date(viewY, viewM + 1, nextD), outOfMonth: true })
    nextD++
  }

  const today = new Date()
  const todayISO = toISO(today)
  const selectedDay = selected ? selected.getDate() : null
  const selectedInView = selected && selected.getFullYear() === viewY && selected.getMonth() === viewM

  const weekdayLabels = labels.weekdays.split(',').map((s) => s.trim())

  const isSelectedToday =
    !!selected && today.getFullYear() === selected.getFullYear() && today.getMonth() === selected.getMonth() && today.getDate() === selected.getDate()

  const display = selected
    ? isSelectedToday
      ? labels.todayLabel
      : displayTemplate
          .replace('{y}', String(selected.getFullYear()))
          .replace('{m}', String(selected.getMonth() + 1))
          .replace('{d}', String(selected.getDate()))
    : ''

  return (
    <div ref={containerRef} className="relative">
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        aria-haspopup="dialog"
        aria-expanded={open}
        aria-label={triggerLabel}
        className="flex items-center gap-2 px-4 py-2 bg-surface-container rounded-lg font-body-md text-body-md text-text-primary hover:bg-surface-container-high transition-colors"
      >
        <span className="material-symbols-outlined" style={{ fontSize: '18px' }}>
          calendar_today
        </span>
        <span>{display}</span>
      </button>

      {open && (
        <div
          role="dialog"
          aria-label={triggerLabel}
          className="absolute bottom-full left-0 mb-2 z-50 bg-bg-card border border-divider rounded-xl shadow-lg p-4 w-[300px] max-h-[80vh] overflow-y-auto"
        >
          {/* 顶部:年/月标题 + 翻页按钮(按模式不同:days=翻月, months=翻年) */}
          <div className="flex items-center justify-between mb-3">
            <button
              type="button"
              onClick={mode === 'days' ? goPrevMonth : goPrevYear}
              aria-label={mode === 'days' ? labels.prevMonth : labels.prevYear}
              className="p-1 rounded-md hover:bg-surface-container-low text-on-surface-variant"
            >
              <span className="material-symbols-outlined" style={{ fontSize: '20px' }}>
                chevron_left
              </span>
            </button>
            <button
              type="button"
              onClick={() => setMode((m) => (m === 'days' ? 'months' : 'days'))}
              aria-label={labels.yearLabel}
              className="flex items-center gap-1 px-2 py-1 rounded-md hover:bg-surface-container-low text-text-primary"
            >
              <span className="font-body-md text-body-md font-semibold">
                {mode === 'days' ? `${viewY} 年 ${viewM + 1} 月` : `${viewY} 年`}
              </span>
              <span
                className="material-symbols-outlined text-on-surface-variant"
                style={{ fontSize: '18px' }}
              >
                {mode === 'days' ? 'arrow_drop_up' : 'arrow_drop_down'}
              </span>
            </button>
            <button
              type="button"
              onClick={mode === 'days' ? goNextMonth : goNextYear}
              aria-label={mode === 'days' ? labels.nextMonth : labels.nextYear}
              className="p-1 rounded-md hover:bg-surface-container-low text-on-surface-variant"
            >
              <span className="material-symbols-outlined" style={{ fontSize: '20px' }}>
                chevron_right
              </span>
            </button>
          </div>

          {mode === 'days' ? (
            <>
              {/* 周标题 */}
              <div className="grid grid-cols-7 mb-1">
                {weekdayLabels.map((w, i) => (
                  <div
                    key={i}
                    className="text-center font-caption-sm text-caption-sm py-1 text-on-surface-variant"
                  >
                    {w}
                  </div>
                ))}
              </div>

              {/* 日期网格 */}
              <div className="grid grid-cols-7 gap-0.5">
                {cells.map((cell, idx) => {
                  const cellISO = toISO(cell.date)
                  const isToday = cellISO === todayISO
                  const isSelected = !cell.outOfMonth && selectedInView && cell.date.getDate() === selectedDay
                  return (
                    <button
                      key={idx}
                      type="button"
                      onClick={() => {
                        if (cell.outOfMonth) {
                          // 跨月:跳到目标月并选中
                          setViewY(cell.date.getFullYear())
                          setViewM(cell.date.getMonth())
                          onChange(cellISO)
                          setOpen(false)
                        } else {
                          pickDay(cell.date.getDate())
                        }
                      }}
                      className={
                        'h-9 w-9 mx-auto rounded-full font-body-md text-body-md transition-colors flex items-center justify-center ' +
                        (isSelected
                          ? 'bg-primary text-on-primary font-semibold'
                          : isToday
                            ? 'border border-primary text-primary font-semibold'
                            : cell.outOfMonth
                              ? 'text-on-surface-variant opacity-50 hover:bg-surface-container-low'
                              : 'text-text-primary hover:bg-surface-container-low')
                      }
                    >
                      {cell.date.getDate()}
                    </button>
                  )
                })}
              </div>
            </>
          ) : (
            <>
              {/* 年份下拉(可选范围) */}
              <div className="flex items-center gap-3 mb-4">
                <span className="font-body-md text-body-md text-on-surface-variant shrink-0">
                  {labels.yearLabel}
                </span>
                <div className="relative flex-1">
                  <select
                    value={viewY}
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
              <div className="grid grid-cols-4 gap-2">
                {Array.from({ length: 12 }, (_, i) => i + 1).map((month) => {
                  const active = month - 1 === viewM
                  return (
                    <button
                      key={month}
                      type="button"
                      onClick={() => pickMonth(month - 1)}
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
            </>
          )}

          {/* 底部 */}
          <div className="flex justify-between border-t border-divider pt-3 mt-3">
            <button
              type="button"
              onClick={clearSelection}
              className="font-body-md text-body-md text-primary hover:underline"
            >
              {labels.clear}
            </button>
            <button
              type="button"
              onClick={goToday}
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