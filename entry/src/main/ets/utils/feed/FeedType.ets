/**
 * RSS/Atom/JSON Feed类型枚举
 */
export enum FeedType {
  RSS = 'rss',
  Atom = 'atom',
  JSONFeed = 'jsonfeed',
  RSSInJSON = 'rssinjson',
  Unknown = 'unknown'
}

/**
 * Feed格式版本信息
 */
export interface FeedVersionInfo {
  type: FeedType
  version: string
  namespace?: string
}

/**
 * 检测feed类型的最小内容长度要求
 */
export const MIN_CONTENT_LENGTH = 128

/**
 * Feed类型检测器
 */
export class FeedTypeDetector {
  
  /**
   * 检测Feed类型
   */
  static detectFeedType(data: string): FeedType {
    if (!data || data.trim().length === 0) {
      return FeedType.Unknown
    }

    const trimmedData = data.trim()

    // 检测JSON格式
    if (trimmedData.startsWith('{')) {
      return FeedTypeDetector.detectJSONFeedType(trimmedData)
    }

    // 检测XML格式
    if (trimmedData.startsWith('<')) {
      return FeedTypeDetector.detectXMLFeedType(trimmedData)
    }

    return FeedType.Unknown
  }

  /**
   * 检测JSON Feed类型
   */
  private static detectJSONFeedType(data: string): FeedType {
    try {
      const parsed: Record<string, Object> = JSON.parse(data)
      
      // 检查是否为JSON Feed
      if (parsed.version && parsed.version.toString().startsWith('1')) {
        return FeedType.JSONFeed
      }
      
      // 检查是否为RSS in JSON
      if (parsed.rss || (parsed.version && parsed.version.toString().startsWith('2'))) {
        return FeedType.RSSInJSON
      }
      
      return FeedType.Unknown
    } catch (error) {
      return FeedType.Unknown
    }
  }

  /**
   * 检测XML Feed类型
   */
  private static detectXMLFeedType(data: string): FeedType {
    const lowerData = data.toLowerCase()
    
    // 检测RSS
    if (lowerData.includes('<rss') && lowerData.includes('version=')) {
      return FeedType.RSS
    }
    
    // 检测Atom
    if (lowerData.includes('<feed') && 
        (lowerData.includes('xmlns="http://www.w3.org/2005/atom"') || 
         lowerData.includes("xmlns='http://www.w3.org/2005/atom'"))) {
      return FeedType.Atom
    }
    
    return FeedType.Unknown
  }

  /**
   * 获取Feed版本信息
   */
  static getFeedVersionInfo(data: string): FeedVersionInfo {
    const feedType = FeedTypeDetector.detectFeedType(data)
    
    switch (feedType) {
      case FeedType.RSS:
        return FeedTypeDetector.getRSSVersionInfo(data)
      case FeedType.Atom:
        return FeedTypeDetector.getAtomVersionInfo(data)
      case FeedType.JSONFeed:
        return FeedTypeDetector.getJSONFeedVersionInfo(data)
      case FeedType.RSSInJSON:
        return FeedTypeDetector.getRSSInJSONVersionInfo(data)
      default:
        return { type: feedType, version: 'unknown' }
    }
  }

  /**
   * 获取RSS版本信息
   */
  private static getRSSVersionInfo(data: string): FeedVersionInfo {
    const versionMatch = data.match(/version\s*=\s*["']([^"']+)["']/i)
    const version = versionMatch ? versionMatch[1] : 'unknown'
    
    return {
      type: FeedType.RSS,
      version: version
    }
  }

  /**
   * 获取Atom版本信息
   */
  private static getAtomVersionInfo(data: string): FeedVersionInfo {
    return {
      type: FeedType.Atom,
      version: '1.0',
      namespace: 'http://www.w3.org/2005/Atom'
    }
  }

  /**
   * 获取JSON Feed版本信息
   */
  private static getJSONFeedVersionInfo(data: string): FeedVersionInfo {
    try {
      const parsed: Record<string, Object> = JSON.parse(data)
      const version = parsed.version ? parsed.version.toString() : 'unknown'
      
      return {
        type: FeedType.JSONFeed,
        version: version
      }
    } catch (error) {
      return {
        type: FeedType.JSONFeed,
        version: 'unknown'
      }
    }
  }

  /**
   * 获取RSS in JSON版本信息
   */
  private static getRSSInJSONVersionInfo(data: string): FeedVersionInfo {
    try {
      const parsed: Record<string, Object> = JSON.parse(data)
      let version = 'unknown'
      
      if (parsed.rss && (parsed.rss as Record<string, Object>).version) {
        version = ((parsed.rss as Record<string, Object>).version as string).toString()
      } else if (parsed.version) {
        version = (parsed.version as string).toString()
      }
      
      return {
        type: FeedType.RSSInJSON,
        version: version
      }
    } catch (error) {
      return {
        type: FeedType.RSSInJSON,
        version: 'unknown'
      }
    }
  }

