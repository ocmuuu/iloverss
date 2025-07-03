import { FeedType } from './FeedType'
import { ParsedAuthor } from './ParsedAuthor'
import { ParsedHub } from './ParsedHub'
import { ParsedItem } from './ParsedItem'

/**
 * 解析后的Feed信息
 * 对应Swift中的ParsedFeed.swift
 */
export interface ParsedFeed {
  type: FeedType
  title?: string
  homePageURL?: string
  feedURL?: string
  language?: string
  feedDescription?: string
  nextURL?: string
  iconURL?: string
  faviconURL?: string
  authors?: ParsedAuthor[]
  expired: boolean
  hubs?: ParsedHub[]
  items?: ParsedItem[]  // 添加缺失的items属性
  lastBuildDate?: string
  managingEditor?: string
  webMaster?: string
  copyright?: string
  generator?: string
  docs?: string
  cloud?: string
  ttl?: number
  rating?: string
  skipHours?: string
  skipDays?: string
  // 保持向后兼容的字段
  description: string
  link: string
  imageUrl: string
}

/**
 * Feed工具类
 */
export class FeedUtils {

  /**
   * 创建Feed信息
   */
  static createFeed(
    type: FeedType,
    title?: string,
    options?: Partial<ParsedFeed>
  ): ParsedFeed {
    return {
      type: type,
      title: title,
      homePageURL: options?.homePageURL,
      feedURL: options?.feedURL,
      language: options?.language,
      feedDescription: options?.feedDescription,
      nextURL: options?.nextURL,
      iconURL: options?.iconURL,
      faviconURL: options?.faviconURL,
      authors: options?.authors || [],
      expired: options?.expired || false,
      hubs: options?.hubs || [],
      lastBuildDate: options?.lastBuildDate,
      managingEditor: options?.managingEditor,
      webMaster: options?.webMaster,
      copyright: options?.copyright,
      generator: options?.generator,
      docs: options?.docs,
      cloud: options?.cloud,
      ttl: options?.ttl,
      rating: options?.rating,
      skipHours: options?.skipHours,
      skipDays: options?.skipDays,
      // 向后兼容字段
      description: options?.feedDescription || options?.description || '',
      link: options?.homePageURL || options?.link || '',
      imageUrl: options?.iconURL || options?.imageUrl || ''
    }
  }

  /**
   * 获取Feed的显示名称
   */
  static getDisplayTitle(feed: ParsedFeed): string {
    if (feed.title && feed.title.trim().length > 0) {
      return feed.title.trim()
    }
    if (feed.feedURL) {
      try {
        // 简单的域名提取，替代URL构造器
        const matches = feed.feedURL.match(/^https?:\/\/([^\/]+)/)
        return matches ? matches[1] : feed.feedURL
      } catch (error) {
        return feed.feedURL
      }
    }
    if (feed.homePageURL) {
      try {
        // 简单的域名提取，替代URL构造器
        const matches = feed.homePageURL.match(/^https?:\/\/([^\/]+)/)
        return matches ? matches[1] : feed.homePageURL
      } catch (error) {
        return feed.homePageURL
      }
    }
    return '未知Feed'
  }

  /**
   * 获取Feed的描述信息
   */
  static getDisplayDescription(feed: ParsedFeed): string {
    return feed.feedDescription || feed.description || '暂无描述'
  }

  /**
   * 获取Feed的主页链接
   */
  static getHomePageURL(feed: ParsedFeed): string | undefined {
    return feed.homePageURL || feed.link || undefined
  }

  /**
   * 获取Feed的图标URL
   */
  static getIconURL(feed: ParsedFeed): string | undefined {
    return feed.iconURL || feed.faviconURL || feed.imageUrl || undefined
  }

  /**
   * 检查Feed是否有效
   */
  static isValidFeed(feed: ParsedFeed): boolean {
    return !!(feed.type && (feed.title || feed.feedURL || feed.homePageURL))
  }

  /**
   * 检查Feed是否已过期
   */
  static isExpired(feed: ParsedFeed): boolean {
    if (feed.expired) {
      return true
    }

    // 检查TTL
    if (feed.ttl && feed.lastBuildDate) {
      try {
        const lastBuild = new Date(feed.lastBuildDate)
        const now = new Date()
        const ttlMs = feed.ttl * 60 * 1000 // TTL单位为分钟
        return (now.getTime() - lastBuild.getTime()) > ttlMs
      } catch {
        return false
      }
    }

    return false
  }

  /**
   * 获取Feed的语言代码
   */
  static getLanguageCode(feed: ParsedFeed): string {
    if (feed.language) {
      // 规范化语言代码
      const lang = feed.language.toLowerCase()
      if (lang.startsWith('zh')) {
        return lang.includes('cn') || lang.includes('hans') ? 'zh-CN' : 'zh-TW'
      }
      return lang.split('-')[0] // 取主要语言代码
    }
    return 'unknown'
  }

