package com.qingzhang.admin.users.dto;

/**
 * 批量硬删管理员账号响应 —— 实际销毁数 + 跳过数。
 *
 * 管理员账号硬删范围很窄:只删 admin_users 行本身,
 * admin_user_roles 由 FK CASCADE 自动清;admin_audit_logs 不动(actor 历史是合规资产)。
 *
 * 「跳过」包含:不存在 / 是自己 / 是最后一个 super_admin(返回时分别记入 skipped)。
 *
 * 前端 toast 直接显示 `已删除 X,跳过 Y`。
 */
public record BatchDeleteAdminUsersResponse(
        int deleted,
        int skipped
) {
}
