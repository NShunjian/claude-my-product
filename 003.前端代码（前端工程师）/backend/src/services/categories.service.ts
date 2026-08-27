import type { RowDataPacket } from 'mysql2'
import { getPool } from '../db/pool.js'
import type { Category, CategoryType } from '../types/index.js'

interface CategoryRow extends RowDataPacket {
  uuid: string
  type: CategoryType
  name: string
  icon: string
  color: string
  sort_order: number
}

const toCategory = (row: CategoryRow): Category => ({
  id: row.uuid,
  type: row.type,
  name: row.name,
  icon: row.icon,
  color: row.color,
})

/**
 * 列出系统预设分类。
 * V1.0 阶段所有分类是 user_id IS NULL 的系统预设，跨用户共享。
 * @param type 可选：限定支出/收入
 */
export const listCategories = async (type?: CategoryType): Promise<Category[]> => {
  const pool = getPool()
  const sql = type
    ? 'SELECT uuid, type, name, icon, color FROM categories WHERE type = ? AND is_active = 1 ORDER BY sort_order'
    : 'SELECT uuid, type, name, icon, color FROM categories WHERE is_active = 1 ORDER BY type, sort_order'
  const params = type ? [type] : []
  const [rows] = await pool.query<CategoryRow[]>(sql, params)
  return rows.map(toCategory)
}