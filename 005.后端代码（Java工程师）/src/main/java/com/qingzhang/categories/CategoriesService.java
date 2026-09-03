package com.qingzhang.categories;

import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import com.qingzhang.categories.dto.CategoryResponse;
import com.qingzhang.categories.dto.CreateCategoryRequest;
import com.qingzhang.categories.dto.UpdateCategoryRequest;
import com.qingzhang.categories.entity.Category;
import com.qingzhang.categories.mapper.CategoryMapper;
import com.qingzhang.common.BizException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * 分类域业务。
 *
 * 错误码:50xx 分类域(spec §5.3 V1.1):
 *   5001  CATEGORY_NOT_FOUND
 *   5002  CATEGORY_PRESET_LOCKED
 *   5003  CATEGORY_NAME_DUPLICATE
 *
 * 设计要点:
 *   1. 列表:返回预设(user_id=NULL) + 当前用户自定义(V1.1 用户级全局,book_id=NULL)。
 *   2. 写操作:仅 user 自己创建的(is_preset=0)可改可删。预设不可改。
 *   3. 同 (user_id, type) 内 name 唯一 —— 走 idx_categories_user_type + DB 抛异常,
 *      这里先 selectCount 主动校验,失败时给 5003。
 */
@Service
public class CategoriesService {

    private static final int CODE_CATEGORY_NOT_FOUND     = 5001;
    private static final int CODE_CATEGORY_PRESET_LOCKED = 5002;
    private static final int CODE_CATEGORY_NAME_DUP      = 5003;

    private final CategoryMapper categoryMapper;

    public CategoriesService(CategoryMapper categoryMapper) {
        this.categoryMapper = categoryMapper;
    }

    public List<CategoryResponse> list(long userId, String type) {
        return categoryMapper.selectList(
                Wrappers.<Category>lambdaQuery()
                        .and(w -> w.isNull(Category::getUserId).or().eq(Category::getUserId, userId))
                        .eq(Category::getIsActive, (byte) 1)
                        .eq(type != null, Category::getType, type)
                        .orderByAsc(Category::getSortOrder)
                        // 同 sort_order(自定义默认 0)内,二级按 created_at DESC,保证自定义分类返回时已"最新在前";
                        // 预设分类 sort_order 各不相同,created_at DESC 不会改变其视觉顺序。
                        .orderByDesc(Category::getCreatedAt)
        ).stream().map(this::toResponse).toList();
    }

    // ===== 创建自定义分类 =====

    @Transactional(rollbackFor = Exception.class)
    public CategoryResponse create(long userId, CreateCategoryRequest req) {
        // 业务校验:type
        if (!"expense".equals(req.type()) && !"income".equals(req.type())) {
            throw new BizException(CODE_CATEGORY_NOT_FOUND, "type 必须是 expense / income");
        }
        // 业务校验:name 不与同用户同类预设冲突
        if (existsByName(userId, req.type(), null, req.name())) {
            throw new BizException(CODE_CATEGORY_NAME_DUP,
                    "已存在同名分类: " + req.name());
        }
        Instant now = Instant.now();
        Category c = Category.builder()
                .uuid(UUID.randomUUID().toString())
                .userId(userId)
                .bookId(null)                // 用户级全局
                .type(req.type())
                .name(req.name())
                .icon(req.icon())
                .color(req.color() == null ? "#A0AEC0" : req.color())
                .isPreset((byte) 0)
                .isActive((byte) 1)
                .sortOrder(req.sortOrder() == null ? 0 : req.sortOrder())
                .createdAt(now)
                .updatedAt(now)
                .build();
        categoryMapper.insert(c);
        return toResponse(c);
    }

    // ===== 修改 =====

    @Transactional(rollbackFor = Exception.class)
    public CategoryResponse update(long userId, String uuid, UpdateCategoryRequest req) {
        Category c = mustOwnedCustom(userId, uuid);

        if (req.name() != null) {
            if (req.name().isBlank()) {
                throw new BizException(CODE_CATEGORY_NOT_FOUND, "name 不能为空");
            }
            if (!req.name().equals(c.getName())) {
                // 重命名:在 (user, new type) 下查重,排除自己
                String typeForCheck = req.type() != null ? req.type() : c.getType();
                if (existsByName(userId, typeForCheck, c.getId(), req.name())) {
                    throw new BizException(CODE_CATEGORY_NAME_DUP,
                            "已存在同名分类: " + req.name());
                }
            }
            c.setName(req.name());
        }
        if (req.icon() != null) c.setIcon(req.icon());
        if (req.color() != null) c.setColor(req.color());
        if (req.type() != null) {
            if (!"expense".equals(req.type()) && !"income".equals(req.type())) {
                throw new BizException(CODE_CATEGORY_NOT_FOUND, "type 必须是 expense / income");
            }
            c.setType(req.type());
        }
        if (req.sortOrder() != null) c.setSortOrder(req.sortOrder());
        c.setUpdatedAt(Instant.now());
        categoryMapper.updateById(c);
        return toResponse(c);
    }

    // ===== 删除(软删) =====

    @Transactional(rollbackFor = Exception.class)
    public void delete(long userId, String uuid) {
        Category c = mustOwnedCustom(userId, uuid);
        // 软删:is_active=0,records.fk_categories 是 SET NULL,删除后关联账目的 categoryId 自动清空
        c.setIsActive((byte) 0);
        c.setUpdatedAt(Instant.now());
        categoryMapper.updateById(c);
    }

    // ===== 内部 =====

    /** 校验是否是自己的「非预设」分类。预设抛 5002,不存在抛 5001,非本人抛 5001。 */
    private Category mustOwnedCustom(long userId, String uuid) {
        Category c = categoryMapper.selectOne(Wrappers.<Category>lambdaQuery()
                .eq(Category::getUuid, uuid));
        if (c == null) {
            throw new BizException(CODE_CATEGORY_NOT_FOUND, "分类不存在: " + uuid);
        }
        if (c.getIsPreset() != null && c.getIsPreset() == 1) {
            throw new BizException(CODE_CATEGORY_PRESET_LOCKED, "预设分类不可修改或删除");
        }
        if (c.getUserId() == null || c.getUserId() != userId) {
            throw new BizException(CODE_CATEGORY_NOT_FOUND, "无权操作该分类");
        }
        return c;
    }

    /** 检查同 (user_id 维度, type) 下是否已有同名(name)的分类。预设(user_id NULL)也算。excludeId 用于「编辑自己」时排除自身。 */
    private boolean existsByName(long userId, String type, Long excludeId, String name) {
        Long count = categoryMapper.selectCount(
                Wrappers.<Category>lambdaQuery()
                        .eq(Category::getName, name)
                        .eq(Category::getIsActive, (byte) 1)
                        .eq(type != null, Category::getType, type)
                        .and(w -> w.isNull(Category::getUserId).or().eq(Category::getUserId, userId))
                        .ne(excludeId != null, Category::getId, excludeId)
        );
        return count != null && count > 0;
    }

    private CategoryResponse toResponse(Category c) {
        return new CategoryResponse(
                c.getUuid(),
                c.getType(),
                c.getName(),
                c.getIcon(),
                c.getColor(),
                c.getSortOrder(),
                c.getIsPreset() != null && c.getIsPreset() == 1,
                c.getCreatedAt() == null ? null : c.getCreatedAt().getEpochSecond()
        );
    }
}
