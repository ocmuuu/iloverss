import { ParsedAuthor } from './ParsedAuthor'
import { ParsedAttachment } from './ParsedAttachment'

/**
 * 解析后的Feed文章/条目
 */
export class ParsedItem {
  public syncServiceID?: string
  public uniqueID: string
  public feedURL: string
  public url?: string
  public externalURL?: string
  public title?: string
  public language?: string
  public contentHTML?: string
  public contentText?: string
  public summary?: string
  public imageURL?: string
  public bannerImageURL?: string
  public datePublished?: Date
  public dateModified?: Date
  public authors: ParsedAuthor[]
  public tags: string[]
  public attachments: ParsedAttachment[]

  constructor(uniqueID: string, feedURL: string) {
    this.uniqueID = uniqueID
    this.feedURL = feedURL
    this.authors = []
    this.tags = []
    this.attachments = []
  }

  /**
   * 验证文章是否有效（至少有标题或内容）
   */
  isValid(): boolean {
    return !!(this.title && this.title.trim().length > 0) ||
           !!(this.contentHTML && this.contentHTML.trim().length > 0) ||
           !!(this.contentText && this.contentText.trim().length > 0) ||
           !!(this.summary && this.summary.trim().length > 0)
  }

  /**
   * 获取发布日期字符串
   */
  getDatePublishedString(): string {
    return this.datePublished ? this.datePublished.toISOString() : ''
  }

  /**
   * 获取修改日期字符串
   */
  getDateModifiedString(): string {
    return this.dateModified ? this.dateModified.toISOString() : ''
  }

  /**
   * 获取所有作者姓名
   */
  getAuthorNames(): string[] {
    return this.authors.map(author => author.name).filter(name => !!name) as string[]
  }

  /**
   * 获取作者姓名字符串（逗号分隔）
   */
  getAuthorNamesString(): string {
    const names = this.getAuthorNames()
    return names.join(', ')
  }

  /**
   * 获取标签字符串（逗号分隔）
   */
  getTagsString(): string {
    return this.tags.join(', ')
  }

  /**
   * 添加作者
   */
  addAuthor(author: ParsedAuthor): void {
    this.authors.push(author)
  }

  /**
   * 添加标签
   */
  addTag(tag: string): void {
    if (tag && tag.trim().length > 0 && !this.tags.includes(tag.trim())) {
      this.tags.push(tag.trim())
    }
  }

  /**
   * 添加多个标签
   */
  addTags(newTags: string[]): void {
    const uniqueTags = Array.from(new Set(newTags.filter(tag => tag && tag.trim().length > 0)))
    for (const tag of uniqueTags) {
      this.addTag(tag)
    }
  }

  /**
   * 添加附件
   */
  addAttachment(attachment: ParsedAttachment): void {
    this.attachments.push(attachment)
  }

  /**
   * 获取纯文本内容（优先级：contentText > 从HTML提取 > summary）
   */
  getPlainTextContent(): string {
    if (this.contentText && this.contentText.trim().length > 0) {
      return this.contentText.trim()
    }
    
    if (this.contentHTML && this.contentHTML.trim().length > 0) {
      // 简单的HTML标签移除
      return this.contentHTML.replace(/<[^>]*>/g, '').trim()
    }
    
    return this.summary || ''
  }

  /**
   * 获取显示用的摘要（限制长度）
   */
  getDisplaySummary(maxLength: number = 200): string {
    const content = this.getPlainTextContent()
    if (content.length <= maxLength) {
      return content
    }
    return content.substring(0, maxLength) + '...'
  }

  /**
   * 检查是否有图片
   */
  hasImage(): boolean {
    return !!(this.imageURL || this.bannerImageURL)
  }

  /**
   * 获取最佳图片URL（优先banner，后备image）
   */
  getBestImageURL(): string {
    return this.bannerImageURL || this.imageURL || ''
  }

  /**
   * 获取最佳URL（优先external，后备url）
   */
  getBestURL(): string {
    return this.externalURL || this.url || ''
  }

  /**
   * 检查是否有作者信息
   */
  hasAuthors(): boolean {
    return this.authors.length > 0
  }

  /**
   * 检查是否有标签
   */
  hasTags(): boolean {
    return this.tags.length > 0
  }

  /**
   * 检查是否有附件
   */
  hasAttachments(): boolean {
    return this.attachments.length > 0
  }

