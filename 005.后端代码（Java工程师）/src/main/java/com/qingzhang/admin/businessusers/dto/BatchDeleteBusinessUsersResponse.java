package com.qingzhang.admin.businessusers.dto;

/**
 * 批量硬删业务用户响应 —— 返回各表实际销毁的行数。
 *
 * 硬删是不可逆操作,操作员需要在响应里看到「真删了多少」用于事后核对。
 *
 * 字段语义:
 *   usersDeleted      — users 表硬删的行数
 *   booksDeleted      — 该用户拥有的 books 行数(FK CASCADE 不止 books,book_members / budgets 跟着)
 *   recordsDeleted    — 该用户全部 records(先于 books 删,绕过 records.book_id RESTRICT)
 *   accountsDeleted   — 该用户账户(FK CASCADE 也会从 user 删除触发,这里显式调是为准确计数)
 *   categoriesDeleted — 该用户分类
 *   skipped           — ids 中不存在 / 已被软删 / 已是自己的,这些跳过
 *
 * ponytail:不返回 success boolean,前端看 deleted + skipped 决定 toast 文案。
 */
public record BatchDeleteBusinessUsersResponse(
        int usersDeleted,
        int booksDeleted,
        int recordsDeleted,
        int accountsDeleted,
        int categoriesDeleted,
        int skipped
) {
}
