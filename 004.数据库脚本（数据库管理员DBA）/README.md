# 轻账 (QingZhang) 数据库脚本

> 配套文档：[001.产品PRD/轻账-产品需求文档PRD.md](../001.产品PRD/轻账-产品需求文档PRD.md)（V1.0 基线）
> 增量文档：[001.产品PRD/轻账-产品需求文档PRD-V1.0.1.md](../001.产品PRD/轻账-产品需求文档PRD-V1.0.1.md)（用户认证）
> 前端实现：[003.前端代码/frontend](../003.前端代码/frontend)（Dexie v2 / IndexedDB）

---

## 一、目录结构

```
004.数据库脚本/
├── README.md                  # 本文档
├── 00_mysql_config.cnf        # MySQL 字符集 + 时区配置（解决乱码/时间漂移）
├── 01_schema_qingzhang.sql    # 表结构（DDL）
└── 02_seed_qingzhang.sql      # 初始化数据（DML）
```

---

## 二、技术选型

| 维度 | 选型 | 说明 |
|------|------|------|
| 数据库 | **MySQL 9.7.2** | 主流、稳定；与前端 IndexedDB 字段可一一对应 |
| 字符集 | `utf8mb4 / utf8mb4_unicode_ci` | 支持 emoji、汉字、表情符号 |
| 时间精度 | `DATETIME(3)` | 毫秒级，与前端 `Date.now()` 对齐 |
| 金额类型 | `DECIMAL(12,2)` / `DECIMAL(14,2)` | 避免浮点误差 |
| 迁移工具（建议） | Flyway / Liquibase | V1.1 / V2.0 版本升级时使用 |

---

## 三、表清单（10 张）

| # | 表名 | 中文 | V1.0 | V1.0.1 | V1.1 预留 | V2.0 预留 |
|---|------|------|:----:|:------:|:---------:|:---------:|
| 1 | `users` | 用户表 |  | ✅ |  |  |
| 2 | `books` | 账本表 |  |  | ✅ |  |
| 3 | `book_members` | 账本成员表 |  |  | ✅ |  |
| 4 | `categories` | 分类表 |  |  | ✅ |  |
| 5 | `accounts` | 账户表 |  |  | ✅ |  |
| 6 | `records` | 账目流水表 | ✅ | ✅ | ✅ |  |
| 7 | `record_attachments` | 附件表 |  |  | ✅ |  |
| 8 | `budgets` | 预算表 |  |  |  | ✅ |
| 9 | `export_logs` | 导出日志表 |  | ✅ |  |  |
| 10 | `operation_logs` | 操作日志表 |  | ✅ |  |  |

### 视图

| 视图 | 用途 |
|------|------|
| `v_account_balance` | 账户余额（收入-支出+转入-转出），替代前端实时聚合 |
| `v_monthly_summary` | 月度收支总览，对应 PRD 报表页"月度总览卡片" |

---

## 四、实体关系图（ERD）

```
                              ┌─────────────────────┐
                              │       users         │  V1.0.1 新增
                              │  PK id / UUID uuid  │
                              │  username UNIQUE    │
                              └──────────┬──────────┘
                                         │ 1:N
                                         ▼
        ┌─────────────────────────────────────────────────────┐
        │                       books                          │  V1.1 共享账本
        │  PK id  FK owner_id→users                            │
        │  type: personal / shared / business                  │
        └────────┬────────────────────────────┬────────────────┘
                 │ 1:N                        │ 1:N
                 ▼                            ▼
        ┌──────────────────┐         ┌──────────────────┐
        │   categories      │         │    accounts      │
        │  PK id           │         │  PK id           │
        │  type enum       │         │  type enum       │
        │  is_preset bool  │         │  initial_balance │
        │  user_id NULL    │         │  current_balance │
        │  表示预设分类     │         │  is_default bool │
        └────────┬─────────┘         └─────────┬─────────┘
                 │ N:1                       │ 1:N
                 │  (账目引用分类)            │  (账目引用账户)
                 │                           │
                 ▼                           ▼
        ┌──────────────────────────────────────────────────────┐
        │                       records                         │  核心流水表
        │  PK id  UUID  user_id  book_id                       │
        │  type enum(expense/income/transfer)                   │
        │  category_id  account_id  to_account_id               │
        │  amount DECIMAL(12,2)  note  record_date             │
        │  source enum  client_id (云同步去重)                  │
        └────────────────────────┬─────────────────────────────┘
                                 │ 1:N
                                 ▼
                    ┌──────────────────────┐
                    │ record_attachments   │  V1.1 OCR 拍照
                    │  PK id  record_id    │
                    │  file_url  ocr_raw   │
                    └──────────────────────┘
```