  /**
   * 转换为字符串表示
   */
  toString(): string {
    return `ParsedItem(title: "${this.title}", url: "${this.url}")`
  }

  /**
   * 创建ParsedItem实例
   */
  static create(uniqueID: string, feedURL: string, data?: Partial<ParsedItem>): ParsedItem {
    const item = new ParsedItem(uniqueID, feedURL)
    
    if (data) {
      item.syncServiceID = data.syncServiceID
      item.url = data.url
      item.externalURL = data.externalURL
      item.title = data.title
      item.language = data.language
      item.contentHTML = data.contentHTML
      item.contentText = data.contentText
      item.summary = data.summary
      item.imageURL = data.imageURL
      item.bannerImageURL = data.bannerImageURL
      item.datePublished = data.datePublished
      item.dateModified = data.dateModified
      
      if (data.authors) {
        item.authors = data.authors.slice()
      }
      if (data.tags) {
        item.tags = data.tags.slice()
      }
      if (data.attachments) {
        item.attachments = data.attachments.slice()
      }
    }
    
    return item
  }

  /**
   * 从对象创建ParsedItem实例
   */
  static fromObject(obj: Record<string, Object>): ParsedItem {
    const uniqueID = obj.uniqueID as string || obj.guid as string || obj.id as string || ''
    const feedURL = obj.feedURL as string || obj.link as string || ''
    
    const item = new ParsedItem(uniqueID, feedURL)
    
    // 基本字符串字段
    item.syncServiceID = obj.syncServiceID as string
    item.url = obj.url as string
    item.externalURL = obj.externalURL as string
    item.title = obj.title as string
    item.language = obj.language as string
    item.contentHTML = obj.contentHTML as string
    item.contentText = obj.contentText as string
    item.summary = obj.summary as string || obj.description as string
    item.imageURL = obj.imageURL as string
    item.bannerImageURL = obj.bannerImageURL as string
    
    // 日期字段
    if (obj.datePublished) {
      if (obj.datePublished instanceof Date) {
        item.datePublished = obj.datePublished
      } else {
        item.datePublished = new Date(obj.datePublished as string)
      }
    }
    if (obj.dateModified) {
      if (obj.dateModified instanceof Date) {
        item.dateModified = obj.dateModified
      } else {
        item.dateModified = new Date(obj.dateModified as string)
      }
    }
    
    // 数组字段
    if (obj.authors && Array.isArray(obj.authors)) {
      for (const authorData of obj.authors as Record<string, string>[]) {
        const author: ParsedAuthor = {}
        if (typeof authorData === 'object' && authorData !== null) {
          const data = authorData as Record<string, string>
          author.name = data.name
          author.url = data.url
          author.avatarURL = data.avatarURL
          author.emailAddress = data.emailAddress
        }
        item.addAuthor(author)
      }
    }
    if (obj.tags && Array.isArray(obj.tags)) {
      item.addTags(obj.tags as string[])
    }
    if (obj.attachments && Array.isArray(obj.attachments)) {
      for (const attachmentData of obj.attachments as Record<string, string | number>[]) {
        const attachment: ParsedAttachment = { url: '' }
        if (typeof attachmentData === 'object' && attachmentData !== null) {
          const data = attachmentData as Record<string, string | number>
          attachment.url = data.url as string || ''
          attachment.mimeType = data.mimeType as string
          attachment.title = data.title as string
          attachment.sizeInBytes = data.sizeInBytes as number
          attachment.durationInSeconds = data.durationInSeconds as number
        }
        item.addAttachment(attachment)
      }
    }
    
    return item
  }
}

/**
 * ParsedItem工具类
 */
export class ParsedItemUtils {
  /**
   * 验证ParsedItem数组
   */
  static validateItems(items: ParsedItem[]): ParsedItem[] {
    return items.filter(item => item.isValid())
  }

  /**
   * 按发布日期排序（最新在前）
   */
  static sortByDatePublished(items: ParsedItem[]): ParsedItem[] {
    const sortedItems = items.slice() // 创建副本
    sortedItems.sort((a, b) => {
      const dateA = a.datePublished || new Date(0)
      const dateB = b.datePublished || new Date(0)
      return dateB.getTime() - dateA.getTime()
    })
    return sortedItems
  }

  /**
   * 按标题排序
   */
  static sortByTitle(items: ParsedItem[]): ParsedItem[] {
    const sortedItems = items.slice() // 创建副本
    sortedItems.sort((a, b) => {
      const titleA = a.title || ''
      const titleB = b.title || ''
      return titleA.localeCompare(titleB)
    })
    return sortedItems
  }

