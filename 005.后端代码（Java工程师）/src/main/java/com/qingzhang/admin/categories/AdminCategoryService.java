package com.qingzhang.admin.categories;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.qingzhang.admin.audit.AdminAuditService;
import com.qingzhang.admin.dto.AdminCategoryListItem;
import com.qingzhang.admin.dto.AdminPresetCategoryRequest;
import com.qingzhang.admin.dto.Page;
import com.qingzhang.admin.security.AdminActor;
import com.qingzhang.categories.entity.Category;
import com.qingzhang.categories.mapper.CategoryMapper;
import com.qingzhang.common.BizException;
import com.qingzhang.common.ErrorCode;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * 预设分类管理 —— 列表/新建/修改/删除。所有变更过 AuditService 写审计。
 *
 * 范围限定 is_preset=1 AND user_id IS NULL AND book_id IS NULL 的全局分类。
 * 用户私有分类不进 admin(走普通用户 API)。
 */
@Service
public class AdminCategoryService {

    private static final Logger log = LoggerFactory.getLogger(AdminCategoryService.class);

    private final CategoryMapper categoryMapper;
    private final AdminAuditService auditService;

    public AdminCategoryService(CategoryMapper categoryMapper, AdminAuditService auditService) {
        this.categoryMapper = categoryMapper;
        this.auditService = auditService;
    }

    /** 列预设分类 —— 可按 type / name 过滤,分页。 */
    public Page<AdminCategoryListItem> list(String type, String name, long page, long size) {
        long p = Math.max(1, page);
        long s = Math.min(Math.max(1, size), 100);

        QueryWrapper<Category> q = new QueryWrapper<>();
        q.eq("is_preset", 1)
                .isNull("user_id")
                .isNull("book_id");
        if (type != null && !type.isBlank()) {
            q.eq("type", type.trim());
        }
        if (name != null && !name.isBlank()) {
            q.like("name", name.trim());
        }
        q.orderByAsc("sort_order").orderByAsc("id");

        IPage<Category> mp = categoryMapper.selectPage(new com.baomidou.mybatisplus.extension.plugins.pagination.Page<>(p, s), q);
        long total = mp.getTotal();
        List<AdminCategoryListItem> items = mp.getRecords().stream().map(this::toListItem).collect(Collectors.toList());
        return new Page<>(items, total, s, p);
    }

    /** 新建预设分类。审计: category.preset.create。 */
    @Transactional(rollbackFor = Exception.class)
    public AdminCategoryListItem create(AdminPresetCategoryRequest body, AdminActor actor) {
        validateCreateBody(body);

        if (isDuplicateName(body.type(), body.name(), null)) {
            auditService.recordFailure(actor.userId(), actor.username(),
                    "category.preset.create", "category", null,
                    "同名预设分类已存在: " + body.type() + "/" + body.name(),
                    actor.ip(), actor.userAgent());
            throw new BizException(ErrorCode.ADMIN_TARGET_NOT_FOUND, "同名预设分类已存在");
        }

        Instant now = Instant.now();
        Category c = Category.builder()
                .userId(null)
                .bookId(null)
                .type(body.type())
                .name(body.name())
                .icon(body.icon())
                .color(body.color())
                .sortOrder(body.sortOrder() != null ? body.sortOrder() : 0)
                .isPreset((byte) 1)
                .isActive((byte) 1)
                .createdAt(now)
                .updatedAt(now)
                .build();
        categoryMapper.insert(c);
        long id = c.getId();
        log.info("[admin] category.preset.create: id={} name={} actor={}", id, c.getName(), actor.username());

        Map<String, Object> after = new HashMap<>();
        after.put("type", c.getType());
        after.put("name", c.getName());
        after.put("icon", c.getIcon());
        after.put("color", c.getColor());
        after.put("sortOrder", c.getSortOrder());
        after.put("isActive", true);
        auditService.recordSuccess(actor.userId(), actor.username(),
                "category.preset.create", "category", id,
                null, after, actor.ip(), actor.userAgent());

        return toListItem(c, 0L);
    }

