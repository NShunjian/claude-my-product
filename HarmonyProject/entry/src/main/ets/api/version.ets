/**
 * 版本 API:对齐 uniapp api/version.ts。
 */
import { request } from './http'
import type { SystemVersion } from '../model/Types'

export function getSystemVersion(): Promise<SystemVersion> {
  return request<SystemVersion>('/system/version', { silent401: true })
}