### 关键约束

- `users.username` **唯一索引**：注册时不可重复（对齐 PRD V1.0.1 §3.2）
- `records.client_id` **(user_id, client_id) 唯一**：云同步幂等性
- `accounts` 删除前置检查：若 `records.account_id` 仍存在记录，禁止删除（对齐 PRD V1.0 §4.1 "删除账户时若有关联账目则提示"）
- `records.amount > 0`：CHECK 约束，杜绝脏数据
- 所有业务表 `deleted_at IS NULL` 软删除过滤，配合 V1.1 云同步与审计

---

## 五、与前端 IndexedDB（Dexie v2）的字段映射

> 前端使用 Dexie/IndexedDB 存储，本脚本设计的 MySQL 表结构是对其关系化升级，两者字段一一对应。

| Dexie v2 索引 / 字段 | MySQL 字段 | 备注 |
|----------------------|-----------|------|
| `records: id, type, categoryId, accountId, recordDate, createdAt` | `records: PK uuid, idx(type, category_id, account_id, record_date, created_at)` | 索引策略一致 |
| `accounts: id, isDefault, sortOrder` | `accounts: PK uuid, idx(user_id, is_default, sort_order)` | 增加 user_id 维度 |
| `categories: id, type, sortOrder` | `categories: PK uuid, idx(user_id, type, sort_order)` | 增加 user_id 维度 |
| `users: id, username` | `users: PK uuid, UNIQUE(username)` | 一致 |
| `Record.amount: number` | `records.amount: DECIMAL(12,2)` | 类型升级避免浮点 |
| `Account.balance: number` | `accounts.current_balance + v_account_balance` | 后端可由视图实时计算 |
| `User.passwordHash: string` | `users.password_hash: VARCHAR(128)` | 同 SHA-256 + salt |
| `User.salt: string` | `users.salt: VARCHAR(64)` | 同 16 字节 base64 |

---

## 六、执行方式

### 6.1 命令行

```bash
# 1. 创建数据库
mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS qingzhang DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# 2. （Docker 部署必须）应用字符集与时区配置
docker cp 00_mysql_config.cnf mysql97:/etc/mysql/conf.d/99-qingzhang.cnf
docker restart mysql97

# 3. 切换数据库
mysql -u root -p qingzhang < 01_schema_qingzhang.sql

# 4. （可选）导入初始化数据
mysql -u root -p qingzhang < 02_seed_qingzhang.sql
```

### 6.2 Flyway / Liquibase（推荐生产）

```
db/migration/
├── V1__create_users.sql            -- 拆自 01_schema_qingzhang.sql
├── V1__create_books.sql
├── ...
├── V2__add_user_to_categories.sql   -- V1.0.1 增量
└── V3__add_budgets.sql             -- V2.0 增量
```

---

## 七、版本演进

| 数据库版本 | 内容 | 对应产品版本 |
|-----------|------|-------------|
| V1 | users / books / book_members / categories / accounts / records / record_attachments / budgets / export_logs / operation_logs | V1.0 ~ V1.0.1 |
| V2（预留） | 拆分 records（按月分区）/ 添加 budgets 完整字段 / 添加 ai_insights | V2.0 智能版 |

### V1.0 → V1.0.1 迁移要点

- 老用户首次进入应用时，V1.0.1 自动为该设备生成一个默认 user 记录（id=0 demo 或首次注册用户），记账数据 `user_id` 自动回填
- 若需要历史数据归属到指定用户，运行：

```sql
UPDATE records r
JOIN users u ON u.username = ?
SET r.user_id = u.id
WHERE r.user_id IS NULL;
```

### V1.0 → V1.1 迁移要点

- `books.is_default` 已有默认账本
- `book_members` 写入 owner 自身作为 admin
- 前端 store 增加 `currentBookId`，UI 增加账本切换器

