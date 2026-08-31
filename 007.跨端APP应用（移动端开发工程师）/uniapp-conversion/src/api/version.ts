import { request } from './http'

/** 后端 GET /api/version 响应 */
export interface SystemVersionResponse {
  version: string
}

/** 拉取后端权威版本号（无鉴权） */
export function getSystemVersion(): Promise<SystemVersionResponse> {
  return request<SystemVersionResponse>('/api/version')
}
