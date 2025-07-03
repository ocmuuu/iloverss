# 数据库设计

## 数据库概述

iloverss 采用 HarmonyOS 的 RelationalStore 关系型数据库，设计遵循第三范式，确保数据完整性和一致性。

## 数据库架构

### 数据库配置
- **数据库名称**: iloverss.db
- **版本**: 1.0
- **字符集**: UTF-8
- **存储位置**: 应用沙盒目录

## 表结构设计

### 1. feeds 表 (RSS订阅源)

```sql
CREATE TABLE feeds (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,                    -- RSS源标题
    url TEXT UNIQUE NOT NULL,               -- RSS源URL
    description TEXT,                       -- RSS源描述
    icon_url TEXT,                          -- 图标URL
    last_updated INTEGER,                   -- 最后更新时间
    folder_id INTEGER,                      -- 所属文件夹ID
    is_active INTEGER DEFAULT 1,            -- 是否激活
    created_at INTEGER DEFAULT (strftime('%s', 'now')),
    updated_at INTEGER DEFAULT (strftime('%s', 'now')),
    FOREIGN KEY (folder_id) REFERENCES folders(id) ON DELETE SET NULL
);
```

**索引设计**:
- `idx_feeds_url`: URL唯一索引
- `idx_feeds_folder_id`: 文件夹ID索引
- `idx_feeds_last_updated`: 更新时间索引

### 2. folders 表 (文件夹)

```sql
CREATE TABLE folders (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,                     -- 文件夹名称
    sort_order INTEGER DEFAULT 0,           -- 排序顺序
    created_at INTEGER DEFAULT (strftime('%s', 'now')),
    updated_at INTEGER DEFAULT (strftime('%s', 'now'))
);
```

**索引设计**:
- `idx_folders_name`: 文件夹名称索引
- `idx_folders_sort_order`: 排序索引

### 3. articles 表 (文章)

```sql
CREATE TABLE articles (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    feed_id INTEGER NOT NULL,               -- 所属RSS源ID
    title TEXT NOT NULL,                    -- 文章标题
    link TEXT,                              -- 文章链接
    description TEXT,                       -- 文章描述/摘要
    content TEXT,                           -- 文章内容
    author_id INTEGER,                      -- 作者ID
    published_at INTEGER,                   -- 发布时间
    guid TEXT,                              -- 文章唯一标识
    created_at INTEGER DEFAULT (strftime('%s', 'now')),
    updated_at INTEGER DEFAULT (strftime('%s', 'now')),
    FOREIGN KEY (feed_id) REFERENCES feeds(id) ON DELETE CASCADE,
    FOREIGN KEY (author_id) REFERENCES authors(id) ON DELETE SET NULL
);
```

**索引设计**:
- `idx_articles_feed_id`: RSS源ID索引
- `idx_articles_published_at`: 发布时间索引
- `idx_articles_guid`: GUID唯一索引
- `idx_articles_title`: 标题索引

### 4. statuses 表 (文章状态)

```sql
CREATE TABLE statuses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    article_id INTEGER NOT NULL,            -- 文章ID
    is_read INTEGER DEFAULT 0,              -- 是否已读
    is_favorite INTEGER DEFAULT 0,          -- 是否收藏
    read_at INTEGER,                        -- 阅读时间
    created_at INTEGER DEFAULT (strftime('%s', 'now')),
    updated_at INTEGER DEFAULT (strftime('%s', 'now')),
    FOREIGN KEY (article_id) REFERENCES articles(id) ON DELETE CASCADE,
    UNIQUE(article_id)
);
```

**索引设计**:
- `idx_statuses_article_id`: 文章ID唯一索引
- `idx_statuses_is_read`: 已读状态索引
- `idx_statuses_is_favorite`: 收藏状态索引

### 5. authors 表 (作者)

```sql
CREATE TABLE authors (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,                     -- 作者姓名
    email TEXT,                             -- 作者邮箱
    uri TEXT,                               -- 作者网站
    created_at INTEGER DEFAULT (strftime('%s', 'now')),
    updated_at INTEGER DEFAULT (strftime('%s', 'now'))
);
```

