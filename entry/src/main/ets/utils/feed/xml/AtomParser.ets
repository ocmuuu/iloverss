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
import { RSParsedFeed, RSParsedArticle, RSParsedAuthor, RSParsedEnclosure } from './RSSParser'

/**
 * Atom XML解析器
 * 包装XML解析功能，提供与其他解析器一致的接口
 */
export class AtomParser {
  
  /**
   * 解析Atom XML数据
   */
  static parse(parserData: ParserData): ParsedFeed | null {
    try {
      const rsParsedFeed = AtomParser.parseAtomXML(parserData)
      if (rsParsedFeed) {
        return RSParsedFeedTransformer.parsedFeed(rsParsedFeed)
      }
      return null
    } catch (error) {
      hilog.error(0x0000, 'AtomParser', `Atom解析失败: ${error}`)
      return null
    }
  }
  
  /**
   * 解析Atom XML内容
   */
  private static parseAtomXML(parserData: ParserData): RSParsedFeed | null {
    try {
      const xmlDoc = XMLParser.parse(parserData.data)
      
      // 查找feed根元素
      const feedElement = xmlDoc.getElementsByTagName('feed')[0]
      if (!feedElement) {
        throw new FeedParserError(FeedParserErrorType.RSS_CHANNEL_NOT_FOUND, 'Atom feed根元素未找到', parserData.url)
      }
      
      // 解析feed信息
      const title = AtomParser.getElementText(feedElement, 'title')
      const subtitle = AtomParser.getElementText(feedElement, 'subtitle')
      
      // 查找link元素（可能有多个）
      const link = AtomParser.getFeedLink(feedElement)
      
      // 解析entry列表
      const entryElements = feedElement.getElementsByTagName('entry')
      
      const articles: RSParsedArticle[] = []
      
      for (let i = 0; i < entryElements.length; i++) {
        const entryElement = entryElements[i]
        
        const article = AtomParser.parseAtomEntry(entryElement, parserData.url)
        if (article) {
          articles.push(article)
        } else {
          hilog.warn(0x0000, 'AtomParser', `entry解析失败: ${i + 1}`)
        }
      }
            
      return {
        title: title,
        link: link,
        urlString: parserData.url,
        language: '',
        description: subtitle,
        articles: articles
      }
      
    } catch (error) {
      hilog.error(0x0000, 'AtomParser', `Atom XML解析失败: ${error}`)
      return null
    }
  }
  
  /**
   * 解析Atom entry元素
   */
  private static parseAtomEntry(entryElement: Element, feedURL: string): RSParsedArticle | null {
    try {
      const title = AtomParser.getElementText(entryElement, 'title')
      const id = AtomParser.getElementText(entryElement, 'id')
      const published = AtomParser.getElementText(entryElement, 'published')
      const updated = AtomParser.getElementText(entryElement, 'updated')
      
      // 获取内容
      const content = AtomParser.getAtomContent(entryElement)
      
      // 获取链接
      const link = AtomParser.getEntryLink(entryElement)
      
      // 生成文章ID
      const articleID = id || AtomParser.generateArticleID(title, link, published)
      
      // 解析日期
      const datePublished = published ? AtomParser.parseDate(published) : null
      const dateModified = updated ? AtomParser.parseDate(updated) : null
      
      // 解析作者
      const authors = AtomParser.parseAtomAuthors(entryElement)
      
      // 解析附件（link rel="enclosure"）
      const enclosures = AtomParser.parseAtomEnclosures(entryElement)
      
      
      return {
        articleID: articleID,
        permalink: link,
        link: link,
        title: title,
        language: '',
        body: content,
        datePublished: datePublished,
        dateModified: dateModified,
        authors: authors,
        enclosures: enclosures,
        tags: []
      }
      
    } catch (error) {
      hilog.warn(0x0000, 'AtomParser', `解析Atom entry失败: ${error}`)
      return null
    }
  }
  
  /**
   * 获取feed的链接
   */
  private static getFeedLink(feedElement: Element): string {
    const linkElements = feedElement.getElementsByTagName('link')
    
    // 优先查找 rel="alternate" 的链接
    for (let i = 0; i < linkElements.length; i++) {
      const linkElement = linkElements[i]
      const rel = linkElement.getAttribute('rel')
      const href = linkElement.getAttribute('href')
      
      if (rel === 'alternate' && href) {
        return href
      }
    }
    
    // 如果没有找到，返回第一个有href的链接
    for (let i = 0; i < linkElements.length; i++) {
      const linkElement = linkElements[i]
      const href = linkElement.getAttribute('href')
      if (href) {
        return href
      }
    }
    
    return ''
  }
  
