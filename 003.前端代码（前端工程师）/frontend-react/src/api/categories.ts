import { request } from '../lib/api'

export type CategoryType = 'expense' | 'income'

export interface Category {
  id: string
  type: CategoryType
  name: string
  /** 后端存 emoji；前端可在 UI 层映射到 Material Symbols */
  icon: string
  color: string
  sortOrder: number
}

export interface ListCategoriesResponse {
  items: Category[]
}

export async function listCategories(type?: CategoryType): Promise<Category[]> {
  const qs = type ? `?type=${type}` : ''
  const res = await request<ListCategoriesResponse>(`/api/categories${qs}`)
  return res.items
}