  /**
   * 根据关键词过滤
   */
  static filterByKeyword(items: ParsedItem[], keyword: string): ParsedItem[] {
    if (!keyword || keyword.trim().length === 0) {
      return items
    }
    
    const lowerKeyword = keyword.toLowerCase()
    return items.filter(item => {
      return (item.title && item.title.toLowerCase().includes(lowerKeyword)) ||
             (item.summary && item.summary.toLowerCase().includes(lowerKeyword)) ||
             (item.contentText && item.contentText.toLowerCase().includes(lowerKeyword))
    })
  }

  /**
   * 根据作者过滤
   */
  static filterByAuthor(items: ParsedItem[], authorName: string): ParsedItem[] {
    if (!authorName || authorName.trim().length === 0) {
      return items
    }
    
    const lowerAuthorName = authorName.toLowerCase()
    return items.filter(item => {
      return item.authors.some(author => 
        author.name && author.name.toLowerCase().includes(lowerAuthorName)
      )
    })
  }

  /**
   * 根据标签过滤
   */
  static filterByTag(items: ParsedItem[], tag: string): ParsedItem[] {
    if (!tag || tag.trim().length === 0) {
      return items
    }
    
    const lowerTag = tag.toLowerCase()
    return items.filter(item => {
      return item.tags.some(itemTag => 
        itemTag.toLowerCase().includes(lowerTag)
      )
    })
  }

  /**
   * 根据日期范围过滤
   */
  static filterByDateRange(items: ParsedItem[], startDate: Date, endDate: Date): ParsedItem[] {
    return items.filter(item => {
      const publishDate = item.datePublished
      if (!publishDate) {
        return false
      }
      return publishDate >= startDate && publishDate <= endDate
    })
  }

  /**
   * 获取所有不重复的作者
   */
  static getAllAuthors(items: ParsedItem[]): ParsedAuthor[] {
    const authorMap = new Map<string, ParsedAuthor>()
    
    for (const item of items) {
      for (const author of item.authors) {
        if (author.name && !authorMap.has(author.name)) {
          authorMap.set(author.name, author)
        }
      }
    }
    
    return Array.from(authorMap.values())
  }

  /**
   * 获取所有不重复的标签
   */
  static getAllTags(items: ParsedItem[]): string[] {
    const tagSet = new Set<string>()
    
    for (const item of items) {
      for (const tag of item.tags) {
        tagSet.add(tag)
      }
    }
    
    const sortedTags = Array.from(tagSet)
    sortedTags.sort()
    return sortedTags
  }

  /**
   * 获取统计信息
   */
  static getStatistics(items: ParsedItem[]): ItemStatistics {
    let totalItems = items.length
    let itemsWithImages = 0
    let itemsWithAuthors = 0
    let itemsWithTags = 0
    let itemsWithAttachments = 0
    
    for (const item of items) {
      if (item.hasImage()) itemsWithImages++
      if (item.hasAuthors()) itemsWithAuthors++
      if (item.hasTags()) itemsWithTags++
      if (item.hasAttachments()) itemsWithAttachments++
    }
    
    return {
      totalItems,
      itemsWithImages,
      itemsWithAuthors,
      itemsWithTags,
      itemsWithAttachments,
      uniqueAuthors: ParsedItemUtils.getAllAuthors(items).length,
      uniqueTags: ParsedItemUtils.getAllTags(items).length
    }
  }

  /**
   * 合并重复的文章（基于uniqueID或URL）
   */
  static deduplicateItems(items: ParsedItem[]): ParsedItem[] {
    const seenItems = new Set<string>()
    const result: ParsedItem[] = []
    
    for (const item of items) {
      const key = item.uniqueID || item.url || item.title || ''
      if (key && !seenItems.has(key)) {
        seenItems.add(key)
        result.push(item)
      }
    }
    
    return result
  }

  /**
   * 限制文章数量
   */
  static limitItems(items: ParsedItem[], maxCount: number): ParsedItem[] {
    return items.slice(0, maxCount)
  }
}

/**
 * 文章统计信息接口
 */
export interface ItemStatistics {
  totalItems: number
  itemsWithImages: number
  itemsWithAuthors: number
  itemsWithTags: number
  itemsWithAttachments: number
  uniqueAuthors: number
  uniqueTags: number
}

export default ParsedItem 