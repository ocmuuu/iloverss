import hilog from '@ohos.hilog'
import { FeedType } from '../FeedType'
import { ParsedFeed } from '../ParsedFeed'
import { ParsedItem } from '../ParsedItem'
import { ParsedAuthor } from '../ParsedAuthor'
import { ParsedAttachment } from '../ParsedAttachment'
import { FeedParserError, FeedParserErrorType } from '../FeedParserError'
import { ParserData } from '../ParserData'
import { XMLParser, Element } from './XMLParser'
import { RSParsedFeedTransformer } from './RSParsedFeedTransformer'

/**
 * RSS解析的中间数据结构
 */
export interface RSParsedFeed {
  title: string
  link: string
  urlString: string
  language: string
  description: string
  articles: RSParsedArticle[]
  lastBuildDate?: string | null
  ttl?: number
  iconUrl?: string
}

export interface RSParsedArticle {
  articleID: string
  permalink: string
  link: string
  title: string
  language: string
  body: string
  datePublished: Date | null
  dateModified: Date | null
  authors: RSParsedAuthor[]
  enclosures: RSParsedEnclosure[]
  tags: string[]
}

export interface RSParsedAuthor {
  name: string
  url: string
  emailAddress: string
}

export interface RSParsedEnclosure {
  url: string
  mimeType: string
  length: number
}

/**
 * RSS XML解析器
 * 包装XML解析功能，提供与其他解析器一致的接口
 */
export class RSSParser {
  
  /**
   * 解析RSS XML数据
   */
  static parse(parserData: ParserData): ParsedFeed | null {
    try {
      const rsParsedFeed = RSSParser.parseRSSXML(parserData)
      if (rsParsedFeed) {
        return RSParsedFeedTransformer.parsedFeed(rsParsedFeed)
      }
      return null
    } catch (error) {
      hilog.error(0x0000, 'RSSParser', `RSS解析失败: ${error}`)
      return null
    }
  }
  
  /**
   * 解析RSS XML内容
   */
  private static parseRSSXML(parserData: ParserData): RSParsedFeed | null {
    try {
      const xmlDoc = XMLParser.parse(parserData.data)
      
      // 查找RSS根元素
      const rssElement = xmlDoc.getElementsByTagName('rss')[0]
      if (!rssElement) {
        throw new FeedParserError(FeedParserErrorType.RSS_CHANNEL_NOT_FOUND, 'RSS根元素未找到', parserData.url)
      }
      
      // 查找channel元素
      const channelElement = rssElement.getElementsByTagName('channel')[0]
      if (!channelElement) {
        throw new FeedParserError(FeedParserErrorType.RSS_CHANNEL_NOT_FOUND, 'RSS channel元素未找到', parserData.url)
      }
      
      // 解析channel信息
      const title = RSSParser.getElementText(channelElement, 'title')
      const link = RSSParser.getElementText(channelElement, 'link')
      const description = RSSParser.getElementText(channelElement, 'description')
      const language = RSSParser.getElementText(channelElement, 'language')
      const lastBuildDate = RSSParser.getElementText(channelElement, 'lastBuildDate')
      const ttlStr = RSSParser.getElementText(channelElement, 'ttl')
      const ttlNum = ttlStr ? parseInt(ttlStr, 10) : 0
      const imageElement = channelElement.getElementsByTagName('image')[0]
      let iconUrl = ''
      if (imageElement) {
        iconUrl = RSSParser.getElementText(imageElement, 'url')
      }
      
      // 解析item列表
      const itemElements = channelElement.getElementsByTagName('item')
      const articles: RSParsedArticle[] = []
      
      for (let i = 0; i < itemElements.length; i++) {
        const itemElement = itemElements[i]
        const article = RSSParser.parseRSSItem(itemElement, parserData.url)
        if (article) {
          articles.push(article)
        }
      }
      
      return {
        title: title,
        link: link,
        urlString: parserData.url,
        language: language,
        description: description,
        articles: articles,
        lastBuildDate: lastBuildDate,
        ttl: ttlNum,
        iconUrl: iconUrl
      }
      
    } catch (error) {
      hilog.error(0x0000, 'RSSParser', `RSS XML解析失败: ${error}`)
      return null
    }
  }
  