  /**
   * 获取entry的链接
   */
  private static getEntryLink(entryElement: Element): string {
    const linkElements = entryElement.getElementsByTagName('link')
    
    // 优先查找 rel="alternate" 的链接
    for (let i = 0; i < linkElements.length; i++) {
      const linkElement = linkElements[i]
      const rel = linkElement.getAttribute('rel')
      const href = linkElement.getAttribute('href')
      
      if (rel === 'alternate' && href) {
        return href
      }
    }
    
    // 如果没有找到，返回第一个有href的链接
    for (let i = 0; i < linkElements.length; i++) {
      const linkElement = linkElements[i]
      const href = linkElement.getAttribute('href')
      if (href) {
        return href
      }
    }
    
    return ''
  }
  
  /**
   * 将包含多个CDATA段的原始字符串合并，并去除包裹标记
   */
  private static joinCDATA(raw: string): string {
    if (!raw) {
      return ''
    }
    // 删除 <![CDATA[ 和 ]]> 标记，然后去掉首尾空白
    return raw.replace(/<!\[CDATA\[/g, '').replace(/\]\]>/g, '').trim()
  }
  
  /**
   * 获取Atom内容
   */
  private static getAtomContent(entryElement: Element): string {
    // 优先查找content元素
    const contentElement = entryElement.getElementsByTagName('content')[0]
    if (contentElement) {
      const raw = contentElement.textContent || ''
      const joined = AtomParser.joinCDATA(raw)
      if (joined) {
        return joined
      }
      // 如果join后仍为空，尝试序列化其子元素
      if (contentElement.children.length > 0) {
        return contentElement.children.map(child => AtomParser.serializeElement(child)).join('')
      }
    }
    // 如果没有content，或content为空，查找summary
    const summaryElement = entryElement.getElementsByTagName('summary')[0]
    if (summaryElement) {
      const raw = summaryElement.textContent || ''
      return AtomParser.joinCDATA(raw)
    }
    return ''
  }
  
  /**
   * 将 Element 序列化为 HTML 字符串（递归）
   */
  private static serializeElement(el: Element): string {
    // 序列化属性
    const attrs = Object.keys(el.attributes)
      .map(key => `${key}="${el.attributes[key]}"`) 
      .join(' ')
    const openTag = attrs.length > 0 ? `<${el.tagName} ${attrs}>` : `<${el.tagName}>`
    const innerText = el.textContent || ''
    const childrenHTML = el.children.map(child => AtomParser.serializeElement(child)).join('')
    return `${openTag}${innerText}${childrenHTML}</${el.tagName}>`
  }
  
  /**
   * 解析Atom作者信息
   */
  private static parseAtomAuthors(entryElement: Element): RSParsedAuthor[] {
    const authors: RSParsedAuthor[] = []
    const authorElements = entryElement.getElementsByTagName('author')
    
    for (let i = 0; i < authorElements.length; i++) {
      const authorElement = authorElements[i]
      const name = AtomParser.getElementText(authorElement, 'name')
      const email = AtomParser.getElementText(authorElement, 'email')
      const uri = AtomParser.getElementText(authorElement, 'uri')
      
      authors.push({
        name: name,
        url: uri,
        emailAddress: email
      })
    }
    
    return authors
  }
  
  /**
   * 解析Atom附件（enclosure类型的链接）
   */
  private static parseAtomEnclosures(entryElement: Element): RSParsedEnclosure[] {
    const enclosures: RSParsedEnclosure[] = []
    const linkElements = entryElement.getElementsByTagName('link')
    
    for (let i = 0; i < linkElements.length; i++) {
      const linkElement = linkElements[i]
      const rel = linkElement.getAttribute('rel')
      
      if (rel === 'enclosure') {
        const href = linkElement.getAttribute('href')
        const type = linkElement.getAttribute('type')
        const length = linkElement.getAttribute('length')
        
        if (href && type) {
          enclosures.push({
            url: href,
            mimeType: type,
            length: length ? parseInt(length, 10) || 0 : 0
          })
        }
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
   * 生成文章ID（当没有ID时）
   */
  private static generateArticleID(title: string, link: string, published: string): string {
    const content = `${title}${link}${published}`
    return AtomParser.simpleHash(content)
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