---

## 八、安全建议

1. **密码哈希**：生产请使用 `bcrypt / argon2` 替代 SHA-256+salt（V1.0.1 已注明，纯前端场景可接受）
2. **软删除**：所有业务表 `deleted_at` 字段必须应用层过滤
4. **索引**：高频查询已建复合索引，月度统计建议 `idx_records_user_type_date`
5. **金额**：禁止浮点直接参与计算，统一使用 `DECIMAL`
6. **审计**：`operation_logs` 记录关键写操作，便于追溯
7. **数据导出**：按月/分类/全量导出走 `export_logs` 流水，避免漏审计

---

## 八.一、字符集与时区配置（Docker / 自托管 MySQL 必读）

> 常见坑：Docker 镜像默认 `character_set_client=latin1` 与 `time_zone=SYSTEM(UTC)`，
> 导致中文乱码、时间与北京时间相差 8 小时。生产部署前请先应用 [00_mysql_config.cnf](./00_mysql_config.cnf)。

### 1. 应用配置到现有容器

```bash
docker cp 00_mysql_config.cnf mysql97:/etc/mysql/conf.d/99-qingzhang.cnf
docker exec mysql97 mysql -uroot -p123456 -e "SET GLOBAL init_connect='SET NAMES utf8mb4';"
docker restart mysql97
```

### 2. 验证

```sql
SHOW VARIABLES LIKE 'character_set_client';   -- 应为 utf8mb4
SHOW VARIABLES LIKE 'character_set_results';  -- 应为 utf8mb4
SHOW VARIABLES LIKE 'time_zone';              -- 应为 Asia/Shanghai
SELECT NOW(), UTC_TIMESTAMP();                -- 两者差 8 小时
```

### 3. Navicat 客户端设置

如不修改服务端配置，仅需让 Navicat 显示正确：

- 连接 → 选中 `mysql97` → 右键 **连接属性** → **高级** 选项卡 → **编码**：`utf8mb4`
- 测试连接 → 确认中文显示正常

---

## 九、常用查询示例

### 9.1 月度收支总览（首页卡片）

```sql
SELECT * FROM v_monthly_summary
WHERE user_id = ? AND book_id = ?
  AND `month` = DATE_FORMAT(NOW(), '%Y-%m');
```

### 9.2 当月分类排名

```sql
SELECT
  c.name         AS category_name,
  c.icon,
  c.color,
  SUM(r.amount)  AS total,
  COUNT(*)       AS cnt
FROM records r
JOIN categories c ON c.id = r.category_id
WHERE r.user_id = ?
  AND r.type = 'expense'
  AND r.deleted_at IS NULL
  AND DATE_FORMAT(r.record_date, '%Y-%m') = ?
GROUP BY c.id
ORDER BY total DESC;
```

### 9.3 账户余额

```sql
SELECT * FROM v_account_balance
WHERE user_id = ? AND is_archived = 0
ORDER BY is_default DESC, sort_order ASC;
```

### 9.4 当日流水

```sql
SELECT r.*, c.name AS category_name, c.icon, c.color, a.name AS account_name
FROM records r
LEFT JOIN categories c ON c.id = r.category_id
JOIN accounts a       ON a.id = r.account_id
WHERE r.user_id = ?
  AND r.record_date = ?
  AND r.deleted_at IS NULL
ORDER BY r.created_at DESC;
```

### 9.5 月度趋势（近 6 月折线图数据）

```sql
SELECT
  DATE_FORMAT(record_date, '%Y-%m') AS month,
  SUM(CASE WHEN type='expense' THEN amount ELSE 0 END) AS expense,
  SUM(CASE WHEN type='income'  THEN amount ELSE 0 END) AS income
FROM records
WHERE user_id = ?
  AND deleted_at IS NULL
  AND record_date >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
GROUP BY DATE_FORMAT(record_date, '%Y-%m')
ORDER BY month;
```

---

## 十、变更记录

| 日期 | 版本 | 变更 | 作者 |
|------|------|------|------|
| 2026-08-26 | V1 | 初始化：基于 V1.0 PRD 与 V1.0.1 用户认证增量，建立 10 张表 + 2 个视图 | 工程团队 |