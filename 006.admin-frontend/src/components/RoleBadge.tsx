import type { CSSProperties } from 'react'

/**
 * 角色标签 —— 3 种角色对应不同颜色
 *   super_admin       超级管理员    红
 *   vice_super_admin  副超级管理员  紫
 *   admin             管理员        蓝
 *   viewer            只读审计员    灰
 *   其它(未知 code)               默认灰
 *
 * 副管理员 (vice_admin) 已在 V7 删除。
 */

interface RoleMeta {
  label: string
  color: string
  bg: string
  border: string
}

const ROLE_META: Record<string, RoleMeta> = {
  super_admin:       { label: '超级管理员',   color: '#fff', bg: '#dc2626', border: '#b91c1c' }, // 红
  vice_super_admin:  { label: '副超级管理员', color: '#fff', bg: '#7c3aed', border: '#6d28d9' }, // 紫
  admin:             { label: '管理员',       color: '#fff', bg: '#2563eb', border: '#1d4ed8' }, // 蓝
  viewer:            { label: '只读审计员',   color: '#fff', bg: '#6b7280', border: '#4b5563' }, // 灰
}

const DEFAULT_META: RoleMeta = { label: '未知角色', color: '#fff', bg: '#9ca3af', border: '#6b7280' }

export function roleLabel(code: string | undefined | null): string {
  if (!code) return ''
  return ROLE_META[code]?.label ?? code
}

export function roleMeta(code: string): RoleMeta {
  return ROLE_META[code] ?? { ...DEFAULT_META, label: code }
}

interface Props {
  code: string
  size?: 'sm' | 'md'
}

export default function RoleBadge({ code, size = 'md' }: Props) {
  const meta = roleMeta(code)
  const padding = size === 'sm' ? '1px 6px' : '2px 8px'
  const fontSize = size === 'sm' ? 11 : 12
  const style: CSSProperties = {
    display: 'inline-block',
    padding,
    fontSize,
    lineHeight: 1.4,
    fontWeight: 600,
    color: meta.color,
    backgroundColor: meta.bg,
    border: `1px solid ${meta.border}`,
    borderRadius: 4,
    marginRight: 4,
    whiteSpace: 'nowrap',
    letterSpacing: 0.2,
  }
  return <span style={style}>{meta.label}</span>
}

/** 多角色并排显示(同一行,逗号分隔由父容器布局) */
export function RoleBadgeList({ codes }: { codes: string[] | undefined }) {
  if (!codes || codes.length === 0) {
    return <span style={{ color: '#9ca3af', fontSize: 12 }}>—</span>
  }
  return (
    <>
      {codes.map((c) => (
        <RoleBadge key={c} code={c} size="sm" />
      ))}
    </>
  )
}
