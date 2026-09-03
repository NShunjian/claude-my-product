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
  /** 后端 V1.1 暴露:true=系统预设(只读)/false=用户自定义(可改可删) */
  isPreset: boolean
  /** Unix 秒,=后端 categories.created_at。uniapp 用它把自定义分类按"最新在前"排;
   *  React 端目前不在分类管理页用到此字段,这里挂个可选字段以保持类型与后端一致。 */
  createdAt?: string
}

export interface ListCategoriesResponse {
  items: Category[]
}

export interface CategoryEnvelope {
  category: Category
}

export interface CreateCategoryInput {
  type: CategoryType
  name: string
  icon: string
  color?: string
  sortOrder?: number
}

export interface UpdateCategoryInput {
  name?: string
  icon?: string
  color?: string
  sortOrder?: number
}

export async function listCategories(type?: CategoryType): Promise<Category[]> {
  const qs = type ? `?type=${type}` : ''
  const res = await request<ListCategoriesResponse>(`/api/categories${qs}`)
  return res.items
}

export async function createCategory(input: CreateCategoryInput): Promise<Category> {
  const res = await request<CategoryEnvelope>('/api/categories', {
    method: 'POST',
    body: JSON.stringify(input),
  })
  return res.category
}

export async function updateCategory(id: string, input: UpdateCategoryInput): Promise<Category> {
  const res = await request<CategoryEnvelope>(`/api/categories/${encodeURIComponent(id)}`, {
    method: 'PATCH',
    body: JSON.stringify(input),
  })
  return res.category
}

export async function deleteCategory(id: string): Promise<void> {
  await request<{ ok: true }>(`/api/categories/${encodeURIComponent(id)}`, { method: 'DELETE' })
}
