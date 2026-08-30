/**
 * 后端 DTO 一一对应的类型 —— 字段名严格匹配 Java record。
 * 修改任一字段前先同步后端,不然 TS 编译就报错 —— 这是好事。
 */

// ====== 通用信封 ======
export interface ApiResponse<T> {
  code: number
  message: string
  data: T
}
export interface Page<T> {
  records: T[]
  total: number
  size: number
  current: number
}
export type Byte = 0 | 1

// ====== 鉴权 ======
export interface AdminMeResponse {
  id: number
  uuid: string
  username: string
  displayName: string
  isSuperAdmin: boolean
  permissions: string[]
  roleCodes: string[]
}
export interface AuthLoginRequest {
  username: string
  password: string
}
export interface AuthUserDto {
  id: number
  uuid: string
  username: string
  displayName: string
}
export interface AuthLoginResponse {
  user: AuthUserDto
  token: string
  permissions: string[]
  roleCodes: string[]
  isSuperAdmin: boolean
}

// ====== 用户管理 ======
export interface AdminUserListItem {
  id: number
  uuid: string
  username: string
  displayName: string
  status: Byte
  lastLoginAt: string | null
  createdAt: string
  recordCount: number
  bookCount: number
}
export interface AdminUserDetailResponse {
  id: number
  uuid: string
  username: string
  displayName: string
  avatar: string | null
  gender: string | null
  age: number | null
  email: string | null
  phone: string | null
  status: Byte
  lastLoginAt: string | null
  createdAt: string
  roles: string[]
}
export interface AdminUpdateUserStatusRequest {
  enabled: boolean
}
export interface AdminResetPasswordResponse {
  newPassword: string
}
export interface AdminGrantRoleRequest {
  roleCode: string
}

// ====== 预设分类 ======
export interface AdminCategoryListItem {
  id: number
  uuid: string
  type: 'expense' | 'income'
  name: string
  icon: string | null
  color: string | null
  sortOrder: number | null
  isActive: boolean
  createdAt: string
  updatedAt: string
  usageCount: number
}
export interface AdminPresetCategoryRequest {
  type: 'expense' | 'income'
  name: string
  icon?: string
  color?: string
  sortOrder?: number
}

// ====== 审计视图 ======
export interface AdminBookListItem {
  uuid: string
  name: string
  type: string
  currency: string
  ownerId: number
  ownerUsername: string
  accountCount: number
  recordCount: number
  createdAt: string
}
export interface AdminRecordListItem {
  uuid: string
  type: string
  amount: string  // BigDecimal as string
  currency: string
  note: string | null
  recordDate: string  // YYYY-MM-DD
  source: string
  userId: number
  username: string
  bookUuid: string | null
  bookName: string | null
  categoryName: string | null
  accountName: string | null
  createdAt: string
}
export interface AdminDashboardStats {
  userCount: number
  userNewToday: number
  userActive7d: number
  bookCount: number
  accountCount: number
  recordCount: number
  recordToday: number
  newUsersLast7Days: { date: string; count: number }[]
  newRecordsLast7Days: { date: string; count: number }[]
}

// ====== 审计日志 ======
export interface AdminAuditLogListItem {
  uuid: string
  actorUsername: string
  action: string
  targetType: string | null
  targetId: number | null
  result: 'success' | 'failure'
  createdAt: string
}
export interface AdminAuditLogDetailResponse {
  uuid: string
  actorUsername: string
  actorUserId: number
  action: string
  targetType: string | null
  targetId: number | null
  beforeSnapshot: string | null
  afterSnapshot: string | null
  ip: string | null
  userAgent: string | null
  result: 'success' | 'failure'
  errorMsg: string | null
  createdAt: string
}
