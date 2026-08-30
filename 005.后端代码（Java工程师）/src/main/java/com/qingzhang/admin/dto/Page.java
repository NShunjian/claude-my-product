package com.qingzhang.admin.dto;

import java.util.List;

/**
 * 分页结果信封,前端 src/api/types.ts 的 Page&lt;T&gt; 接口一一对应:
 *   { "records": [...], "total": 100, "size": 20, "current": 1 }
 *
 * ponytail: 沿用 MyBatis-Plus IPage 字段名 (records/total/size/current),但不复用
 * IPage —— admin 子系统不依赖 mybatis-plus 的分页对象,DTO 层零 mybatis-plus 耦合。
 */
public record Page<T>(List<T> records, long total, long size, long current) {}
