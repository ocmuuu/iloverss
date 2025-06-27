import hilog from '@ohos.hilog'
import { FeedType } from '../FeedType'
import { ParsedFeed } from '../ParsedFeed'
import { ParsedItem } from '../ParsedItem'
import { ParsedAuthor } from '../ParsedAuthor'
import { ParsedAttachment } from '../ParsedAttachment'
import { FeedParserError, FeedParserErrorType } from '../FeedParserError'
import { ParserData } from '../ParserData'

/**
 * RSS in JSON解析器
 * 解析RSS in JSON格式的feed数据
 * 
 * @see https://github.com/scripting/Scripting-News/blob/master/rss-in-json/README.md
 * @see http://cyber.harvard.edu/rss/rss.html
 */
export class RSSInJSONParser {
  
  /**
   * 解析RSS in JSON数据
   */
  static parse(parserData: ParserData): ParsedFeed {
    try {
      const parsedObject: Record<string, object> = JSON.parse(parserData.data)
      
      // 验证RSS对象结构
      const rssObject: Record<string, object> = parsedObject['rss'] as Record<string, object>
      if (!rssObject || typeof rssObject !== 'object') {
        throw new FeedParserError(FeedParserErrorType.RSS_CHANNEL_NOT_FOUND, 'RSS channel未找到', parserData.url)
      }
      
      const channelObject: Record<string, object> = rssObject['channel'] as Record<string, object>
      if (!channelObject || typeof channelObject !== 'object') {
        throw new FeedParserError(FeedParserErrorType.RSS_CHANNEL_NOT_FOUND, 'RSS channel未找到', parserData.url)
      }
      
      // 查找items数组，可能在不同位置且名称可能不同
      let itemsObject = RSSInJSONParser.findItemsArray(parsedObject, channelObject)
      if (!itemsObject) {
        throw new FeedParserError(FeedParserErrorType.RSS_ITEMS_NOT_FOUND, 'RSS items未找到', parserData.url)
      }
      
      // 解析feed基本信息
      const title = String(channelObject['title'] || '')
      const homePageURL = String(channelObject['link'] || '')
      const feedURL = parserData.url
      const feedDescription = String(channelObject['description'] || '')
      const feedLanguage = String(channelObject['language'] || '')
      
      // 解析文章列表
      const items = RSSInJSONParser.parseItems(itemsObject, parserData.url)
      
      return {
        type: FeedType.RSSInJSON,
        title: title,
        homePageURL: homePageURL,
        feedURL: feedURL,
        language: feedLanguage,
        feedDescription: feedDescription,
        nextURL: '',
        iconURL: '',
        faviconURL: '',
        authors: [],
        expired: false,
        hubs: [],
        // 向后兼容字段
        description: feedDescription,
        link: homePageURL,
        imageUrl: ''
      }
      
    } catch (error) {
      if (error instanceof FeedParserError) {
        throw error
      }
      hilog.error(0x0000, 'RSSInJSONParser', `RSS in JSON解析失败: ${error}`)
      throw new FeedParserError(FeedParserErrorType.INVALID_JSON, 'RSS in JSON解析失败', parserData.url)
    }
  }
  
  /**
   * 查找items数组，可能在不同位置且名称可能不同
   */
  private static findItemsArray(parsedObject: Record<string, object>, channelObject: Record<string, object>): Record<string, string>[] | null {
    // 按优先级查找items数组
    const locations = [
      channelObject['item'],
      parsedObject['item'],
      channelObject['items'],
      parsedObject['items']
    ]
    
    for (const location of locations) {
      if (Array.isArray(location)) {
        return location
      }
    }
    
    return null
  }
  
  /**
   * 解析文章列表
   */
  private static parseItems(itemsObject: Record<string, string>[], feedURL: string): ParsedItem[] {
    const items: ParsedItem[] = []
    
    for (const itemData of itemsObject) {
      const item = RSSInJSONParser.parseItemWithDictionary(itemData, feedURL)
      if (item) {
        items.push(item)
      }
    }
    
    return items
  }
  
