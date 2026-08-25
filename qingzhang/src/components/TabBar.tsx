import React from 'react'

interface Tab {
  key: string
  label: string
  path: string
  icon: React.FC<{ className?: string; size?: number }>
}

interface TabBarProps {
  tabs: Tab[]
  activePath: string
  onChange: (path: string) => void
}

const TabBar: React.FC<TabBarProps> = ({ tabs, activePath, onChange }) => {
  return (
    <nav className="fixed bottom-0 left-0 right-0 z-40 border-t border-[var(--color-divider)] bg-[var(--color-bg-card)] px-2 safe-bottom">
      <div className="mx-auto flex max-w-[480px] items-center justify-around py-2">
        {tabs.map((tab) => {
          const isActive = tab.path === activePath
          const Icon = tab.icon
          return (
            <button
              key={tab.key}
              onClick={() => onChange(tab.path)}
              className={`flex flex-col items-center justify-center gap-1 px-4 py-1 transition-colors ${
                isActive ? 'text-[var(--color-primary)]' : 'text-[var(--color-text-secondary)]'
              }`}
            >
              <Icon className={isActive ? 'text-[var(--color-primary)]' : 'text-[var(--color-text-secondary)]'} size={24} />
              <span className="text-xs">{tab.label}</span>
            </button>
          )
        })}
      </div>
    </nav>
  )
}

export default TabBar
