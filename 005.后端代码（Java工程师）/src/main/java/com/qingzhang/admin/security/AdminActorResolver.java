package com.qingzhang.admin.security;

import com.baomidou.dynamic.datasource.annotation.DS;
import com.qingzhang.admin.entity.AdminUser;
import com.qingzhang.admin.mapper.AdminUserMapper;
import com.qingzhang.auth.JwtAuthFilter;
import com.qingzhang.common.BizException;
import com.qingzhang.common.ErrorCode;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.stereotype.Component;

/**
 * 从 HttpServletRequest 里抽 AdminActor —— 给所有 admin 域 controller 共用。
 *
 * 抽到这里的原因:BusinessUsersController 调用链跨库(master + admin),
 * 不能在 controller 类上挂 @DS("admin")(会让后续 service 调用全跑 admin 库)。
 * 把 actor 查询封进一个独立的 @DS("admin") bean,controller 自身保持 master 默认,
 * 调 actor 时透到 admin 库,执行完回 master。
 *
 * ponytail:UsersController (admin 子) 没切,仍在自己类上挂 @DS("admin") —— 因为
 * 它的 service 也是 admin 库,没跨库冲突。等下次统一收编。
 */
@Component
@DS("admin")
public class AdminActorResolver {

    private final AdminUserMapper adminUserMapper;

    public AdminActorResolver(AdminUserMapper adminUserMapper) {
        this.adminUserMapper = adminUserMapper;
    }

    public AdminActor resolve(HttpServletRequest req) {
        Long uid = (Long) req.getAttribute(JwtAuthFilter.USER_ID_ATTR);
        if (uid == null) {
            throw new BizException(ErrorCode.ADMIN_AUTH_REQUIRED, "未登录");
        }
        AdminUser u = adminUserMapper.selectById(uid);
        String username = u == null ? "unknown" : u.getUsername();
        return new AdminActor(uid, username, req.getRemoteAddr(), req.getHeader("User-Agent"));
    }
}