import React from 'react'

interface IconProps {
  className?: string
  size?: number
}

export const Home: React.FC<IconProps> = ({ className, size = 24 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" className={className}>
    <path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2V9z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
    <path d="M9 22V12h6v10" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
)

export const PieChart: React.FC<IconProps> = ({ className, size = 24 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" className={className}>
    <path d="M21.21 15.89A10 10 0 118.2 2.36l.87 5.36L21.21 15.89z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
    <path d="M22 12a10 10 0 00-10-10v10h10z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
)

export const Wallet: React.FC<IconProps> = ({ className, size = 24 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" className={className}>
    <path d="M19 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
    <path d="M16 11a2 2 0 100 4 2 2 0 000-4z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
    <path d="M3 7V5a2 2 0 012-2h14a2 2 0 012 2v2" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
)

export const Settings: React.FC<IconProps> = ({ className, size = 24 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" className={className}>
    <circle cx="12" cy="12" r="3" stroke="currentColor" strokeWidth="2" />
    <path d="M19.4 15a1.65 1.65 0 00.33 1.82l.06.07a2 2 0 01-2.83 2.83l-.07-.06a1.65 1.65 0 00-1.82-.33 1.65 1.65 0 00-1 1.51v.1a2 2 0 01-4 0v-.1a1.65 1.65 0 00-1-1.51 1.65 1.65 0 00-1.82.33l-.07.06a2 2 0 01-2.83-2.83l.06-.07a1.65 1.65 0 00.33-1.82 1.65 1.65 0 00-1.51-1h-.1a2 2 0 010-4h.1a1.65 1.65 0 001.51-1 1.65 1.65 0 00-.33-1.82l-.06-.07a2 2 0 012.83-2.83l.07.06a1.65 1.65 0 001.82.33h.1a1.65 1.65 0 001-1.51v-.1a2 2 0 014 0v.1a1.65 1.65 0 001 1.51 1.65 1.65 0 001.82-.33l.07-.06a2 2 0 012.83 2.83l-.06.07a1.65 1.65 0 00-.33 1.82v.1a1.65 1.65 0 001.51 1h.1a2 2 0 010 4h-.1a1.65 1.65 0 00-1.51 1z" stroke="currentColor" strokeWidth="2" />
  </svg>
)

export const Plus: React.FC<IconProps> = ({ className, size = 24 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" className={className}>
    <path d="M12 5v14M5 12h14" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
)

export const Close: React.FC<IconProps> = ({ className, size = 24 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" className={className}>
    <path d="M18 6L6 18M6 6l12 12" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
)

export const Moon: React.FC<IconProps> = ({ className, size = 24 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" className={className}>
    <path d="M21 12.79A9 9 0 1111.21 3 7 7 0 0021 12.79z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
)

export const Sun: React.FC<IconProps> = ({ className, size = 24 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" className={className}>
    <circle cx="12" cy="12" r="5" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
    <path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
)
