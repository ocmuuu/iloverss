import hilog from '@ohos.hilog'
import { FeedType, FeedTypeDetector, FeedVersionInfo } from './FeedType'
import { ParsedFeed } from './ParsedFeed'
import { FeedParserError, FeedParserErrorType } from './FeedParserError'
import { ParserData } from './ParserData'
import { JSONFeedParser } from './json/JSONFeedParser'
import { RSSInJSONParser } from './json/RSSInJSONParser'
import { RSSParser } from './xml/RSSParser'
import { AtomParser } from './xml/AtomParser'
import { XMLParser } from './xml/XMLParser'
import { RSParsedFeedTransformer } from './xml/RSParsedFeedTransformer'

/**
 * Feed解析器回调函数类型
 */
export type FeedParserCallback = (parsedFeed: ParsedFeed | null, error: Error | null) => void

/**
 * 预解析结果
 */
export interface PreparseResult {
  feedType: FeedType
  version: string
  namespace?: string
  title: string
  description: string
  isValid: boolean
  error?: string
}

/**
 * 解析尝试接口
 */
interface ParseAttempt {
  type: FeedType
  parser: () => Promise<ParsedFeed>
}

/**
 * Feed解析器工厂
 * 统一的Feed解析入口，支持RSS、Atom、JSON Feed和RSS in JSON
 */
export class FeedParser {
  
  /**
   * 检查是否可以解析给定的数据
   */
  static canParse(parserData: ParserData): boolean {
    const feedType = FeedTypeDetector.detectFeedType(parserData.data)
    
    switch (feedType) {
      case FeedType.JSONFeed:
      case FeedType.RSSInJSON:
        return true
      case FeedType.RSS:
      case FeedType.Atom:
        return XMLParser.canParse(parserData.data)
      default:
        return false
    }
  }
  
  /**
   * 解析Feed数据
   */
  static async parse(parserData: ParserData): Promise<ParsedFeed> {
    const feedType = FeedTypeDetector.detectFeedType(parserData.data)
    
    switch (feedType) {
      case FeedType.JSONFeed:
      case FeedType.RSSInJSON:
        return FeedParser.parseJSONFeed(parserData, feedType)
      case FeedType.RSS:
        return FeedParser.parseRSSFeed(parserData)
      case FeedType.Atom:
        return FeedParser.parseAtomFeed(parserData)
      case FeedType.Unknown:
      default:
        throw new FeedParserError(
          FeedParserErrorType.UNSUPPORTED_FORMAT,
          '不支持的Feed格式或无法确定Feed类型',
          parserData.url
        )
    }
  }
  
  /**
   * 解析JSON Feed
   */
  private static async parseJSONFeed(parserData: ParserData, feedType: FeedType): Promise<ParsedFeed> {
    try {
      if (feedType === FeedType.JSONFeed) {
        return JSONFeedParser.parse(parserData)
      } else if (feedType === FeedType.RSSInJSON) {
        return RSSInJSONParser.parse(parserData)
      } else {
        throw new Error('不支持的JSON Feed类型')
      }
    } catch (error) {
      if (error instanceof FeedParserError) {
        throw error
      }
      throw new FeedParserError(
        FeedParserErrorType.PARSE_ERROR,
        `JSON解析失败: ${error instanceof Error ? error.message : '未知错误'}`,
        parserData.url
      )
    }
  }
  
  /**
   * 解析RSS Feed
   */
  private static async parseRSSFeed(parserData: ParserData): Promise<ParsedFeed> {
    try {
      const parsedData = RSSParser.parse(parserData)
      if (!parsedData) {
        throw new Error('RSS解析失败')
      }
      return parsedData
    } catch (error) {
      throw new FeedParserError(
        FeedParserErrorType.PARSE_ERROR,
        `RSS解析失败: ${error instanceof Error ? error.message : '未知错误'}`,
        parserData.url
      )
    }
  }
  
  /**
   * 解析Atom Feed
   */
  private static async parseAtomFeed(parserData: ParserData): Promise<ParsedFeed> {
    try {
      const parsedData = AtomParser.parse(parserData)
      if (!parsedData) {
        throw new Error('Atom解析失败')
      }
      return parsedData
    } catch (error) {
      throw new FeedParserError(
        FeedParserErrorType.PARSE_ERROR,
        `Atom解析失败: ${error instanceof Error ? error.message : '未知错误'}`,
        parserData.url
      )
    }
  }
  
  /**
   * 获取Feed类型
   */
  static getFeedType(parserData: ParserData): FeedType {
    return FeedTypeDetector.detectFeedType(parserData.data)
  }
  
