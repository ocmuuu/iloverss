# 系统架构设计

## 架构概述

iloverss 采用分层架构设计，遵循单一职责原则和依赖倒置原则，确保系统的可维护性、可扩展性和可测试性。

## 整体架构

### 分层架构图

```
┌─────────────────────────────────────────────────────────────┐
│                    用户界面层 (UI Layer)                      │
├─────────────────────────────────────────────────────────────┤
│  Index.ets          RSSFeedList.ets    RSSArticleList.ets   │
│  RSSArticleDetail.ets  RSSFolderManager.ets                 │
├─────────────────────────────────────────────────────────────┤
│                    业务逻辑层 (Business Layer)                │
├─────────────────────────────────────────────────────────────┤
│  RSSService.ets     FeedDataService.ets  RSSRefreshService.ets │
│  OPMLService.ets    EntryAbility.ets                        │
├─────────────────────────────────────────────────────────────┤
│                    数据访问层 (Data Access Layer)             │
├─────────────────────────────────────────────────────────────┤
│  DatabaseManager.ets  ArticleDAO.ets    FeedDAO.ets         │
│  FolderDAO.ets      StatusDAO.ets      AuthorDAO.ets        │
├─────────────────────────────────────────────────────────────┤
│                    工具服务层 (Utility Layer)                 │
├─────────────────────────────────────────────────────────────┤
│  FeedParser.ets     FaviconDownloader.ets  PermissionUtils.ets │
│  PreferencesUtil.ets  Toast.ets         Log.ts              │
├─────────────────────────────────────────────────────────────┤
│                    数据存储层 (Storage Layer)                 │
├─────────────────────────────────────────────────────────────┤
│  RelationalStore    Preferences    File System              │
└─────────────────────────────────────────────────────────────┘
```

## 核心模块设计

### 1. 用户界面层 (UI Layer)

#### 职责
- 用户交互界面展示
- 用户输入处理
- 界面状态管理
- 响应式布局适配

#### 核心组件
- **Index.ets**: 主界面，三栏式布局容器
- **RSSFeedList.ets**: RSS源列表组件
- **RSSArticleList.ets**: 文章列表组件
- **RSSArticleDetail.ets**: 文章详情组件
- **RSSFolderManager.ets**: 文件夹管理组件

#### 设计原则
- 组件化设计，高内聚低耦合
- 响应式数据绑定
- 状态管理统一
- 界面与业务逻辑分离

### 2. 业务逻辑层 (Business Layer)

#### 职责
- 业务流程控制
- 数据转换和处理
- 业务规则实现
- 服务协调

#### 核心服务
- **RSSService.ets**: RSS源管理服务
- **FeedDataService.ets**: 数据同步服务
- **RSSRefreshService.ets**: 定时刷新服务
- **OPMLService.ets**: OPML导入导出服务
- **EntryAbility.ets**: 应用生命周期管理

#### 设计模式
- 服务模式 (Service Pattern)
- 单例模式 (Singleton Pattern)
- 观察者模式 (Observer Pattern)

### 3. 数据访问层 (Data Access Layer)

#### 职责
- 数据持久化
- 数据查询和操作
- 数据一致性保证
- 事务管理

#### 核心组件
- **DatabaseManager.ets**: 数据库管理器
- **ArticleDAO.ets**: 文章数据访问对象
- **FeedDAO.ets**: RSS源数据访问对象
- **FolderDAO.ets**: 文件夹数据访问对象
- **StatusDAO.ets**: 状态数据访问对象
- **AuthorDAO.ets**: 作者数据访问对象

#### 设计模式
- DAO模式 (Data Access Object Pattern)
- 工厂模式 (Factory Pattern)
- 策略模式 (Strategy Pattern)

### 4. 工具服务层 (Utility Layer)

#### 职责
- 通用工具功能
- 第三方服务集成
- 系统服务封装
- 错误处理和日志

#### 核心组件
- **FeedParser.ets**: RSS解析引擎
- **FaviconDownloader.ets**: 图标下载服务
- **PermissionUtils.ets**: 权限管理工具
- **PreferencesUtil.ets**: 偏好设置工具
- **Toast.ets**: 消息提示工具
- **Log.ts**: 日志工具