**索引设计**:
- `idx_authors_name`: 作者姓名索引
- `idx_authors_email`: 邮箱索引

### 6. search 表 (搜索索引)

```sql
CREATE TABLE search (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    article_id INTEGER NOT NULL,            -- 文章ID
    title TEXT,                             -- 标题搜索索引
    content TEXT,                           -- 内容搜索索引
    description TEXT,                       -- 描述搜索索引
    created_at INTEGER DEFAULT (strftime('%s', 'now')),
    FOREIGN KEY (article_id) REFERENCES articles(id) ON DELETE CASCADE
);
```

**索引设计**:
- `idx_search_article_id`: 文章ID索引
- `idx_search_title`: 标题全文索引
- `idx_search_content`: 内容全文索引

## 关系设计

### 实体关系图

```
folders (1) ←→ (N) feeds (1) ←→ (N) articles (1) ←→ (1) statuses
                                    ↓
                              authors (1) ←→ (N) articles
                                    ↓
                              search (1) ←→ (1) articles
```

### 外键约束

1. **feeds.folder_id → folders.id**
   - 删除文件夹时，RSS源设为NULL
   - 更新时级联更新

2. **articles.feed_id → feeds.id**
   - 删除RSS源时，级联删除所有文章
   - 确保数据一致性

3. **articles.author_id → authors.id**
   - 删除作者时，文章作者设为NULL
   - 保留文章内容

4. **statuses.article_id → articles.id**
   - 删除文章时，级联删除状态
   - 一对一关系

5. **search.article_id → articles.id**
   - 删除文章时，级联删除搜索索引
   - 一对一关系

## 数据完整性

### 约束设计

1. **非空约束**
   - feeds.title, feeds.url
   - folders.name
   - articles.title, articles.feed_id
   - statuses.article_id

2. **唯一约束**
   - feeds.url (RSS源URL唯一)
   - articles.guid (文章GUID唯一)
   - statuses.article_id (每篇文章只有一个状态)

3. **检查约束**
   - is_read, is_favorite: 0或1
   - is_active: 0或1

### 触发器设计

1. **更新时间触发器**
```sql
CREATE TRIGGER update_feeds_timestamp 
AFTER UPDATE ON feeds
BEGIN
    UPDATE feeds SET updated_at = strftime('%s', 'now') WHERE id = NEW.id;
END;
```

2. **搜索索引触发器**
```sql
CREATE TRIGGER update_search_index
AFTER INSERT OR UPDATE ON articles
BEGIN
    INSERT OR REPLACE INTO search (article_id, title, content, description)
    VALUES (NEW.id, NEW.title, NEW.content, NEW.description);
END;
```

## 性能优化

### 索引策略

1. **主键索引**: 所有表的主键自动索引
2. **外键索引**: 所有外键字段建立索引
3. **查询索引**: 常用查询字段建立索引
4. **全文索引**: 搜索字段建立全文索引

### 查询优化

1. **JOIN优化**: 使用INNER JOIN减少数据量
2. **WHERE优化**: 优先使用索引字段过滤
3. **ORDER BY优化**: 使用索引字段排序
4. **LIMIT优化**: 分页查询使用LIMIT

### 数据清理

1. **过期数据清理**: 定期清理30天前的文章
2. **重复数据清理**: 基于GUID去重
3. **索引重建**: 定期重建索引优化性能

## 数据迁移

### 版本管理

1. **版本号**: 数据库版本号管理
2. **迁移脚本**: 版本升级脚本
3. **回滚机制**: 升级失败回滚机制

### 迁移策略

1. **增量迁移**: 只迁移变更的表结构
2. **数据备份**: 迁移前自动备份
3. **事务保证**: 迁移过程事务保证

## 备份恢复

### 备份策略

1. **自动备份**: 应用启动时自动备份
2. **手动备份**: 用户手动触发备份
3. **增量备份**: 只备份变更数据

### 恢复机制

1. **自动恢复**: 数据库损坏时自动恢复
2. **手动恢复**: 用户选择备份文件恢复
3. **数据验证**: 恢复后数据完整性验证 