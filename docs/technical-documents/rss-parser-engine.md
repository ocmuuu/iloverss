# RSS 解析引擎

## 设计目标
- 支持多种RSS/Feed格式
- 自动类型检测与容错
- 高性能解析与内容清理

## 架构
- 统一解析接口（FeedParser）
- 多种解析器模块（AtomParser、RSSParser、JSONFeedParser、RSSInJSONParser）
- 错误处理与降级机制

## 主要流程
1. 检测Feed类型
2. 选择解析器
3. 解析基础信息与文章列表
4. 内容清理与安全处理
5. 返回标准化数据结构

## 关键技术
- XML/JSON解析
- HTML标签过滤
- 错误日志与重试 