import { useAdminAuth } from './AdminAuthContext'

/**
 * 权限判定 hook —— super_admin 永远通过。
 *
 *  permission codes 匹配 V6 SQL seed 的字段:
 *    user:list / user:view / user:disable / user:reset_password
 *    category:preset:list / create / update / delete
 *    book:list / book:view
 *    record:list / record:view
 *    dashboard:view / audit:list / role:grant / role:revoke
 *    business_user:list / view / disable / reset_password
 */
export function usePermissions() {
  const { permissions, roleCodes, isSuperAdmin } = useAdminAuth()
  const set = new Set(permissions)
  const has = (code: string) => isSuperAdmin || set.has(code)
  const hasAny = (codes: string[]) => isSuperAdmin || codes.some((c) => set.has(c))
  return { has, hasAny, isSuperAdmin, roleCodes }
}
