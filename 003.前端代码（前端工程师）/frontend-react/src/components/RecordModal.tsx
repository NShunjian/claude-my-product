import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import type { Category } from '../data/categories'

// 主题色映射（与原型一致）
const COLOR_MAP: Record<string, { solid: string; tint: string; label: string }> = {
  'cat-pink': { solid: '#ED64A6', tint: 'rgba(236 72 153 / 0.12)', label: '#be185d' },
  'cat-blue': { solid: '#4299E1', tint: 'rgba(66 153 225 / 0.12)', label: '#2b6cb0' },
  'cat-purple': { solid: '#805AD5', tint: 'rgba(128 90 213 / 0.12)', label: '#6b46c1' },
  'cat-teal': { solid: '#319795', tint: 'rgba(49 121 149 / 0.12)', label: '#0f766e' },
  'cat-brown': { solid: '#8B6E4E', tint: 'rgba(139 110 78 / 0.12)', label: '#78350f' },
  secondary: { solid: '#10b981', tint: 'rgba(16 185 129 / 0.14)', label: '#047857' },
  outline: { solid: '#727782', tint: 'rgba(114 119 130 / 0.10)', label: '#414750' },
}

interface RecordModalProps {
  kind: 'expense' | 'income'
  categories: Category[]
  defaultCategoryId?: string
  /** 主题色（主按钮背景），默认 expense=primary blue / income=green */
  accent?: 'primary' | 'secondary'
}