    /** 修改预设分类 —— PATCH,任意字段子集。审计: category.preset.update。 */
    @Transactional(rollbackFor = Exception.class)
    public AdminCategoryListItem update(long id, AdminPresetCategoryRequest body, AdminActor actor) {
        Category existing = mustPreset(id);
        if (body.name() != null && isDuplicateName(existing.getType(), body.name(), id)) {
            auditService.recordFailure(actor.userId(), actor.username(),
                    "category.preset.update", "category", id,
                    "同名预设分类已存在: " + existing.getType() + "/" + body.name(),
                    actor.ip(), actor.userAgent());
            throw new BizException(ErrorCode.ADMIN_TARGET_NOT_FOUND, "同名预设分类已存在");
        }

        Map<String, Object> before = new HashMap<>();
        before.put("type", existing.getType());
        before.put("name", existing.getName());
        before.put("icon", existing.getIcon());
        before.put("color", existing.getColor());
        before.put("sortOrder", existing.getSortOrder());
        before.put("isActive", existing.getIsActive());

        if (body.name() != null) existing.setName(body.name());
        if (body.icon() != null) existing.setIcon(body.icon());
        if (body.color() != null) existing.setColor(body.color());
        if (body.sortOrder() != null) existing.setSortOrder(body.sortOrder());
        existing.setUpdatedAt(Instant.now());
        // isActive 通过独立路径(PATCH /status?)留给 v2;v1 在 update body 里允许通过
        // 传 null 区分"不改"。此处默认不改。
        categoryMapper.updateById(existing);

        Map<String, Object> after = new HashMap<>();
        after.put("type", existing.getType());
        after.put("name", existing.getName());
        after.put("icon", existing.getIcon());
        after.put("color", existing.getColor());
        after.put("sortOrder", existing.getSortOrder());
        after.put("isActive", existing.getIsActive());
        auditService.recordSuccess(actor.userId(), actor.username(),
                "category.preset.update", "category", id,
                before, after, actor.ip(), actor.userAgent());
        log.info("[admin] category.preset.update: id={} actor={}", id, actor.username());

        return toListItem(existing, 0L);
    }

    /** 切换预设分类启用状态。审计: category.preset.update。 */
    @Transactional(rollbackFor = Exception.class)
    public AdminCategoryListItem updateStatus(long id, boolean enabled, AdminActor actor) {
        Category existing = mustPreset(id);
        byte newActive = (byte) (enabled ? 1 : 0);
        Map<String, Object> before = new HashMap<>();
        before.put("isActive", existing.getIsActive());
        existing.setIsActive(newActive);
        existing.setUpdatedAt(Instant.now());
        categoryMapper.updateById(existing);
        Map<String, Object> after = new HashMap<>();
        after.put("isActive", newActive);
        auditService.recordSuccess(actor.userId(), actor.username(),
                "category.preset.update", "category", id,
                before, after, actor.ip(), actor.userAgent());
        log.info("[admin] category.preset.update: id={} isActive={} actor={}", id, newActive, actor.username());
        return toListItem(existing, 0L);
    }

    /** 软删除预设分类。审计: category.preset.delete。 */
    @Transactional(rollbackFor = Exception.class)
    public void delete(long id, AdminActor actor) {
        Category existing = mustPreset(id);
        Map<String, Object> before = new HashMap<>();
        before.put("type", existing.getType());
        before.put("name", existing.getName());
        before.put("isActive", existing.getIsActive());
        // MyBatis-Plus @TableLogic 自动把 deletedAt 置为 NOW()
        categoryMapper.deleteById(id);

        auditService.recordSuccess(actor.userId(), actor.username(),
                "category.preset.delete", "category", id,
                before, null, actor.ip(), actor.userAgent());
        log.info("[admin] category.preset.delete: id={} actor={}", id, actor.username());
    }

    // -------- helpers --------

    private Category mustPreset(long id) {
        Category c = categoryMapper.selectById(id);
        if (c == null || c.getIsPreset() == null || c.getIsPreset() != 1) {
            throw new BizException(ErrorCode.ADMIN_TARGET_NOT_FOUND, "预设分类不存在: id=" + id);
        }
        return c;
    }

    private void validateCreateBody(AdminPresetCategoryRequest body) {
        if (body == null) {
            throw new BizException(ErrorCode.ADMIN_TARGET_NOT_FOUND, "请求体为空");
        }
        if (body.type() == null || (!"expense".equals(body.type()) && !"income".equals(body.type()))) {
            throw new BizException(ErrorCode.ADMIN_TARGET_NOT_FOUND, "type 必须为 expense / income");
        }
        if (body.name() == null || body.name().isBlank()) {
            throw new BizException(ErrorCode.ADMIN_TARGET_NOT_FOUND, "name 不能为空");
        }
    }

    /** 预设分类同名检查 —— 同 type + 同 name 视为重复,排除当前 id。 */
    private boolean isDuplicateName(String type, String name, Long excludeId) {
        if (type == null || name == null) return false;
        QueryWrapper<Category> q = new QueryWrapper<>();
        q.eq("type", type)
                .eq("name", name)
                .eq("is_preset", 1)
                .isNull("user_id");
        if (excludeId != null) {
            q.ne("id", excludeId);
        }
        Long c = categoryMapper.selectCount(q);
        return c != null && c > 0;
    }

    private AdminCategoryListItem toListItem(Category c) {
        return toListItem(c, 0L);  // v1:不预聚合 usage count
    }

    private AdminCategoryListItem toListItem(Category c, long usageCount) {
        return new AdminCategoryListItem(
                c.getId(),
                c.getUuid(),
                c.getType(),
                c.getName(),
                c.getIcon(),
                c.getColor(),
                c.getSortOrder(),
                c.getIsActive() != null && c.getIsActive() == 1,
                c.getCreatedAt(),
                c.getUpdatedAt(),
                usageCount
        );
    }
}
