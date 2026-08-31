import type { ReactNode } from 'react'
import { usePermissions } from '../auth/usePermissions'

export function PermissionGate({ code, children }: { code: string; children: ReactNode }) {
  const { has } = usePermissions()
  if (!has(code)) return null
  return <>{children}</>
}