## 数据流设计

### 数据流程图

```
用户操作 → UI组件 → 业务服务 → 数据访问层 → 数据库
    ↓         ↓         ↓          ↓         ↓
  响应更新 ← 状态更新 ← 数据处理 ← 查询结果 ← 持久化
```

### 核心数据流

#### 1. RSS源添加流程
```
用户输入URL → RSSService → FeedParser → FeedDAO → 数据库
    ↓           ↓           ↓          ↓        ↓
  界面更新 ← 解析结果 ← 格式验证 ← 数据保存 ← 事务提交
```

#### 2. 文章同步流程
```
定时触发 → RSSRefreshService → RSSService → FeedParser → ArticleDAO
   ↓           ↓               ↓           ↓          ↓
界面更新 ← 同步完成 ← 数据更新 ← 解析结果 ← 数据保存
```

#### 3. 搜索流程
```
用户搜索 → UI组件 → FeedDataService → ArticleDAO → 数据库查询
   ↓         ↓          ↓            ↓          ↓
结果展示 ← 数据转换 ← 搜索结果 ← 模糊查询 ← 索引搜索
```

## 接口设计

### 服务接口

#### RSSService 接口
```typescript
interface RSSService {
  addFeed(url: string): Promise<Feed>
  removeFeed(feedId: number): Promise<void>
  refreshFeed(feedId: number): Promise<void>
  refreshAllFeeds(): Promise<void>
  getFeeds(): Promise<Feed[]>
}
```

#### FeedDataService 接口
```typescript
interface FeedDataService {
  getArticles(feedId?: number): Promise<Article[]>
  getUnreadArticles(): Promise<Article[]>
  markAsRead(articleId: number): Promise<void>
  markAllAsRead(feedId?: number): Promise<void>
  toggleFavorite(articleId: number): Promise<void>
  searchArticles(query: string): Promise<Article[]>
}
```

#### OPMLService 接口
```typescript
interface OPMLService {
  exportOPML(): Promise<string>
  importOPML(opmlContent: string): Promise<void>
}
```

## 错误处理设计

### 错误分类
1. **网络错误**: 连接失败、超时、服务器错误
2. **解析错误**: RSS格式错误、XML解析失败
3. **数据库错误**: 连接失败、事务失败
4. **权限错误**: 网络权限、存储权限
5. **业务错误**: 数据验证失败、业务规则冲突

### 错误处理策略
- **重试机制**: 网络请求失败自动重试
- **降级处理**: 解析失败时提供基础信息
- **用户提示**: 友好的错误信息展示
- **日志记录**: 详细错误日志便于调试

## 性能优化设计

### 缓存策略
- **内存缓存**: 热点数据内存缓存
- **数据库缓存**: 文章内容本地存储
- **图标缓存**: 网站图标本地缓存

### 并发控制
- **RSS同步**: 最多3个并发请求
- **数据库操作**: 异步操作避免阻塞
- **UI更新**: 批量更新减少重绘

### 资源管理
- **内存管理**: 及时释放不需要的资源
- **网络优化**: 请求合并、压缩传输
- **存储优化**: 定期清理过期数据

## 安全设计

### 数据安全
- **本地存储**: 敏感数据本地加密存储
- **网络传输**: HTTPS协议保证传输安全
- **权限控制**: 最小权限原则

### 输入验证
- **URL验证**: RSS源URL格式验证
- **数据验证**: 输入数据格式和范围验证
- **SQL注入防护**: 参数化查询

## 扩展性设计

### 模块化设计
- **插件化架构**: 支持功能模块扩展
- **配置驱动**: 通过配置文件控制功能
- **接口标准化**: 统一的接口规范

### 版本兼容
- **向后兼容**: 新版本兼容旧数据
- **数据迁移**: 自动数据格式升级
- **API版本**: 支持多版本API

## 部署架构

### 单机部署
- **本地数据库**: RelationalStore本地存储
- **本地缓存**: 文件系统缓存
- **独立运行**: 无需外部服务依赖

### 配置管理
- **环境配置**: 开发、测试、生产环境配置
- **用户配置**: 个性化设置持久化
- **系统配置**: 应用级配置管理 