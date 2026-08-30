import { useAdminAuth } from './AdminAuthContext'

/**
 * 权限判定 hook —— super_admin 永远通过。
 *
 *  permission codes 匹配 V5 SQL seed 的字段:
 *    user:list / user:detail / user:disable / user:reset_password / user:grant_role
 *    category:preset:list / create / update / delete
 *    book:list / book:view
 *    record:list / record:view
 *    dashboard:view / audit:list / role:grant / role:revoke
 */
export function usePermissions() {
  const { permissions, isSuperAdmin } = useAdminAuth()
  const set = new Set(permissions)
  const has = (code: string) => isSuperAdmin || set.has(code)
  const hasAny = (codes: string[]) => isSuperAdmin || codes.some((c) => set.has(c))
  return { has, hasAny, isSuperAdmin }
}
