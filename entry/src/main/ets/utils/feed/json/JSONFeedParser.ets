import hilog from '@ohos.hilog'
import { FeedType } from '../FeedType'
import { ParsedFeed } from '../ParsedFeed'
import { ParsedItem } from '../ParsedItem'
import { ParsedAuthor } from '../ParsedAuthor'
import { ParsedHub } from '../ParsedHub'
import { ParsedAttachment } from '../ParsedAttachment'
import { FeedParserError, FeedParserErrorType } from '../FeedParserError'
import { ParserData } from '../ParserData'

/**
 * JSON Feed解析器键名接口
 */
interface JSONFeedKeys {
  version: string
  items: string
  title: string
  homePageURL: string
  feedURL: string
  feedDescription: string
  nextURL: string
  icon: string
  favicon: string
  expired: string
  author: string
  authors: string
  name: string
  url: string
  avatar: string
  hubs: string
  type: string
  contentHTML: string
  contentText: string
  externalURL: string
  summary: string
  image: string
  bannerImage: string
  datePublished: string
  dateModified: string
  tags: string
  uniqueID: string
  attachments: string
  mimeType: string
  sizeInBytes: string
  durationInSeconds: string
  language: string
}

/**
 * JSON Feed解析器键名常量
 */
const Keys: JSONFeedKeys = {
  version: 'version',
  items: 'items',
  title: 'title',
  homePageURL: 'home_page_url',
  feedURL: 'feed_url',
  feedDescription: 'description',
  nextURL: 'next_url',
  icon: 'icon',
  favicon: 'favicon',
  expired: 'expired',
  author: 'author',
  authors: 'authors',
  name: 'name',
  url: 'url',
  avatar: 'avatar',
  hubs: 'hubs',
  type: 'type',
  contentHTML: 'content_html',
  contentText: 'content_text',
  externalURL: 'external_url',
  summary: 'summary',
  image: 'image',
  bannerImage: 'banner_image',
  datePublished: 'date_published',
  dateModified: 'date_modified',
  tags: 'tags',
  uniqueID: 'id',
  attachments: 'attachments',
  mimeType: 'mime_type',
  sizeInBytes: 'size_in_bytes',
  durationInSeconds: 'duration_in_seconds',
  language: 'language'
}

/**
 * JSON Feed解析器
 * 解析JSON Feed格式的feed数据
 * 
 * @see https://jsonfeed.org/version/1.1
 */
export class JSONFeedParser {
  private static readonly JSON_FEED_VERSION_MARKER = '://jsonfeed.org/version/'
  
  /**
   * 解析JSON Feed数据
   */
  static parse(parserData: ParserData): ParsedFeed {
    try {
      const jsonData = JSON.parse(parserData.data) as Record<string, string | number | boolean | Record<string, string>[]>
      
      // 验证版本信息
      const version = jsonData[Keys.version] as string
      if (!version || !version.includes(JSONFeedParser.JSON_FEED_VERSION_MARKER)) {
        throw new FeedParserError(FeedParserErrorType.JSON_FEED_VERSION_NOT_FOUND, 'JSON Feed版本未找到', parserData.url)
      }
      
      // 验证必需的字段
      const itemsArray = jsonData[Keys.items] as Record<string, string | number | boolean>[]
      if (!itemsArray || !Array.isArray(itemsArray)) {
        throw new FeedParserError(FeedParserErrorType.JSON_FEED_ITEMS_NOT_FOUND, 'JSON Feed items字段未找到', parserData.url)
      }
      
      const title = jsonData[Keys.title] as string
      if (!title) {
        throw new FeedParserError(FeedParserErrorType.JSON_FEED_TITLE_NOT_FOUND, 'JSON Feed title字段未找到', parserData.url)
      }
      
      // 解析feed基本信息
      const authors = JSONFeedParser.parseAuthors(jsonData)
      const homePageURL = jsonData[Keys.homePageURL] as string || ''
      const feedURL = jsonData[Keys.feedURL] as string || parserData.url
      const feedDescription = jsonData[Keys.feedDescription] as string || ''
      const nextURL = jsonData[Keys.nextURL] as string || ''
      const iconURL = jsonData[Keys.icon] as string || ''
      const faviconURL = jsonData[Keys.favicon] as string || ''
      const expired = jsonData[Keys.expired] as boolean || false
      const hubs = JSONFeedParser.parseHubs(jsonData as Record<string, string | Record<string, string>[]>)
      const language = jsonData[Keys.language] as string || ''
      
      // 解析文章列表
      const items = JSONFeedParser.parseItems(itemsArray, parserData.url)
      
      return {
        type: FeedType.JSONFeed,
        title: title,
        homePageURL: homePageURL,
        feedURL: feedURL,
        language: language,
        feedDescription: feedDescription,
        nextURL: nextURL,
        iconURL: iconURL,
        faviconURL: faviconURL,
        authors: authors,
        expired: expired,
        hubs: hubs,
        // 向后兼容字段
        description: feedDescription,
        link: homePageURL,
        imageUrl: iconURL || ''
      }
      
    } catch (error) {
      if (error instanceof FeedParserError) {
        throw error
      }
      hilog.error(0x0000, 'JSONFeedParser', `JSON解析失败: ${error}`)
      throw new FeedParserError(FeedParserErrorType.INVALID_JSON, 'JSON解析失败', parserData.url)
    }
  }
  
