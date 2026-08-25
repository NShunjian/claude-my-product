import React from 'react'

interface EmptyStateProps {
  title?: string
  description?: string
}

const EmptyState: React.FC<EmptyStateProps> = ({
  title = '还没有记录',
  description = '点击右下角 + 开始记一笔吧',
}) => {
  return (
    <div className="flex flex-col items-center justify-center py-12 text-center">
      <div className="mb-4 text-6xl text-[var(--color-text-secondary)] opacity-30">📝</div>
      <h3 className="mb-2 text-base font-medium text-[var(--color-text-primary)]">{title}</h3>
      <p className="text-sm text-[var(--color-text-secondary)]">{description}</p>
    </div>
  )
}

export default EmptyState
