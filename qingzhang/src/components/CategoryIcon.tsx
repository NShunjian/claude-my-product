import React from 'react'
import { Category } from '../types'

interface CategoryIconProps {
  category: Category
  size?: 'sm' | 'md' | 'lg'
  isActive?: boolean
}

const sizeMap = {
  sm: 'w-6 h-6 text-xs',
  md: 'w-10 h-10 text-base',
  lg: 'w-12 h-12 text-lg',
}

const CategoryIcon: React.FC<CategoryIconProps> = ({ category, size = 'md', isActive = false }) => {
  if (!category) return null

  return (
    <div
      className={`flex items-center justify-center rounded-full ${sizeMap[size]} transition-all ${
        isActive ? 'ring-2 ring-[var(--color-primary)] ring-offset-2' : ''
      }`}
      style={{
        backgroundColor: `${category.color}20`,
        color: category.color,
      }}
    >
      <span>{category.icon}</span>
    </div>
  )
}

export default CategoryIcon
