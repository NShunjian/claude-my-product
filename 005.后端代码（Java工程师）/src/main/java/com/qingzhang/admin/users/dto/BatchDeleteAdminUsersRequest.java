package com.qingzhang.admin.users.dto;

import java.util.List;

/**
 * 批量删除管理员账号 —— body: { ids: number[] },上限 100。
 *
 * ponytail: 与业务用户版本完全同形,不复用 —— admin / business 两个用户域的
 * DTO 演进方向不同(可能 admin 加 source 字段、business 加 reason 等),
 * 各写各的避免耦合。
 */
public record BatchDeleteAdminUsersRequest(List<Long> ids) {
}
