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
  bg: '#FFFFFF',
  bgCard: '#FFFFFF',
  surface: '#F5F5F5',
  divider: '#E0E0E0',
  text: '#1A1A1A',
  textVariant: '#5F6368',
  primary: '#2E7DE6',
  primaryLight: '#D9E8FA',
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
  bg: '#0F1115',
  bgCard: '#181B22',
  surface: '#1F242C',
  divider: '#2A2F38',
  text: '#E6E8EC',
  textVariant: '#A0A6B2',
  primary: '#5BA3FF',
  primaryLight: '#1F3A60',
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
