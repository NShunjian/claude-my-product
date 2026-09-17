/**
 * 主题色板/圆角/间距 token。
 * ponytail: 与 uniapp theme/tokens.ts 1:1 同步,颜色微调对齐 HarmonyOS 设计语言。
 */

export interface ThemeColors {
  bg: string
  bgCard: string
  surface: string
  divider: string
  text: string
  textVariant: string
  primary: string
  primaryLight: string
  onPrimary: string
  secondaryContainer: string
  onSecondaryContainer: string
  error: string
  errorContainer: string
  onErrorContainer: string
  success: string
  navy: string
}

export interface RadiusTokens { sm: number; md: number; lg: number; pill: number }
export interface SpaceTokens { xs: number; sm: number; md: number; lg: number; xl: number }

export interface AppTheme { isDark: boolean; colors: ThemeColors; radius: RadiusTokens; space: SpaceTokens }

const lightColors: ThemeColors = {
  bg: '#F8F8F8',
  bgCard: '#FFFFFF',
  surface: '#F1F5F9',
  divider: '#E2E8F0',
  text: '#0F172A',
  textVariant: '#64748B',
  primary: '#005394',
  primaryLight: '#E5EEFF',
  onPrimary: '#FFFFFF',
  secondaryContainer: '#D1FAE5',
  onSecondaryContainer: '#047857',
  error: '#BA1A1A',
  errorContainer: '#FFEBEE',
  onErrorContainer: '#B91C1C',
  success: '#10B981',
  navy: '#141E3C',
}

const darkColors: ThemeColors = {
  bg: '#0B0F19',
  bgCard: '#141A29',
  surface: '#1C2436',
  divider: '#2A3349',
  text: '#F1F5F9',
  textVariant: '#94A3B8',
  primary: '#5EA0FF',
  primaryLight: '#1B2A45',
  onPrimary: '#FFFFFF',
  secondaryContainer: '#064E3B',
  onSecondaryContainer: '#6EE7B7',
  error: '#FF6B6B',
  errorContainer: '#3A1418',
  onErrorContainer: '#FCA5A5',
  success: '#34D399',
  navy: '#0A1024',
}

const radius: RadiusTokens = { sm: 8, md: 12, lg: 16, pill: 999 }
const space: SpaceTokens = { xs: 4, sm: 8, md: 16, lg: 24, xl: 32 }

export const lightTheme: AppTheme = { isDark: false, colors: lightColors, radius, space }
export const darkTheme: AppTheme = { isDark: true, colors: darkColors, radius, space }

export function getTheme(isDark: boolean): AppTheme { return isDark ? darkTheme : lightTheme }
