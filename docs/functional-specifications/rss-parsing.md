# RSS 解析功能规格

## 支持格式
- RSS 2.0
- Atom 1.0
- JSON Feed
- RSS in JSON

## 解析流程
1. 自动检测Feed类型
2. 选择对应解析器（AtomParser、RSSParser、JSONFeedParser、RSSInJSONParser）
3. 解析基础信息（标题、描述、链接、更新时间等）
4. 解析文章列表及详情（标题、内容、作者、发布时间、附件等）
5. 错误容错处理，解析失败时降级展示

## 解析器模块
- AtomParser：解析Atom 1.0格式
- RSSParser：解析RSS 2.0格式
- JSONFeedParser：解析JSON Feed格式
- RSSInJSONParser：解析RSS in JSON格式

## 容错与安全
- HTML标签过滤，内容安全处理
- 解析失败自动重试，错误日志记录
- 支持内容清理和格式规范化 