  /**
   * 获取Feed版本信息
   */
  static getFeedVersionInfo(parserData: ParserData): FeedVersionInfo {
    return FeedTypeDetector.getFeedVersionInfo(parserData.data)
  }
  
  /**
   * 检查是否为有效的Feed
   */
  static isValidFeed(parserData: ParserData): boolean {
    const feedType = FeedTypeDetector.detectFeedType(parserData.data)
    return feedType !== FeedType.Unknown
  }
  
  /**
   * 按优先级尝试解析Feed
   */
  static async tryParseWithPriority(parserData: ParserData): Promise<ParsedFeed> {
    // 先尝试检测类型
    const feedType = FeedTypeDetector.detectFeedType(parserData.data)
    
    // 如果能检测到明确类型，直接使用对应解析器
    if (feedType !== FeedType.Unknown) {
      return FeedParser.parse(parserData)
    }
    
    // 如果无法检测类型，按优先级尝试不同解析器
    const parseAttempts: ParseAttempt[] = [
      { type: FeedType.Atom, parser: () => FeedParser.parseAtomFeed(parserData) },
      { type: FeedType.JSONFeed, parser: () => FeedParser.parseJSONFeed(parserData, FeedType.JSONFeed) },
      { type: FeedType.RSSInJSON, parser: () => FeedParser.parseJSONFeed(parserData, FeedType.RSSInJSON) },
      { type: FeedType.RSS, parser: () => FeedParser.parseRSSFeed(parserData) }
    ]

    let lastError: Error | null = null

    for (const attempt of parseAttempts) {
      try {
        return await attempt.parser()
      } catch (error) {
        lastError = error instanceof Error ? error : new Error(String(error))
      }
    }

    // 所有解析尝试都失败
    throw new FeedParserError(
      FeedParserErrorType.UNSUPPORTED_FORMAT,
      `无法解析Feed数据，所有格式尝试都失败。最后错误: ${lastError?.message || '未知错误'}`,
      parserData.url
    )
  }
  
  /**
   * 预解析：快速检查Feed基本信息，不解析所有条目
   */
  static async preparse(parserData: ParserData): Promise<PreparseResult> {
    const feedType = FeedTypeDetector.detectFeedType(parserData.data)
    
    if (feedType === FeedType.Unknown) {
      throw new FeedParserError(
        FeedParserErrorType.UNSUPPORTED_FORMAT,
        '无法确定Feed类型',
        parserData.url
      )
    }

    try {
      // 只获取基本feed信息，不解析具体条目
      const basicInfo = FeedTypeDetector.getFeedVersionInfo(parserData.data)
      
      return {
        feedType: basicInfo.type,
        version: basicInfo.version,
        namespace: basicInfo.namespace,
        title: FeedParser.extractTitle(parserData, feedType),
        description: FeedParser.extractDescription(parserData, feedType),
        isValid: true
      }
    } catch (error) {
      return {
        feedType: feedType,
        version: 'unknown',
        title: '',
        description: '',
        isValid: false,
        error: error instanceof Error ? error.message : '未知错误'
      }
    }
  }
  
  /**
   * 提取Feed标题（用于预解析）
   */
  private static extractTitle(parserData: ParserData, feedType: FeedType): string {
    try {
      if (feedType === FeedType.JSONFeed || feedType === FeedType.RSSInJSON) {
        const data: Record<string, object> = JSON.parse(parserData.data)
        return String(data.title || '') || String(((data.rss as Record<string, object>)?.channel as Record<string, object>)?.title || '')
      } else {
        // XML格式
        const titleMatch = parserData.data.match(/<title[^>]*>([^<]*)<\/title>/i)
        return titleMatch ? titleMatch[1].trim() : ''
      }
    } catch {
      return ''
    }
  }
  
  /**
   * 提取Feed描述（用于预解析）
   */
  private static extractDescription(parserData: ParserData, feedType: FeedType): string {
    try {
      if (feedType === FeedType.JSONFeed || feedType === FeedType.RSSInJSON) {
        const data: Record<string, object> = JSON.parse(parserData.data)
        return String(data.description || '') || String(((data.rss as Record<string, object>)?.channel as Record<string, object>)?.description || '')
      } else {
        // XML格式
        const descMatch = parserData.data.match(/<description[^>]*>([^<]*)<\/description>/i)
        return descMatch ? descMatch[1].trim() : ''
      }
    } catch {
      return ''
    }
  }
}

// 导出所有相关类型和类
export { ParserData, FeedParserError, FeedParserErrorType }

export default FeedParser