  /**
   * 解析单个文章
   */
  private static parseItemWithDictionary(itemDictionary: Record<string, string>, feedURL: string): ParsedItem | null {
    const externalURL = itemDictionary['link'] as string || ''
    const title = itemDictionary['title'] as string || ''
    
    // 处理描述内容
    let contentHTML = itemDictionary['description'] as string || ''
    let contentText = ''
    
    // 如果内容不包含HTML标签，则作为纯文本处理
    if (contentHTML && !contentHTML.includes('<')) {
      contentText = contentHTML
      contentHTML = ''
    }
    
    // 至少需要有标题或内容
    if (!contentHTML && !contentText && !title) {
      return null
    }
    
    // 解析发布日期
    let datePublished: Date | null = null
    const pubDateString = itemDictionary['pubDate'] as string
    if (pubDateString) {
      datePublished = RSSInJSONParser.parseDate(pubDateString)
    }
    
    // 解析作者、标签和附件
    const authors = RSSInJSONParser.parseAuthors(itemDictionary)
    const tags = RSSInJSONParser.parseTags(itemDictionary as Record<string, string | Record<string, string> | Record<string, string>[]>)
    const attachments = RSSInJSONParser.parseAttachments(itemDictionary as Record<string, string | Record<string, string | number>>)
    
    // 生成或获取唯一ID
    let uniqueID = itemDictionary['guid'] as string
    if (!uniqueID) {
      uniqueID = RSSInJSONParser.calculateUniqueID(itemDictionary, datePublished, title, externalURL, authors, attachments, contentHTML, contentText)
    }
    
    if (!uniqueID) {
      return null
    }
    
    const item = new ParsedItem(uniqueID, feedURL)
    item.syncServiceID = ''
    item.url = ''
    item.externalURL = externalURL
    item.title = title
    item.language = ''
    item.contentHTML = contentHTML
    item.contentText = contentText
    item.summary = ''
    item.imageURL = ''
    item.bannerImageURL = ''
    item.datePublished = datePublished || undefined
    item.dateModified = undefined
    item.authors = authors
    item.tags = tags
    item.attachments = attachments
    
    return item
  }
  
  /**
   * 计算唯一ID（当guid不存在时）
   */
  private static calculateUniqueID(
    itemDictionary: Record<string, string>,
    datePublished: Date | null,
    title: string,
    externalURL: string,
    authors: ParsedAuthor[],
    attachments: ParsedAttachment[],
    contentHTML: string,
    contentText: string
  ): string {
    // 组合多个元素来生成唯一标识符
    let s = ''
    
    if (datePublished) {
      s += datePublished.getTime().toString()
    }
    if (title) {
      s += title
    }
    if (externalURL) {
      s += externalURL
    }
    if (authors.length > 0 && authors[0].emailAddress) {
      s += authors[0].emailAddress
    }
    if (attachments.length > 0) {
      s += attachments[0].url
    }
    
    if (!s) {
      // 最后的手段
      if (contentHTML) {
        s = contentHTML
      } else if (contentText) {
        s = contentText
      }
    }
    
    // 生成MD5哈希
    return RSSInJSONParser.md5Hash(s)
  }
  
  /**
   * 简单的MD5哈希实现（用于唯一ID生成）
   */
  private static md5Hash(str: string): string {
    // 简化版本，实际应用中建议使用更完整的hash实现
    let hash = 0
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i)
      hash = ((hash << 5) - hash) + char
      hash = hash & hash // 转换为32位整数
    }
    return Math.abs(hash).toString(16)
  }
  
  /**
   * 解析作者信息
   */
  private static parseAuthors(itemDictionary: Record<string, string>): ParsedAuthor[] {
    const authorEmailAddress = itemDictionary['author'] as string
    if (!authorEmailAddress) {
      return []
    }
    
    const parsedAuthor: ParsedAuthor = {
      name: '',
      url: '',
      avatarURL: '',
      emailAddress: authorEmailAddress
    }
    
    return [parsedAuthor]
  }
  
  /**
   * 解析标签
   */
  private static parseTags(itemDictionary: Record<string, string | Record<string, string> | Record<string, string>[]>): string[] {
    const categoryObject = itemDictionary['category']
    
    if (!categoryObject) {
      return []
    }
    
    // 处理单个分类对象
    if (typeof categoryObject === 'object' && !Array.isArray(categoryObject)) {
      const oneTag = categoryObject['#value'] as string
      return oneTag ? [oneTag] : []
    }
    
    // 处理分类数组
    if (Array.isArray(categoryObject)) {
      const tags: string[] = []
      for (const category of categoryObject) {
        if (typeof category === 'object' && category['#value']) {
          tags.push(category['#value'] as string)
        }
      }
      return tags
    }
    
    return []
  }
  
  /**
   * 解析附件
   */
  private static parseAttachments(itemDictionary: Record<string, string | Record<string, string | number>>): ParsedAttachment[] {
    const enclosureObject = itemDictionary['enclosure']
    if (!enclosureObject || typeof enclosureObject !== 'object') {
      return []
    }
    
    const attachmentURL = enclosureObject['url'] as string
    if (!attachmentURL) {
      return []
    }
    
    // 解析附件大小
    let attachmentSize: number | undefined = undefined
    const lengthValue = enclosureObject['length']
    if (typeof lengthValue === 'number') {
      attachmentSize = lengthValue
    } else if (typeof lengthValue === 'string') {
      const parsedSize = parseInt(lengthValue, 10)
      if (!isNaN(parsedSize)) {
        attachmentSize = parsedSize
      }
    }
    
    const mimeType = enclosureObject['type'] as string || ''
    
    const attachment: ParsedAttachment = {
      url: attachmentURL,
      mimeType: mimeType,
      title: '',
      sizeInBytes: attachmentSize,
      durationInSeconds: undefined
    }
    
    return [attachment]
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
} 