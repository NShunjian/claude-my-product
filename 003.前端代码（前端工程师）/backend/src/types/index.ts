export interface User {
  id: number
  uuid: string
  username: string
  displayName: string | null
  createdAt: string
}

export interface JwtPayload {
  sub: number
  uuid: string
  username: string
}
