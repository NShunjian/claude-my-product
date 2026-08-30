package com.qingzhang.admin.businessusers.dto;

import java.util.List;

/**
 * 批量删除业务用户请求体 —— 选中的用户 id 列表(单次上限 100,后端校验)。
 */
public record BatchDeleteBusinessUsersRequest(
        List<Long> ids
) {
}