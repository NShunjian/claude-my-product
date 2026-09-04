package com.qingzhang.categories;

import com.qingzhang.categories.dto.CategoryResponse;
import com.qingzhang.categories.dto.CreateCategoryRequest;
import com.qingzhang.categories.dto.UpdateCategoryRequest;
import com.qingzhang.categories.entity.Category;
import com.qingzhang.categories.mapper.CategoryMapper;
import com.qingzhang.common.BizException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * 005 Java 后端 — CategoriesService 分类域业务测试
 *
 * 覆盖目标(005-java-backend.md §5.3):
 *   - list:返回预设(user_id=NULL)+ 用户自定义,过滤 is_active=1
 *   - create happy path:用户自定义分类可建
 *   - create 5001:type 既不是 expense 也不是 income → 5001
 *   - create 5003:同 (user, type) 下 name 重复 → 5003
 *   - update 5002:试图改预设分类 → 5002 PRESET_LOCKED
 *   - update 5001:分类不存在 → 5001 NOT_FOUND
 *   - delete happy path:软删(is_active=0),不真删
 *
 * 工具:JUnit 5 + Mockito + AssertJ
 */
class CategoriesServiceTest {

    private CategoryMapper categoryMapper;
    private CategoriesService service;

    @BeforeEach
    void setUp() {
        categoryMapper = mock(CategoryMapper.class);
        service = new CategoriesService(categoryMapper);
        when(categoryMapper.insert(any(Category.class))).thenReturn(1);
        when(categoryMapper.updateById(any(Category.class))).thenReturn(1);
    }

    @Test
    @DisplayName("list — 返预设 + 用户自定义,过滤 is_active=1")
    void listActiveCategories() {
        Category preset = Category.builder()
            .id(1L).uuid(UUID.randomUUID().toString())
            .userId(null).type("expense").name("餐饮")
            .isPreset((byte) 1).isActive((byte) 1).sortOrder(1)
            .createdAt(Instant.now()).build();
        Category custom = Category.builder()
            .id(2L).uuid(UUID.randomUUID().toString())
            .userId(100L).type("expense").name("奶茶")
            .isPreset((byte) 0).isActive((byte) 1).sortOrder(0)
            .createdAt(Instant.now()).build();
        when(categoryMapper.selectList(any())).thenReturn(List.of(preset, custom));

        List<CategoryResponse> list = service.list(100L, "expense");

        assertThat(list).hasSize(2);
        assertThat(list.get(0).isPreset()).isTrue();
        assertThat(list.get(0).name()).isEqualTo("餐饮");
        assertThat(list.get(1).isPreset()).isFalse();
        assertThat(list.get(1).name()).isEqualTo("奶茶");
        assertThat(list.get(1).id()).isNotBlank();
    }

    @Test
    @DisplayName("create happy path — 自定义 expense 分类可建,isPreset=false")
    void createCustomCategory() {
        when(categoryMapper.selectCount(any())).thenReturn(0L);

        CreateCategoryRequest req = new CreateCategoryRequest(
            "expense", "咖啡", "☕", "#7B61FF", 0
        );
        CategoryResponse resp = service.create(100L, req);

        assertThat(resp).isNotNull();
        assertThat(resp.name()).isEqualTo("咖啡");
        assertThat(resp.type()).isEqualTo("expense");
        assertThat(resp.isPreset()).isFalse();
        assertThat(resp.icon()).isEqualTo("☕");
        assertThat(resp.color()).isEqualTo("#7B61FF");
        verify(categoryMapper, times(1)).insert(any(Category.class));
    }

    @Test
    @DisplayName("create — type='transfer'(非法)→ 抛 5001 CATEGORY_NOT_FOUND")
    void createInvalidType() {
        CreateCategoryRequest req = new CreateCategoryRequest(
            "transfer", "违规分类", "", "#000000", 0
        );
        assertThatThrownBy(() -> service.create(100L, req))
            .isInstanceOf(BizException.class)
            .satisfies(e -> assertThat(((BizException) e).getCode()).isEqualTo(5001));
        verify(categoryMapper, never()).insert(any(Category.class));
    }