  /**
   * 解析作者信息
   */
  private static parseAuthors(dictionary: Record<string, string | number | boolean | Record<string, string>[]>): ParsedAuthor[] {
    const authors: ParsedAuthor[] = []

    // 1) authors 数组
    const authorsVal = dictionary[Keys.authors]
    if (Array.isArray(authorsVal)) {
      for (const a of authorsVal) {
        if (typeof a === 'object' && a !== null && !Array.isArray(a)) {
          const author = JSONFeedParser.parseAuthor(a as Record<string, string>)
          if (author) {
            authors.push(author)
          }
        }
      }
      return authors
    }

    // 2) author 单对象
    const authorVal = dictionary[Keys.author]
    if (authorVal && typeof authorVal === 'object' && authorVal !== null && !Array.isArray(authorVal)) {
      const author = JSONFeedParser.parseAuthor(authorVal as Record<string, string>)
      if (author) {
        authors.push(author)
      }
    }

    return authors
  }
  
  /**
   * 解析单个作者
   */
  private static parseAuthor(dictionary: Record<string, string>): ParsedAuthor | null {
    const name = dictionary[Keys.name] as string || ''
    const url = dictionary[Keys.url] as string || ''
    const avatar = dictionary[Keys.avatar] as string || ''
    
    if (!name && !url && !avatar) {
      return null
    }
    
    return {
      name: name,
      url: url,
      avatarURL: avatar,
      emailAddress: ''
    }
  }
  
  /**
   * 解析Hub信息
   */
  private static parseHubs(dictionary: Record<string, string | Record<string, string>[]>): ParsedHub[] {
    const hubs: ParsedHub[] = []
    
    const hubsArray = dictionary[Keys.hubs] as Record<string, string>[]
    if (!hubsArray || !Array.isArray(hubsArray)) {
      return hubs
    }
    
    for (const hubData of hubsArray) {
      const hubURL = hubData[Keys.url] as string
      const hubType = hubData[Keys.type] as string
      
      if (hubURL && hubType) {
        hubs.push(new ParsedHub(hubURL, hubType))
      }
    }
    
    return hubs
  }
  
  /**
   * 解析文章列表
   */
  private static parseItems(itemsArray: Record<string, string | number | boolean>[], feedURL: string): ParsedItem[] {
    const items: ParsedItem[] = []
    
    for (const itemData of itemsArray) {
      const item = JSONFeedParser.parseItem(itemData, feedURL)
      if (item) {
        items.push(item)
      }
    }
    
    return items
  }
  
  /**
   * 解析单个文章
   */
  private static parseItem(itemDictionary: Record<string, string | number | boolean>, feedURL: string): ParsedItem | null {
    // 获取唯一ID
    const uniqueID = JSONFeedParser.parseUniqueID(itemDictionary as Record<string, string | number>)
    if (!uniqueID) {
      return null
    }
    
    // 至少需要有内容
    const contentHTML = itemDictionary[Keys.contentHTML] as string || ''
    const contentText = itemDictionary[Keys.contentText] as string || ''
    if (!contentHTML && !contentText) {
      return null
    }
    
    // 解析基本信息
    const url = itemDictionary[Keys.url] as string || ''
    const externalURL = itemDictionary[Keys.externalURL] as string || ''
    const title = JSONFeedParser.parseTitle(itemDictionary as Record<string, string>, feedURL)
    const language = itemDictionary[Keys.language] as string || ''
    const summary = itemDictionary[Keys.summary] as string || ''
    const imageURL = itemDictionary[Keys.image] as string || ''
    const bannerImageURL = itemDictionary[Keys.bannerImage] as string || ''
    
    // 解析日期
    const datePublished = JSONFeedParser.parseDate(itemDictionary[Keys.datePublished] as string) || undefined
    const dateModified = JSONFeedParser.parseDate(itemDictionary[Keys.dateModified] as string) || undefined
    
    // 解析作者、标签和附件
    const authors = JSONFeedParser.parseAuthors(itemDictionary as Record<string, string | number | boolean | Record<string, string>[]>)
    const tags = JSONFeedParser.parseTagsSafe(itemDictionary)
    const attachments = JSONFeedParser.parseAttachmentsSafe(itemDictionary)
    
    const item = new ParsedItem(uniqueID, feedURL)
    item.syncServiceID = ''
    item.url = url
    item.externalURL = externalURL
    item.title = title
    item.language = language
    item.contentHTML = contentHTML
    item.contentText = contentText
    item.summary = summary
    item.imageURL = imageURL
    item.bannerImageURL = bannerImageURL
    item.datePublished = datePublished
    item.dateModified = dateModified
    item.authors = authors
    item.tags = tags
    item.attachments = attachments
    
    return item
  }
  