export function RecordModal({
  kind,
  categories,
  defaultCategoryId,
  accent = kind === 'expense' ? 'primary' : 'secondary',
}: RecordModalProps) {
  const navigate = useNavigate()

  const [, setAmount] = useState('')
  const [note, setNote] = useState('')
  const [categoryId, setCategoryId] = useState(defaultCategoryId ?? categories[0]?.id ?? '')
  const [expression, setExpression] = useState('')
  const [showSuccess, setShowSuccess] = useState(false)
  const [activeTab, setActiveTab] = useState<'expense' | 'income'>(kind)

  useEffect(() => {
    setActiveTab(kind)
  }, [kind])

  function handleClose() {
    navigate(-1)
  }

  function handleTabSwitch(next: 'expense' | 'income') {
    setActiveTab(next)
    // 切 tab 时跳到对应路由
    navigate(next === 'expense' ? '/record/expense' : '/record/income', { replace: true })
  }

  function pressKey(key: string) {
    if (key === 'back') {
      setExpression((prev) => prev.slice(0, -1))
      return
    }
    if (key === 'op') {
      // + 或 - 操作符
      setExpression((prev) => {
        if (!prev) return '0+'
        const last = prev.slice(-1)
        if (last === '+' || last === '-') return prev.slice(0, -1) + '+' // always add last
        // simple: replace trailing number
        return prev + '+'
      })
      return
    }
    if (key === '.') {
      setExpression((prev) => {
        // 找最后一段数字检查是否已有小数点
        const seg = prev.split(/[+\-]/).pop() ?? ''
        if (seg.includes('.')) return prev
        return prev + '.'
      })
      return
    }
    // 数字键
    setExpression((prev) => {
      const next = prev + key
      // 限制最大长度避免溢出
      return next.length > 12 ? prev : next
    })
  }

  function computeAmount(): string {
    if (!expression) return '0.00'
    // 简单求值（只支持 + 法，足够原型演示）
    try {
      if (!expression.includes('+')) {
        const n = parseFloat(expression)
        return Number.isFinite(n) ? n.toFixed(2) : '0.00'
      }
      const parts = expression.split('+').map((s) => parseFloat(s) || 0)
      const sum = parts.reduce((a, b) => a + b, 0)
      return sum.toFixed(2)
    } catch {
      return '0.00'
    }
  }

  function handleSubmit() {
    const v = computeAmount()
    if (v === '0.00') return
    setAmount(v)
    setShowSuccess(true)
    setTimeout(() => navigate(-1), 1200)
  }

  // 数字键
  const KEYS: Array<{ label: string; value: string; isOp?: boolean; isConfirm?: boolean; isBack?: boolean }> = [
    { label: '1', value: '1' },
    { label: '2', value: '2' },
    { label: '3', value: '3' },
    { label: '⌫', value: 'back', isBack: true },
    { label: '4', value: '4' },
    { label: '5', value: '5' },
    { label: '6', value: '6' },
    { label: '+', value: 'op', isOp: true },
    { label: '7', value: '7' },
    { label: '8', value: '8' },
    { label: '9', value: '9' },
    { label: '−', value: 'op', isOp: true },
    { label: '0', value: '0' },
    { label: '.', value: '.' },
    { label: '✓', value: 'confirm', isConfirm: true },
  ]

  return (
    <div className="fixed inset-0 z-50 flex flex-col justify-end md:justify-center items-center pointer-events-none">
      {/* Backdrop */}
      <div
        className="absolute inset-0 pointer-events-auto"
        style={{
          background:
            'radial-gradient(ellipse at top, rgba(66 100 160 / 0.55) 0%, rgba(20 30 60 / 0.78) 100%)',
          backdropFilter: 'blur(6px)',
          WebkitBackdropFilter: 'blur(6px)',
        }}
        onClick={handleClose}
      />

      {/* Sheet */}
      <div
        className="w-full max-w-md bg-bg-card pointer-events-auto flex flex-col overflow-hidden border border-divider relative z-10"
        style={{
          borderTopLeftRadius: 20,
          borderTopRightRadius: 20,
          boxShadow: '0 -8px 32px rgba(0,0,0,0.18)',
          maxHeight: '92vh',
        }}
      >
        {showSuccess ? (
          <div className="flex flex-col items-center justify-center py-20">
            <div
              className={`w-16 h-16 rounded-full flex items-center justify-center mb-4 ${
                accent === 'primary' ? 'bg-primary-light text-primary' : 'bg-secondary-container text-secondary'
              }`}
            >
              <span
                className="material-symbols-outlined text-3xl"
                style={{ fontVariationSettings: "'FILL' 1" }}
              >
                check
              </span>
            </div>
            <p className="font-headline-md text-headline-md text-text-primary">记录成功</p>
          </div>
        ) : (
          <>
            {/* Header: × + Tab 切换 */}
            <div className="flex items-center justify-between px-6 py-4 border-b border-divider">
              <button
                type="button"
                onClick={handleClose}
                aria-label="关闭"
                className="text-on-surface-variant hover:text-primary transition-colors"
              >
                <span className="material-symbols-outlined" style={{ fontSize: '24px' }}>
                  close
                </span>
              </button>

              <div className="flex items-center bg-surface-container rounded-lg p-1 gap-1">
                <button
                  type="button"
                  onClick={() => handleTabSwitch('expense')}
                  className={`px-5 py-1.5 font-body-md text-body-md font-medium rounded-md transition-colors ${
                    activeTab === 'expense'
                      ? 'bg-bg-card text-primary shadow-sm'
                      : 'text-on-surface-variant'
                  }`}
                >
                  支出
                </button>
                <button
                  type="button"
                  onClick={() => handleTabSwitch('income')}
                  className={`px-5 py-1.5 font-body-md text-body-md font-medium rounded-md transition-colors ${
                    activeTab === 'income'
                      ? 'bg-bg-card text-primary shadow-sm'
                      : 'text-on-surface-variant'
                  }`}
                >
                  收入
                </button>
              </div>

              <div className="w-6" />
            </div>

            {/* 金额显示 */}
            <div className="text-center px-6 pt-6 pb-4 bg-surface-container-lowest">
              <p className="font-caption-sm text-caption-sm text-on-surface-variant mb-2">
                输入金额
              </p>
              <div className="flex items-center justify-center gap-1">
                <span className="font-label-mono text-2xl text-on-surface-variant">¥</span>
                <span
                  className="font-label-mono text-5xl text-text-primary tabular-nums border-b-2 border-primary pb-1 px-2"
                  style={{ minWidth: '160px', display: 'inline-block' }}
                >
                  {computeAmount()}
                </span>
                <span
                  className="font-label-mono text-2xl text-text-primary ml-1"
                  style={{ animation: 'blink 1s steps(2, end) infinite' }}
                >
                  |
                </span>
              </div>
            </div>

            {/* 分类网格 */}
            <div className="px-6 py-6 bg-bg-card">
              <div className="grid grid-cols-4 gap-y-5 gap-x-2">
                {categories.map((cat) => {
                  const c = COLOR_MAP[cat.colorToken]
                  const isSelected = cat.id === categoryId
                  return (
                    <button
                      key={cat.id}
                      type="button"
                      onClick={() => setCategoryId(cat.id)}
                      className="flex flex-col items-center gap-2 transition-transform active:scale-95"
                    >
                      <span
                        className="w-12 h-12 rounded-full flex items-center justify-center transition-colors"
                        style={{
                          backgroundColor: isSelected ? c.solid : c.tint,
                          border: isSelected ? `2px solid ${c.label}` : '2px solid transparent',
                        }}
                      >
                        <span
                          className="material-symbols-outlined"
                          style={{
                            fontSize: '22px',
                            color: isSelected ? '#fff' : c.solid,
                            fontVariationSettings: "'FILL' 1",
                          }}
                        >
                          {cat.icon}
                        </span>
                      </span>
                      <span
                        className="font-caption-sm text-caption-sm"
                        style={{
                          color: isSelected ? c.label : '#414750',
                          fontWeight: isSelected ? 600 : 400,
                        }}
                      >
                        {cat.name}
                      </span>
                    </button>
                  )
                })}
              </div>
            </div>

            {/* 日期 + 备注 行 */}
            <div className="px-6 pb-4 flex items-center gap-3">
              <button
                type="button"
                className="flex items-center gap-2 px-4 py-2 bg-surface-container rounded-lg font-body-md text-body-md text-text-primary hover:bg-surface-container-high transition-colors"
              >
                <span className="material-symbols-outlined" style={{ fontSize: '18px' }}>
                  calendar_today
                </span>
                今天
              </button>
              <input
                type="text"
                value={note}
                onChange={(e) => setNote(e.target.value)}
                placeholder="添加备注..."
                className="flex-1 px-4 py-2 bg-surface-container rounded-lg font-body-md text-body-md text-text-primary placeholder:text-outline focus:outline-none focus:ring-1 focus:ring-primary transition-colors"
              />
            </div>

            {/* 数字键盘 */}
            <div className="px-4 pb-4 grid grid-cols-4 gap-2 bg-bg-card">
              {KEYS.map((k, idx) => {
                const isZero = k.value === '0'
                if (k.isConfirm) {
                  return (
                    <button
                      key={`confirm-${idx}`}
                      type="button"
                      onClick={handleSubmit}
                      disabled={expression === ''}
                      className="row-span-1 rounded-xl transition-all active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed"
                      style={{
                        backgroundColor: accent === 'primary' ? '#005394' : '#10b981',
                        color: '#fff',
                        height: 56,
                      }}
                    >
                      <span
                        className="material-symbols-outlined"
                        style={{ fontSize: '28px', fontVariationSettings: "'FILL' 1" }}
                      >
                        check
                      </span>
                    </button>
                  )
                }
                if (k.isBack) {
                  return (
                    <button
                      key={`back-${idx}`}
                      type="button"
                      onClick={() => pressKey('back')}
                      className="rounded-xl bg-surface-container text-on-surface transition-all active:scale-95 hover:bg-surface-container-high"
                      style={{ height: 56 }}
                    >
                      <span
                        className="material-symbols-outlined"
                        style={{ fontSize: '22px' }}
                      >
                        backspace
                      </span>
                    </button>
                  )
                }
                if (k.isOp) {
                  return (
                    <button
                      key={`op-${idx}`}
                      type="button"
                      onClick={() => pressKey('op')}
                      className="rounded-xl bg-surface-container text-on-surface font-headline-md text-headline-md transition-all active:scale-95 hover:bg-surface-container-high"
                      style={{ height: 56 }}
                    >
                      {k.label}
                    </button>
                  )
                }
                return (
                  <button
                    key={`${k.value}-${idx}`}
                    type="button"
                    onClick={() => pressKey(k.value)}
                    className={`rounded-xl bg-surface-container text-text-primary font-headline-md text-headline-md transition-all active:scale-95 hover:bg-surface-container-high ${
                      isZero ? 'col-span-2' : ''
                    }`}
                    style={{ height: 56 }}
                  >
                    {k.label}
                  </button>
                )
              })}
            </div>
          </>
        )}
      </div>

      {/* 闪烁光标动画 */}
      <style>{`
        @keyframes blink {
          to { visibility: hidden; }
        }
      `}</style>
    </div>
  )
}