import { FeedType } from '../FeedType'
import { ParsedFeed } from '../ParsedFeed'
import { ParsedItem } from '../ParsedItem'
import { ParsedAuthor } from '../ParsedAuthor'
import { ParsedAttachment } from '../ParsedAttachment'
import { RSParsedFeed, RSParsedArticle, RSParsedAuthor, RSParsedEnclosure } from './RSSParser'

/**
 * RSS解析结果转换器
 * 将RSS和Atom解析器产生的中间结果转换为统一的ParsedFeed格式
 * 
 * 这个转换器的作用是为RSS和Atom解析器提供统一的输出格式，
 * 使得所有解析器都能返回相同的数据结构
 */
export class RSParsedFeedTransformer {
  
  /**
   * 将RSParsedFeed转换为ParsedFeed
   */
  static parsedFeed(rsParsedFeed: RSParsedFeed): ParsedFeed {
    
    const items = RSParsedFeedTransformer.parsedItems(rsParsedFeed.articles)
    
    
    return {
      type: FeedType.RSS, // 默认为RSS类型，Atom也会被标记为RSS
      title: rsParsedFeed.title || '',
      homePageURL: rsParsedFeed.link || '',
      feedURL: rsParsedFeed.urlString || '',
      language: rsParsedFeed.language || '',
      feedDescription: rsParsedFeed.description || '',
      nextURL: '',
      iconURL: rsParsedFeed.iconUrl || '',
      faviconURL: '',
      authors: [],
      expired: false,
      hubs: [],
      lastBuildDate: rsParsedFeed.lastBuildDate || undefined,
      ttl: rsParsedFeed.ttl || undefined,
      // 向后兼容字段
      description: rsParsedFeed.description || '',
      link: rsParsedFeed.link || '',
      imageUrl: rsParsedFeed.iconUrl || '',
      // 修复：添加缺失的items字段
      items: items
    }
  }
  
  /**
   * 将RSParsedArticle数组转换为ParsedItem数组
   */
  private static parsedItems(parsedArticles: RSParsedArticle[]): ParsedItem[] {
    return parsedArticles.map(article => RSParsedFeedTransformer.parsedItem(article))
  }
  
  /**
   * 将RSParsedArticle转换为ParsedItem
   */
  private static parsedItem(parsedArticle: RSParsedArticle): ParsedItem {
    const uniqueID = parsedArticle.articleID
    const url = parsedArticle.permalink
    const externalURL = parsedArticle.link
    const title = parsedArticle.title
    const language = parsedArticle.language
    const contentHTML = parsedArticle.body
    const datePublished = parsedArticle.datePublished
    const dateModified = parsedArticle.dateModified
    const authors = RSParsedFeedTransformer.parsedAuthors(parsedArticle.authors)
    const attachments = RSParsedFeedTransformer.parsedAttachments(parsedArticle.enclosures)
    const tags = parsedArticle.tags || []
    
    const item = new ParsedItem(uniqueID, parsedArticle.link || '')
    item.syncServiceID = ''
    item.url = url
    item.externalURL = externalURL
    item.title = title
    item.language = language
    item.contentHTML = contentHTML
    item.contentText = contentHTML || '' // 使用HTML内容作为文本内容
    item.summary = contentHTML || '' // 使用HTML内容作为摘要
    item.imageURL = ''
    item.bannerImageURL = ''
    item.datePublished = datePublished || undefined
    item.dateModified = dateModified || undefined
    item.authors = authors
    item.tags = tags
    item.attachments = attachments
    
    return item
  }
  
  /**
   * 将RSParsedAuthor数组转换为ParsedAuthor数组
   */
  private static parsedAuthors(authors: RSParsedAuthor[]): ParsedAuthor[] {
    if (!authors || authors.length === 0) {
      return []
    }
    
    const transformedAuthors: ParsedAuthor[] = []
    
    for (const author of authors) {
      const parsedAuthor: ParsedAuthor = {
        name: author.name || '',
        url: author.url || '',
        avatarURL: '',
        emailAddress: author.emailAddress || ''
      }
      transformedAuthors.push(parsedAuthor)
    }
    
    return transformedAuthors
  }
  
  /**
   * 将RSParsedEnclosure数组转换为ParsedAttachment数组
   */
  private static parsedAttachments(enclosures: RSParsedEnclosure[]): ParsedAttachment[] {
    if (!enclosures || enclosures.length === 0) {
      return []
    }
    
    const attachments: ParsedAttachment[] = []
    
    for (const enclosure of enclosures) {
      const sizeInBytes = enclosure.length > 0 ? enclosure.length : undefined
      
      const attachment: ParsedAttachment = {
        url: enclosure.url,
        mimeType: enclosure.mimeType || '',
        title: '',
        sizeInBytes: sizeInBytes,
        durationInSeconds: undefined
      }
      attachments.push(attachment)
    }
    
    return attachments
  }
} 