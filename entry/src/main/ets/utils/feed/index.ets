/**
 * Feed解析器模块统一导出
 * RSS/Atom/JSON Feed解析器
 */

// 基础类型和枚举
export { FeedType, FeedTypeDetector, MIN_CONTENT_LENGTH } from './FeedType'

// 数据结构
export { ParsedAuthor, AuthorUtils } from './ParsedAuthor'
export { ParsedAttachment, AttachmentUtils, AttachmentType } from './ParsedAttachment'
export { ParsedHub, HubUtils, HubTypes, HubType } from './ParsedHub'
export { ParsedFeed, FeedUtils, FeedSummary, FeedStatistics } from './ParsedFeed'
export { ParsedItem, ItemUtils, ItemSummary, ItemFilters, ItemStatistics } from './ParsedItem'

// 错误处理
export { 
  FeedParserError, 
  FeedParserErrorType, 
  ErrorLevel, 
  ErrorUtils 
} from './FeedParserError'

// 解析器数据
export { 
  ParserData, 
  ParserDataUtils, 
  ValidationResult, 
  DataSizeInfo, 
  DataSnapshot 
} from './ParserData'

// 主解析器
export { FeedParser, FeedParserCallback } from './FeedParser'

// JSON格式解析器
export { JSONFeedParser } from './json/JSONFeedParser'
export { RSSInJSONParser } from './json/RSSInJSONParser'

// XML格式解析器
export { RSSParser, RSParsedFeed, RSParsedArticle, RSParsedAuthor, RSParsedEnclosure } from './xml/RSSParser'
export { AtomParser } from './xml/AtomParser'
export { RSParsedFeedTransformer } from './xml/RSParsedFeedTransformer'
export { XMLParser, Element, Document } from './xml/XMLParser'

// 向后兼容的类型别名
export type ParsedArticle = ParsedItem
export type RSSParseResult = {
  feed: ParsedFeed
  articles: ParsedItem[]
}

/**
 * 模块信息
 */
export const ModuleInfo = {
  name: 'RSS Feed Parser',
  version: '2.0.0',
  description: 'RSS/Atom/JSON Feed解析器',
  modules: [
    'FeedType - Feed类型检测',
    'ParsedAuthor - 作者信息处理',
    'ParsedAttachment - 附件信息处理',
    'ParsedHub - Hub信息处理',
    'ParsedFeed - Feed信息处理',
    'ParsedItem - 文章信息处理',
    'FeedParserError - 错误处理',
    'ParserData - 数据包装',
    'FeedParser - 主解析器',
    'JSONFeedParser - JSON Feed解析',
    'RSSInJSONParser - RSS in JSON解析',
    'RSSParser - RSS XML解析',
    'AtomParser - Atom XML解析',
    'XMLParser - 基础XML解析工具'
  ],
  architecture: 'RSS/Atom/JSON Compatible',
  formats: ['RSS 2.0', 'Atom 1.0', 'JSON Feed 1.1', 'RSS in JSON']
}

export default {
  // 核心类型
  FeedType,
  FeedTypeDetector,
  
  // 数据结构
  ParsedAuthor,
  AuthorUtils,
  ParsedAttachment,
  AttachmentUtils,
  ParsedHub,
  HubUtils,
  ParsedFeed,
  FeedUtils,
  ParsedItem,
  ItemUtils,
  
  // 错误和数据
  FeedParserError,
  FeedParserErrorType,
  ErrorUtils,
  ParserData,
  ParserDataUtils,
  
  // 解析器
  FeedParser,
  JSONFeedParser,
  RSSInJSONParser,
  RSSParser,
  AtomParser,
  RSParsedFeedTransformer,
  XMLParser,
  
  // 模块信息
  ModuleInfo
} 