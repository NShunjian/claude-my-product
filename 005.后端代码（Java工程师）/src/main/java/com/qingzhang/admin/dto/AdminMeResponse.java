package com.qingzhang.admin.dto;
import java.util.List;
public record AdminMeResponse(
    long id, String uuid, String username, String displayName,
    boolean isSuperAdmin,
    List<String> permissions,
    List<String> roleCodes
) {}
