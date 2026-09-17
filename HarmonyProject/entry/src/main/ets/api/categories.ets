/**
 * 分类 API:对齐 uniapp api/categories.ts 1:1。
 */
import { request } from './http'
import type { Category, CategoryCreatePayload, CategoryUpdatePayload } from '../model/Types'

export function listCategories(type: 'expense' | 'income'): Promise<Category[]> {
  return request<Category[]>(`/categories?type=${type}`)
}
export function createCategory(payload: CategoryCreatePayload): Promise<Category> {
  return request<Category>('/categories', { method: 'POST', data: payload })
}
export function updateCategory(id: string, payload: CategoryUpdatePayload): Promise<Category> {
  return request<Category>(`/categories/${id}`, { method: 'PUT', data: payload })
}
export function deleteCategory(id: string): Promise<void> {
  return request<void>(`/categories/${id}`, { method: 'DELETE' })
}

export type { Category, CategoryCreatePayload, CategoryUpdatePayload, CategoryType } from '../model/Types'
