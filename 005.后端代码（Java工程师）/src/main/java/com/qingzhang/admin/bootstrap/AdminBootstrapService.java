package com.qingzhang.admin.bootstrap;

import com.baomidou.dynamic.datasource.annotation.DS;
import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.qingzhang.admin.entity.AdminRole;
import com.qingzhang.admin.entity.AdminUser;
import com.qingzhang.admin.entity.AdminUserRole;
import com.qingzhang.admin.mapper.AdminRoleMapper;
import com.qingzhang.admin.mapper.AdminUserMapper;
import com.qingzhang.admin.mapper.AdminUserRoleMapper;
import com.qingzhang.common.BizException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.core.annotation.Order;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.UUID;

/**
 * 启动时引导:用环境变量 ADMIN_BOOTSTRAP_USERNAME / ADMIN_BOOTSTRAP_PASSWORD
 * 创建第一个超级管理员账号。幂等 —— 已存在则跳过,缺失任一环境变量则跳过。
 *
 * V6 改造:写入 admin_users 而非 users(独立表,F6 split 后 admin 与普通用户分离)。
 *
 * ponytail:不引 Flyway callback / 数据初始化 SQL,把"第一个 admin"放到代码里
 * 因为有密码 hash(BCrypt),不适合 SQL seed。
 */
@Service
@DS("admin")
@Order(1)  // 先于其他 CommandLineRunner 跑(虽然这个项目里只有这一个)
public class AdminBootstrapService implements CommandLineRunner {

    private static final Logger log = LoggerFactory.getLogger(AdminBootstrapService.class);
    private static final String SUPER_ADMIN_CODE = "super_admin";

    private final AdminUserMapper adminUserMapper;
    private final AdminRoleMapper roleMapper;
    private final AdminUserRoleMapper userRoleMapper;
    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();

    @Value("${admin.bootstrap.username:}")
    private String bootstrapUsername;

    @Value("${admin.bootstrap.password:}")
    private String bootstrapPassword;

    public AdminBootstrapService(AdminUserMapper adminUserMapper,
                                 AdminRoleMapper roleMapper,
                                 AdminUserRoleMapper userRoleMapper) {
        this.adminUserMapper = adminUserMapper;
        this.roleMapper = roleMapper;
        this.userRoleMapper = userRoleMapper;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void run(String... args) {
        // 1. 没配环境变量 → 跳过
        if (bootstrapUsername == null || bootstrapUsername.isBlank()
                || bootstrapPassword == null || bootstrapPassword.isBlank()) {
            log.info("[admin-bootstrap] 未配置 ADMIN_BOOTSTRAP_USERNAME/PASSWORD,跳过引导");
            return;
        }

        // 2. 找 super_admin role (V5/V6 migration 必须已 seed)
        AdminRole superAdmin = roleMapper.selectOne(
                new QueryWrapper<AdminRole>().eq("code", SUPER_ADMIN_CODE)
        );
        if (superAdmin == null) {
            log.warn("[admin-bootstrap] 找不到 super_admin 角色 —— 请先跑 V5 Flyway migration。跳过引导。");
            return;
        }

        // 3. 找/创建 admin_users
        AdminUser existing = adminUserMapper.selectOne(
                new QueryWrapper<AdminUser>().eq("username", bootstrapUsername)
        );
        long adminUserId;
        if (existing == null) {
            Instant now = Instant.now();
            AdminUser u = AdminUser.builder()
                    .uuid(UUID.randomUUID().toString())
                    .username(bootstrapUsername)
                    .passwordHash(encoder.encode(bootstrapPassword))
                    .displayName("Root")
                    .status((byte) 1)
                    .createdAt(now)
                    .updatedAt(now)
                    .build();
            try {
                adminUserMapper.insert(u);
            } catch (Exception ex) {
                // username UNIQUE 冲突或密码列 NULL 等 —— BizException 上抛让启动失败
                throw new BizException(1499, "引导创建超级管理员失败: " + ex.getMessage());
            }
            adminUserId = u.getId();
            log.info("[admin-bootstrap] 已创建超级管理员用户: username={} id={}", bootstrapUsername, adminUserId);
        } else {
            adminUserId = existing.getId();
            log.info("[admin-bootstrap] 用户 {} 已存在 (id={}),跳过创建", bootstrapUsername, adminUserId);
        }

        // 4. 授权 super_admin role —— 幂等 + 全局唯一
        //   V13 后 admin_user_roles.super_admin_slot 是 UNIQUE 列,DB 层强制全局至多 1 个。
        //   bootstrap 既不能给"自己"重复授(原幂等检查),也不能给"已有别人持有"时强行授
        //   (否则 INSERT 会被 uk_super_admin_singleton 1062 拒掉,启动失败)。
        //   因此:任意 admin_users 已持有 super_admin → bootstrap 用户保持原角色跳过。
        Long selfLink = userRoleMapper.selectCount(
                new QueryWrapper<AdminUserRole>()
                        .eq("admin_user_id", adminUserId)
                        .eq("role_id", superAdmin.getId())
        );
        if (selfLink != null && selfLink > 0) {
            log.info("[admin-bootstrap] 用户 id={} 已绑定 super_admin,跳过授权", adminUserId);
            return;
        }
        Long globalLink = userRoleMapper.selectCount(
                new QueryWrapper<AdminUserRole>().eq("role_id", superAdmin.getId())
        );
        if (globalLink != null && globalLink > 0) {
            log.warn("[admin-bootstrap] super_admin 已有人持有,bootstrap 用户 {} (id={}) 保持原角色,跳过授权",
                    bootstrapUsername, adminUserId);
            return;
        }
        AdminUserRole link = new AdminUserRole();
        link.setAdminUserId(adminUserId);
        link.setRoleId(superAdmin.getId());
        link.setGrantedAt(Instant.now());
        link.setGrantedBy(null);  // 系统引导,无具体操作人
        userRoleMapper.insert(link);
        log.info("[admin-bootstrap] 已授予 super_admin: adminUserId={} roleId={}", adminUserId, superAdmin.getId());
    }
}