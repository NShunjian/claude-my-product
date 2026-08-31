/** 与 React 版 src/theme/ThemeContext.tsx + index.css 同形 */
export const tokens = {
  color: {
    primary:        '#2E7DE6',
    'primary-light':'#D9E8FA',
    bg:             '#FFFFFF',
    'bg-card':      '#FAFAFA',
    text:           '#1A1A1A',
    'text-variant':  '#5F6368',
    error:          '#BA1A1A',
    divider:        '#E0E0E0',
    surface:        '#F5F5F5',
  },
  radius: { sm: 6, md: 10, lg: 16 },
  space:  { xs: 4, sm: 8, md: 12, lg: 16, xl: 24 },
} as const

export type ThemeMode = 'system' | 'light' | 'dark'

/** dark 主题覆盖色 */
export const darkTokens = {
  primary:        '#5BA3FF',
  'primary-light':'#1F3A60',
  bg:             '#0F1115',
  'bg-card':      '#181B22',
  text:           '#E6E8EC',
  'text-variant': '#A0A6B2',
  error:          '#FF6B6B',
  divider:        '#2A2F38',
  surface:        '#1F242C',
}
