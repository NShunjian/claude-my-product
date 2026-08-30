interface KpiCardProps {
  label: string
  value: string | number
  hint?: string
}

export function KpiCard({ label, value, hint }: KpiCardProps) {
  return (
    <div className="bg-bg-card border border-divider rounded-xl p-5">
      <div className="text-sm text-on-surface-variant">{label}</div>
      <div className="text-3xl font-bold mt-1 text-text-primary">{value}</div>
      {hint && <div className="text-xs text-on-surface-variant mt-2">{hint}</div>}
    </div>
  )
}