  /**
   * 获取Feed类型的显示名称
   */
  static getFeedTypeDisplayName(feed: ParsedFeed): string {
    switch (feed.type) {
      case FeedType.RSS:
        return 'RSS'
      case FeedType.Atom:
        return 'Atom'
              case FeedType.JSONFeed:
        return 'JSON Feed'
              case FeedType.RSSInJSON:
        return 'RSS (JSON)'
      default:
        return '未知格式'
    }
  }

  /**
   * 合并Feed信息（用于更新）
   */
  static mergeFeed(oldFeed: ParsedFeed, newFeed: Partial<ParsedFeed>): ParsedFeed {
    // 手动合并属性，替代扩展运算符
    const merged: ParsedFeed = {
      type: newFeed.type || oldFeed.type,
      title: newFeed.title || oldFeed.title,
      feedURL: newFeed.feedURL || oldFeed.feedURL,
      homePageURL: newFeed.homePageURL || oldFeed.homePageURL,
      description: newFeed.description || oldFeed.description,
      feedDescription: newFeed.feedDescription || oldFeed.feedDescription,
      language: newFeed.language || oldFeed.language,
      link: newFeed.link || oldFeed.link,
      iconURL: newFeed.iconURL || oldFeed.iconURL,
      faviconURL: newFeed.faviconURL || oldFeed.faviconURL,
      imageUrl: newFeed.imageUrl || oldFeed.imageUrl,
      lastBuildDate: newFeed.lastBuildDate || new Date().toISOString(),
      ttl: newFeed.ttl || oldFeed.ttl,
      expired: newFeed.expired !== undefined ? newFeed.expired : oldFeed.expired,
      // 特殊处理数组字段
      authors: newFeed.authors || oldFeed.authors,
      hubs: newFeed.hubs || oldFeed.hubs
    }
    return merged
  }

  /**
   * 创建Feed的摘要信息
   */
  static createSummary(feed: ParsedFeed): FeedSummary {
    return {
      title: FeedUtils.getDisplayTitle(feed),
      description: FeedUtils.getDisplayDescription(feed),
      type: FeedUtils.getFeedTypeDisplayName(feed),
      language: FeedUtils.getLanguageCode(feed),
      homePageURL: FeedUtils.getHomePageURL(feed),
      iconURL: FeedUtils.getIconURL(feed),
      isExpired: FeedUtils.isExpired(feed),
      authorCount: feed.authors?.length || 0,
      hubCount: feed.hubs?.length || 0,
      lastUpdated: feed.lastBuildDate ? new Date(feed.lastBuildDate) : undefined
    }
  }

  /**
   * 验证Feed URL格式
   */
  static validateFeedURL(url: string): boolean {
    try {
      // 简单的URL验证，替代URL构造器
      return url.startsWith('http://') || url.startsWith('https://')
    } catch (error) {
      return false
    }
  }

  /**
   * 从URL推断Feed类型
   */
  static inferFeedTypeFromURL(url: string): FeedType {
    const lowerURL = url.toLowerCase()
    
    if (lowerURL.includes('atom') || lowerURL.endsWith('.atom')) {
              return FeedType.Atom
    }
    if (lowerURL.includes('json') || lowerURL.endsWith('.json')) {
              return FeedType.JSONFeed
    }
    if (lowerURL.includes('rss') || lowerURL.endsWith('.rss') || lowerURL.endsWith('.xml')) {
      return FeedType.RSS
    }
    
            return FeedType.Unknown
  }

  /**
   * 计算Feed的哈希值（用于比较）
   */
  static getFeedHash(feed: ParsedFeed): string {
    const key = feed.feedURL || feed.homePageURL || feed.title || ''
    return key
  }

  /**
   * 检查两个Feed是否相同
   */
  static isSameFeed(feed1: ParsedFeed, feed2: ParsedFeed): boolean {
    return FeedUtils.getFeedHash(feed1) === FeedUtils.getFeedHash(feed2)
  }
}

/**
 * Feed摘要信息接口
 */
export interface FeedSummary {
  title: string
  description: string
  type: string
  language: string
  homePageURL?: string
  iconURL?: string
  isExpired: boolean
  authorCount: number
  hubCount: number
  lastUpdated?: Date
}

/**
 * Feed统计信息接口
 */
export interface FeedStatistics {
  totalFeeds: number
  activeFeedsByType: Record<string, number>
  expiredFeeds: number
  feedsByLanguage: Record<string, number>
  averageUpdateInterval?: number
}

export default ParsedFeed 