  /**
   * 检查数据是否为有效的Feed格式
   */
  static isValidFeed(data: string): boolean {
    const feedType = FeedTypeDetector.detectFeedType(data)
    return feedType !== FeedType.Unknown
  }

  /**
   * 检查是否为特定类型的Feed
   */
  static isFeedType(data: string, expectedType: FeedType): boolean {
    const actualType = FeedTypeDetector.detectFeedType(data)
    return actualType === expectedType
  }

  /**
   * 检查数据是否包含Feed内容的基本特征
   */
  static hasFeedCharacteristics(data: string): boolean {
    if (!data || data.trim().length === 0) {
      return false
    }

    const lowerData = data.toLowerCase()
    
    // 检查是否包含常见的Feed元素
    const feedKeywords = [
      '<rss', '<feed', '<atom', '<channel', '<item', '<entry',
      '"version"', '"items"', '"entries"', '"title"', '"link"'
    ]
    
    return feedKeywords.some(keyword => lowerData.includes(keyword))
  }

  /**
   * 获取所有支持的Feed类型
   */
  static getSupportedTypes(): FeedType[] {
    return [
      FeedType.RSS,
      FeedType.Atom,
      FeedType.JSONFeed,
      FeedType.RSSInJSON
    ]
  }

  /**
   * 获取Feed类型的显示名称
   */
  static getTypeDisplayName(feedType: FeedType): string {
    const displayNames = new Map<FeedType, string>([
      [FeedType.RSS, 'RSS Feed'],
      [FeedType.Atom, 'Atom Feed'],
      [FeedType.JSONFeed, 'JSON Feed'],
      [FeedType.RSSInJSON, 'RSS in JSON'],
      [FeedType.Unknown, '未知格式']
    ])
    
    return displayNames.get(feedType) || '未知格式'
  }

  /**
   * 获取Feed类型的MIME类型
   */
  static getTypeMIME(feedType: FeedType): string {
    const mimeTypes = new Map<FeedType, string>([
      [FeedType.RSS, 'application/rss+xml'],
      [FeedType.Atom, 'application/atom+xml'],
      [FeedType.JSONFeed, 'application/json'],
      [FeedType.RSSInJSON, 'application/json'],
      [FeedType.Unknown, 'text/plain']
    ])
    
    return mimeTypes.get(feedType) || 'text/plain'
  }
}

/**
 * Feed类型工具类
 */
export class FeedTypeUtils {
  /**
   * 比较两个Feed类型
   */
  static isEqual(type1: FeedType, type2: FeedType): boolean {
    return type1 === type2
  }

  /**
   * 检查是否为XML类型的Feed
   */
  static isXMLType(feedType: FeedType): boolean {
    return feedType === FeedType.RSS || feedType === FeedType.Atom
  }

  /**
   * 检查是否为JSON类型的Feed
   */
  static isJSONType(feedType: FeedType): boolean {
    return feedType === FeedType.JSONFeed || feedType === FeedType.RSSInJSON
  }

  /**
   * 获取推荐的文件扩展名
   */
  static getFileExtension(feedType: FeedType): string {
    const extensions = new Map<FeedType, string>([
      [FeedType.RSS, '.rss'],
      [FeedType.Atom, '.atom'],
      [FeedType.JSONFeed, '.json'],
      [FeedType.RSSInJSON, '.json'],
      [FeedType.Unknown, '.txt']
    ])
    
    return extensions.get(feedType) || '.txt'
  }

  /**
   * 从MIME类型推断Feed类型
   */
  static fromMIMEType(mimeType: string): FeedType {
    const normalizedMime = mimeType.toLowerCase().trim()
    
    if (normalizedMime.includes('rss')) {
      return FeedType.RSS
    } else if (normalizedMime.includes('atom')) {
      return FeedType.Atom
    } else if (normalizedMime.includes('json')) {
      // 需要进一步检查内容来区分JSONFeed和RSSInJSON
      return FeedType.JSONFeed
    }
    
    return FeedType.Unknown
  }

  /**
   * 验证Feed类型是否受支持
   */
  static isSupported(feedType: FeedType): boolean {
    return FeedTypeDetector.getSupportedTypes().includes(feedType)
  }

  /**
   * 获取Feed类型的优先级（用于排序）
   */
  static getTypePriority(feedType: FeedType): number {
    const priorities = new Map<FeedType, number>([
      [FeedType.RSS, 1],
      [FeedType.Atom, 2],
      [FeedType.JSONFeed, 3],
      [FeedType.RSSInJSON, 4],
      [FeedType.Unknown, 999]
    ])
    
    return priorities.get(feedType) || 999
  }
}

export default FeedType 