  /**
   * 解析RSS item元素
   */
  private static parseRSSItem(itemElement: Element, feedURL: string): RSParsedArticle | null {
    try {
      const title = RSSParser.getElementText(itemElement, 'title')
      const link = RSSParser.getElementText(itemElement, 'link')
      const description = RSSParser.getElementText(itemElement, 'description')
      const contentEncoded = RSSParser.getElementText(itemElement, 'content:encoded')
      const bodyContent = contentEncoded || description
      const guid = RSSParser.getElementText(itemElement, 'guid')
      const pubDate = RSSParser.getElementText(itemElement, 'pubDate')
      const author = RSSParser.getElementText(itemElement, 'author') || RSSParser.getElementText(itemElement, 'dc:creator')
      
      // 生成文章ID
      const articleID = guid || RSSParser.generateArticleID(title, link, pubDate)
      
      // 解析日期
      const datePublished = pubDate ? RSSParser.parseDate(pubDate) : null
      
      // 解析作者
      const authors: RSParsedAuthor[] = []
      if (author) {
        authors.push({
          name: '',
          url: '',
          emailAddress: author
        })
      }
      
      // 解析分类/标签
      const tags: string[] = []
      const categoryElements = itemElement.getElementsByTagName('category')
      for (let i = 0; i < categoryElements.length; i++) {
        const tagText = categoryElements[i].textContent?.trim()
        if (tagText) {
          tags.push(tagText)
        }
      }
      
      // 解析附件
      const enclosures = RSSParser.parseEnclosures(itemElement)
      
      return {
        articleID: articleID,
        permalink: link,
        link: link,
        title: title,
        language: '',
        body: bodyContent,
        datePublished: datePublished,
        dateModified: null,
        authors: authors,
        enclosures: enclosures,
        tags: tags
      }
      
    } catch (error) {
      hilog.warn(0x0000, 'RSSParser', `解析RSS item失败: ${error}`)
      return null
    }
  }
  
  /**
   * 解析enclosure元素
   */
  private static parseEnclosures(itemElement: Element): RSParsedEnclosure[] {
    const enclosures: RSParsedEnclosure[] = []
    // 1. <enclosure>
    const enclosureElements = itemElement.getElementsByTagName('enclosure')
    for (let i = 0; i < enclosureElements.length; i++) {
      const enclosureElement = enclosureElements[i]
      const url = enclosureElement.getAttribute('url')
      const type = enclosureElement.getAttribute('type')
      const length = enclosureElement.getAttribute('length')
      if (url && type) {
        enclosures.push({
          url: url,
          mimeType: type,
          length: length ? parseInt(length, 10) || 0 : 0
        })
      }
    }
    // 2. <media:content>
    const mediaElements = itemElement.getElementsByTagName('media:content')
    for (let i = 0; i < mediaElements.length; i++) {
      const mediaElement = mediaElements[i]
      const url = mediaElement.getAttribute('url') || mediaElement.getAttribute('url')
      const type = mediaElement.getAttribute('type') || mediaElement.getAttribute('medium') || ''
      const length = mediaElement.getAttribute('fileSize') || mediaElement.getAttribute('length')
      if (url) {
        enclosures.push({
          url: url,
          mimeType: type,
          length: length ? parseInt(length, 10) || 0 : 0
        })
      }
    }
    return enclosures
  }
  
  /**
   * 获取元素的文本内容
   */
  private static getElementText(parentElement: Element, tagName: string): string {
    const elements = parentElement.getElementsByTagName(tagName)
    if (elements.length > 0) {
      return elements[0].textContent || ''
    }
    return ''
  }
  
  /**
   * 生成文章ID（当没有GUID时）
   */
  private static generateArticleID(title: string, link: string, pubDate: string): string {
    const content = `${title}${link}${pubDate}`
    return RSSParser.simpleHash(content)
  }
  
  /**
   * 简单哈希函数
   */
  private static simpleHash(str: string): string {
    let hash = 0
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i)
      hash = ((hash << 5) - hash) + char
      hash = hash & hash
    }
    return Math.abs(hash).toString(16)
  }
  
  /**
   * 解析日期字符串
   */
  private static parseDate(dateString: string): Date | null {
    if (!dateString) {
      return null
    }
    
    const date = new Date(dateString)
    return isNaN(date.getTime()) ? null : date
  }
} 