    @Test
    @DisplayName("create — 同名同 type 已有 → 抛 5003 NAME_DUPLICATE")
    void createNameDuplicate() {
        when(categoryMapper.selectCount(any())).thenReturn(1L);

        CreateCategoryRequest req = new CreateCategoryRequest(
            "expense", "奶茶", "", "#7B61FF", 0
        );
        assertThatThrownBy(() -> service.create(100L, req))
            .isInstanceOf(BizException.class)
            .satisfies(e -> assertThat(((BizException) e).getCode()).isEqualTo(5003));
        verify(categoryMapper, never()).insert(any(Category.class));
    }

    @Test
    @DisplayName("update — 试图改预设分类 → 抛 5002 PRESET_LOCKED")
    void updatePresetLocked() {
        Category preset = Category.builder()
            .id(10L).uuid(UUID.randomUUID().toString())
            .userId(null).type("expense").name("餐饮")
            .isPreset((byte) 1).isActive((byte) 1).sortOrder(1)
            .createdAt(Instant.now()).build();
        when(categoryMapper.selectOne(any())).thenReturn(preset);

        UpdateCategoryRequest req = new UpdateCategoryRequest(
            "新餐饮", null, null, null, null
        );
        assertThatThrownBy(() -> service.update(100L, preset.getUuid(), req))
            .isInstanceOf(BizException.class)
            .satisfies(e -> assertThat(((BizException) e).getCode()).isEqualTo(5002));
        verify(categoryMapper, never()).updateById(any(Category.class));
    }

    @Test
    @DisplayName("update — 分类不存在 → 抛 5001")
    void updateNotFound() {
        when(categoryMapper.selectOne(any())).thenReturn(null);

        UpdateCategoryRequest req = new UpdateCategoryRequest(
            "改名", null, null, null, null
        );
        assertThatThrownBy(() -> service.update(100L, "ghost-uuid", req))
            .isInstanceOf(BizException.class)
            .satisfies(e -> assertThat(((BizException) e).getCode()).isEqualTo(5001));
    }

    @Test
    @DisplayName("update — 自定义分类 happy path → updateById 调用,name 改写")
    void updateCustomHappyPath() {
        Category custom = Category.builder()
            .id(20L).uuid(UUID.randomUUID().toString())
            .userId(100L).type("expense").name("旧名")
            .isPreset((byte) 0).isActive((byte) 1).sortOrder(0)
            .createdAt(Instant.now()).updatedAt(Instant.now()).build();
        when(categoryMapper.selectOne(any())).thenReturn(custom);
        when(categoryMapper.selectCount(any())).thenReturn(0L);

        UpdateCategoryRequest req = new UpdateCategoryRequest(
            "新名", "🍔", "#FF0000", null, 5
        );
        CategoryResponse resp = service.update(100L, custom.getUuid(), req);

        assertThat(resp).isNotNull();
        assertThat(resp.name()).isEqualTo("新名");
        assertThat(resp.icon()).isEqualTo("🍔");
        assertThat(resp.color()).isEqualTo("#FF0000");
        assertThat(resp.sortOrder()).isEqualTo(5);
        verify(categoryMapper, times(1)).updateById(any(Category.class));
    }

    @Test
    @DisplayName("delete — 自定义分类 → updateById 软删(is_active=0),不调 deleteById")
    void deleteSoftDelete() {
        Category custom = Category.builder()
            .id(30L).uuid(UUID.randomUUID().toString())
            .userId(100L).type("income").name("兼职")
            .isPreset((byte) 0).isActive((byte) 1).sortOrder(0)
            .createdAt(Instant.now()).build();
        when(categoryMapper.selectOne(any())).thenReturn(custom);

        service.delete(100L, custom.getUuid());

        verify(categoryMapper, times(1)).updateById(any(Category.class));
    }
}