  /**
   * 解析标题（处理特殊feed的HTML实体）
   */
  private static parseTitle(itemDictionary: Record<string, string>, feedURL: string): string {
    const title = itemDictionary[Keys.title] as string || ''
    
    if (JSONFeedParser.isSpecialCaseTitleWithEntitiesFeed(feedURL)) {
      // 对于特殊feed，需要解码HTML实体
      return title.replace(/&amp;/g, '&')
        .replace(/&lt;/g, '<')
        .replace(/&gt;/g, '>')
        .replace(/&quot;/g, '"')
        .replace(/&#39;/g, "'")
    }
    
    return title
  }
  
  /**
   * 检查是否是标题包含HTML实体的特殊feed
   */
  private static isSpecialCaseTitleWithEntitiesFeed(feedURL: string): boolean {
    const lowerFeedURL = feedURL.toLowerCase()
    const matchStrings = ['kottke.org', 'pxlnv.com', 'macstories.net', 'macobserver.com']
    
    return matchStrings.some(matchString => lowerFeedURL.includes(matchString))
  }
  
  /**
   * 解析唯一ID
   */
  private static parseUniqueID(itemDictionary: Record<string, string | number>): string | null {
    const uniqueID = itemDictionary[Keys.uniqueID]
    
    if (typeof uniqueID === 'string') {
      return uniqueID
    }
    
    // 规范说如果是数字，应该转换为字符串
    if (typeof uniqueID === 'number') {
      return uniqueID.toString()
    }
    
    return null
  }
  
  /**
   * 解析日期
   */
  private static parseDate(dateString: string): Date | null {
    if (!dateString) {
      return null
    }
    
    const date = new Date(dateString)
    return isNaN(date.getTime()) ? null : date
  }
  
  /**
   * 解析标签
   */
  private static parseTags(itemDictionary: Record<string, string[]>): string[] {
    const tagsArray = itemDictionary[Keys.tags] as string[]
    if (!tagsArray || !Array.isArray(tagsArray)) {
      return []
    }
    
    return tagsArray.filter(tag => typeof tag === 'string')
  }

  /**
   * 安全解析标签
   */
  private static parseTagsSafe(itemDictionary: Record<string, string | number | boolean>): string[] {
    const tagsValue = itemDictionary[Keys.tags]
    if (!tagsValue || !Array.isArray(tagsValue)) {
      return []
    }
    
    return (tagsValue as string[]).filter(tag => typeof tag === 'string')
  }
  
  /**
   * 解析附件
   */
  private static parseAttachments(itemDictionary: Record<string, Record<string, string | number>[]>): ParsedAttachment[] {
    const attachments: ParsedAttachment[] = []
    
    const attachmentsArray = itemDictionary[Keys.attachments] as Record<string, string | number>[]
    if (!attachmentsArray || !Array.isArray(attachmentsArray)) {
      return attachments
    }
    
    for (const attachmentData of attachmentsArray) {
      const attachment = JSONFeedParser.parseAttachment(attachmentData)
      if (attachment) {
        attachments.push(attachment)
      }
    }
    
    return attachments
  }

  /**
   * 安全解析附件
   */
  private static parseAttachmentsSafe(itemDictionary: Record<string, string | number | boolean>): ParsedAttachment[] {
    const attachments: ParsedAttachment[] = []
    
    const attachmentsValue = itemDictionary[Keys.attachments]
    if (!attachmentsValue || !Array.isArray(attachmentsValue)) {
      return attachments
    }
    
    const attachmentsArray = attachmentsValue as Record<string, string | number>[]
    for (const attachmentData of attachmentsArray) {
      const attachment = JSONFeedParser.parseAttachment(attachmentData)
      if (attachment) {
        attachments.push(attachment)
      }
    }
    
    return attachments
  }
  
  /**
   * 解析单个附件
   */
  private static parseAttachment(attachmentObject: Record<string, string | number>): ParsedAttachment | null {
    const url = attachmentObject[Keys.url] as string
    const mimeType = attachmentObject[Keys.mimeType] as string
    
    if (!url || !mimeType) {
      return null
    }
    
    const title = attachmentObject[Keys.title] as string || ''
    const sizeInBytes = attachmentObject[Keys.sizeInBytes] as number || 0
    const durationInSeconds = attachmentObject[Keys.durationInSeconds] as number || 0
    
    return {
      url: url,
      mimeType: mimeType,
      title: title,
      sizeInBytes: sizeInBytes > 0 ? sizeInBytes : undefined,
      durationInSeconds: durationInSeconds > 0 ? durationInSeconds : undefined
    }
  }
} 