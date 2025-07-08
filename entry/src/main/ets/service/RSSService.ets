import http from '@ohos.net.http'
import hilog from '@ohos.hilog'
import FeedDAO, { RSSFeedDB, RSSFeedUpdateParams, RSSFeedCreateData } from '../model/FeedDAO'
import ArticleDAO, { RSSArticleDB, RSSArticleCreateData } from '../model/ArticleDAO'
import StatusDAO from '../model/StatusDAO'
import AuthorDAO, { RSSAuthorCreateData } from '../model/AuthorDAO'
import { DatabaseManager } from '../model/DatabaseManager'
import { ImageDAO } from '../model/ImageDAO'
import { UrlHashUtil } from '../utils/UrlHashUtil'
// 使用新的feed解析器体系
import { FeedParser, FeedParserError, FeedParserErrorType } from '../utils/feed/FeedParser'
import { ParserData } from '../utils/feed/ParserData'
import { FeedType, FeedTypeDetector } from '../utils/feed/FeedType'
import { ParsedFeed } from '../utils/feed/ParsedFeed'
import { ParsedItem } from '../utils/feed/ParsedItem'
import { ParsedAuthor } from '../utils/feed/ParsedAuthor'

/**
 * RSS获取结果
 */
export interface RSSFetchResult {
  success: boolean
  error?: string
  newArticleCount?: number
  feedId?: number
}

/**
 * RSS同步选项
 */
export interface RSSSyncOptions {
  timeout?: number // 请求超时时间（毫秒）
  userAgent?: string // User-Agent
  maxRetries?: number // 最大重试次数
  cleanupOldArticles?: boolean // 是否清理旧文章
  keepArticleCount?: number // 保留的文章数量
}

/**
 * 错误处理类型
 */
type ErrorHandler = (error: Error | string) => void

/**
 * RSS服务
 * 负责RSS内容的获取、解析和存储
 */
export class RSSService {
  private static readonly DEFAULT_TIMEOUT = 5000 // 5秒超时
  private static readonly DEFAULT_USER_AGENT = 'HarmonyOS RSS Reader/1.0'
  private static readonly DEFAULT_MAX_RETRIES = 3
  private static readonly DEFAULT_KEEP_ARTICLE_COUNT = 100

  /**
   * 获取并解析单个RSS源
   */
  static async fetchRSSFeed(feedId: number, options: RSSSyncOptions = {}): Promise<RSSFetchResult> {
    try {
      // 获取RSS源信息
      const feed = await FeedDAO.getFeedById(feedId)
      if (!feed) {
        throw new Error(`RSS源不存在: ${feedId}`)
      }

      if (!feed.isActive) {
        return { success: false, error: 'RSS源已禁用' }
      }

      // 获取RSS内容
      const xmlContent = await RSSService.fetchRSSContent(feed.url, options)
      
      // 创建解析器数据包装
      const parserData = ParserData.create(xmlContent, feed.url)

      // 验证内容是否为有效的feed
      if (!FeedParser.canParse(parserData)) {
        throw new Error('获取到的内容不是有效的RSS/Atom feed')
      }

      // 检测feed类型
      const feedType = FeedTypeDetector.detectFeedType(parserData.data)
      
      // 解析RSS内容
      const parseResult = await FeedParser.parse(parserData)
      
      // 更新RSS源信息
      await RSSService.updateFeedInfo(feedId, parseResult)
      
      // 保存文章
      const articles = parseResult.items || []
      const newArticleCount = await RSSService.saveArticles(feedId, articles)
      
      // 清理旧文章（可选）
      if (options.cleanupOldArticles !== false) {
        const keepCount = options.keepArticleCount || RSSService.DEFAULT_KEEP_ARTICLE_COUNT
        await ArticleDAO.cleanupOldArticles(feedId, keepCount)
      }

      // 更新获取状态
      await FeedDAO.updateFeedFetchStatus(feedId, true)

      return {
        success: true,
        feedId,
        newArticleCount
      }

    } catch (error) {
      // 改进错误信息处理
      let errorMsg = 'RSS源获取失败'
      if (error instanceof Error) {
        errorMsg = error.message
      } else if (typeof error === 'string') {
        errorMsg = error
      } else if (error && typeof error === 'object') {
        errorMsg = JSON.stringify(error, null, 2) || '未知对象错误'
      } else {
        errorMsg = String(error) || '未知错误'
      }
      
      hilog.error(0x0000, 'RSSService', `RSS源获取失败: ${feedId}, 错误: ${errorMsg}`)
      
      // 更新错误状态
      await FeedDAO.updateFeedFetchStatus(feedId, false, errorMsg)
      
      return {
        success: false,
        feedId,
        error: errorMsg
      }
    }
  }

  /**
   * 同步所有活跃的RSS源
   */
  static async syncAllFeeds(options: RSSSyncOptions = {}): Promise<RSSFetchResult[]> {
    try {
      // 获取所有活跃的RSS源
      const feeds = await FeedDAO.getAllActiveFeeds()

      const results: RSSFetchResult[] = []

      // 并发获取RSS源（限制并发数）
      const concurrencyLimit = 3
      for (let i = 0; i < feeds.length; i += concurrencyLimit) {
        const batch = feeds.slice(i, i + concurrencyLimit)
        const batchPromises = batch.map(feed => 
          RSSService.fetchRSSFeed(feed.id!, options)
        )
        
        const batchResults = await Promise.allSettled(batchPromises)
        
        for (const result of batchResults) {
          if (result.status === 'fulfilled') {
            results.push(result.value)
          } else {
            hilog.error(0x0000, 'RSSService', `批次同步失败: ${result.reason}`)
            results.push({
              success: false,
              error: result.reason instanceof Error ? result.reason.message : '批次同步失败'
            })
          }
        }

        // 批次间稍作延迟，避免过于频繁的请求
        if (i + concurrencyLimit < feeds.length) {
          await new Promise<void>(resolve => setTimeout(resolve, 1000))
        }
      }

      const successCount = results.filter(r => r.success).length
      const totalNewArticles = results.reduce((sum, r) => sum + (r.newArticleCount || 0), 0)
      
      hilog.info(0x0000, 'RSSService', `RSS同步完成: 成功 ${successCount}/${feeds.length}, 新文章 ${totalNewArticles}篇`)
      return results

    } catch (error) {
      throw new Error('同步所有RSS源失败')
    }
  }

  /**
   * 从网络获取RSS内容
   */
  private static async fetchRSSContent(url: string, options: RSSSyncOptions = {}): Promise<string> {
    const timeout = options.timeout || RSSService.DEFAULT_TIMEOUT
    const userAgent = options.userAgent || RSSService.DEFAULT_USER_AGENT
    const maxRetries = options.maxRetries || RSSService.DEFAULT_MAX_RETRIES

    let lastError: Error | null = null

    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        // 创建HTTP请求
        const httpRequest = http.createHttp()
        
        // 设置请求选项
        const requestOptions: http.HttpRequestOptions = {
          method: http.RequestMethod.GET,
          connectTimeout: timeout,
          readTimeout: timeout,
          header: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'application/rss+xml, application/atom+xml, application/xml, text/xml, */*',
            'Accept-Encoding': 'gzip, deflate',
            'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
            'Cache-Control': 'no-cache',
            'Connection': 'keep-alive'
          }
        }

        // 发送请求
        const response = await httpRequest.request(url, requestOptions)
        
        try {
          // 检查响应状态
          
          if (response.responseCode !== 200) {
            throw new Error(`HTTP错误: ${response.responseCode}`)
          }

          // 获取响应内容
          const xmlContent = response.result as string
          
          if (!xmlContent || xmlContent.trim().length === 0) {
            throw new Error('获取到空的RSS内容')
          }

          // 验证RSS内容
          const parserData = ParserData.create(xmlContent, url)
          const canParse = FeedParser.canParse(parserData)
          
          if (!canParse) {
            throw new Error('不支持的RSS内容格式')
          }

          return xmlContent

        } finally {
          // 确保释放HTTP连接
          httpRequest.destroy()
        }

      } catch (error) {
        lastError = error instanceof Error ? error : new Error(String(error))
        // 如果不是最后一次尝试，等待后重试
        if (attempt < maxRetries) {
          const delay = attempt * 2000 // 递增延迟
          await new Promise<void>(resolve => setTimeout(resolve, delay))
        }
      }
    }

    // 所有尝试都失败了
    throw lastError || new Error('RSS内容获取失败')
  }

  /**
   * 更新RSS源信息
   */
  private static async updateFeedInfo(feedId: number, feedInfo: ParsedFeed): Promise<void> {
    try {
      const updateParams: RSSFeedUpdateParams = {
        title: feedInfo.title,
        description: feedInfo.description,
        link: feedInfo.link,
        imageUrl: feedInfo.imageUrl
      }
      await FeedDAO.updateFeed(feedId, updateParams)
    } catch (error) {
      // 静默处理更新失败
    }
  }

  /**
   * 保存文章到数据库
   */
  private static async saveArticles(feedID: number, items: ParsedItem[]): Promise<number> {
    if (items.length === 0) {
      return 0
    }
    
    // 检查数据库是否初始化
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }
    
    // 验证数据库状态
    const dbStatus = await DatabaseManager.checkDatabaseStatus()
    if (!dbStatus) {
      throw new Error('数据库状态异常')
    }

    try {
      let newArticleCount = 0
      let skipCount = 0

      // 逐个保存文章
      for (let i = 0; i < items.length; i++) {
        const item = items[i]
        try {
          // 生成articleID - 使用时间戳和随机数确保唯一性
          const timestamp = Date.now()
          const random = Math.floor(Math.random() * 1000)
          const articleID = `${feedID}_${item.uniqueID || timestamp}_${random}`
          
          const articleData: RSSArticleCreateData = {
            articleID: articleID,
            feedID: feedID,
            uniqueID: item.uniqueID || `${timestamp}_${random}`,
            title: item.title || '',
            contentHTML: item.contentHTML || '',
            contentText: item.contentText || RSSService.stripHtml(item.contentHTML || item.summary || ''),
            url: item.url || '',
            externalURL: item.externalURL || '',
            summary: item.summary || '',
            imageURL: item.imageURL || '',
            bannerImageURL: item.bannerImageURL || '',
            datePublished: item.datePublished ? item.datePublished.toISOString() : '',
            dateModified: item.dateModified ? item.dateModified.toISOString() : (item.datePublished ? item.datePublished.toISOString() : ''),
            language: item.language || ''
          }
          
          const success = await ArticleDAO.addArticle(articleData)
          if (success) {
            newArticleCount++
            
            // 处理作者信息
            if (item.authors && item.authors.length > 0) {
              await RSSService.saveAuthors(articleID, item.authors)
            }

            // 提取并保存图片 URL
            try {
              const imgUrls = RSSService.extractImageUrls(item)
              for (const imgUrl of imgUrls) {
                const imageID = UrlHashUtil.generateImageId(imgUrl)
                await ImageDAO.saveOrUpdateImage({
                  articleID: articleID,
                  imageID: imageID,
                  url: imgUrl,
                  localPath: '' // 初始为空，下载后填充
                })
              }
            } catch (imgErr) {
              hilog.warn(0x0000, 'RSSService', `提取图片失败: %{public}s`, JSON.stringify(imgErr) ?? '')
            }
          } else {
            skipCount++
          }
        } catch (error) {
          // 跳过重复或有问题的文章
          skipCount++
        }
      }

      return newArticleCount

    } catch (error) {
      return 0
    }
  }

  /**
   * 提取文章中的图片 URL
   */
  private static extractImageUrls(item: ParsedItem): string[] {
    const urls: Set<string> = new Set<string>()

    // 直接字段
    if (item.imageURL) {
      urls.add(item.imageURL)
    }
    if (item.bannerImageURL) {
      urls.add(item.bannerImageURL)
    }

    // 从 contentHTML / summary 中提取 <img src="...">
    const htmlSources: string[] = []
    if (item.contentHTML) htmlSources.push(item.contentHTML)
    if (item.summary) htmlSources.push(item.summary)

    const imgRegex = /<img[^>]+src=["']([^"'>]+)["'][^>]*>/gi

    for (const html of htmlSources) {
      let match: RegExpExecArray | null
      imgRegex.lastIndex = 0
      while ((match = imgRegex.exec(html)) !== null) {
        if (match[1]) {
          urls.add(match[1])
        }
      }
    }

    return Array.from(urls)
  }

  /**
   * 保存作者信息
   */
  private static async saveAuthors(articleID: string, authors: ParsedAuthor[]): Promise<void> {
    try {
      for (const author of authors) {
        const authorID = `${author.name}_${author.emailAddress || Date.now()}`
        
        const authorData: RSSAuthorCreateData = {
          authorID: authorID,
          name: author.name || '',
          url: author.url || '',
          avatarURL: author.avatarURL || '',
          emailAddress: author.emailAddress || ''
        }

        // 添加作者（如果已存在会跳过）
        await AuthorDAO.addAuthor(authorData)
        
        // 关联作者和文章
        await AuthorDAO.linkAuthorToArticle(authorID, articleID)
      }
    } catch (error) {
      // 静默处理作者信息保存失败
    }
  }

  /**
   * 去除HTML标签
   */
  private static stripHtml(html: string): string {
    if (!html) return ''
    return html.replace(/<[^>]*>/g, '').trim()
  }

  /**
   * 添加新的RSS源
   */
  static async addRSSFeed(url: string): Promise<RSSFetchResult> {
    try {
      // 检查URL是否已存在
      const existingFeed = await FeedDAO.getFeedByUrl(url)
      if (existingFeed) {
        return {
          success: false,
          error: 'RSS源已存在'
        }
      }

      // 获取RSS内容进行验证，设置5秒超时
      const xmlContent = await RSSService.fetchRSSContent(url, { timeout: 5000 })
      
      // 创建解析器数据包装
      const parserData = ParserData.create(xmlContent, url)
      
      // 解析RSS内容
      const parseResult = await FeedParser.parse(parserData)
      
      // 创建RSS源数据
      const feedData: RSSFeedCreateData = {
        url: url,
        title: parseResult.title || '未知RSS源',
        description: parseResult.description || '',
        link: parseResult.link || '',
        language: '',
        lastBuildDate: '',
        imageUrl: parseResult.imageUrl || '',
        category: '自定义',
        isActive: true,
        sortOrder: 999
      }

      // 保存RSS源
      const feedSaved = await FeedDAO.addFeed(feedData)
      
      if (!feedSaved) {
        return {
          success: false,
          error: 'RSS源保存失败'
        }
      }
      
      // 获取新创建的RSS源ID
      const newFeed = await FeedDAO.getFeedByUrl(url)
      const newFeedId = newFeed ? newFeed.id! : 1
      
      // 保存文章
      const articles = parseResult.items || []
      const newArticleCount = await RSSService.saveArticles(newFeedId, articles)

      return {
        success: true,
        newArticleCount: newArticleCount
      }

    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : '未知错误'
      
      return {
        success: false,
        error: errorMsg
      }
    }
  }

  /**
   * 测试RSS源连接
   */
  static async testRSSFeed(url: string): Promise<RSSTestResult> {
    try {
      // 获取RSS内容，设置5秒超时
      const xmlContent = await RSSService.fetchRSSContent(url, { timeout: 5000 })
      
      // 创建解析器数据包装
      const parserData = ParserData.create(xmlContent, url)
      
      // 解析RSS内容
      const parseResult = await FeedParser.parse(parserData)
      
      return {
        success: true,
        title: parseResult.title || '未知RSS源'
      }

    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : '未知错误'
      
      return {
        success: false,
        error: errorMsg
      }
    }
  }

  /**
   * 更新RSS源和文章
   */
  static async updateFeedAndArticles(feedId: number, options: RSSSyncOptions = {}): Promise<RSSFetchResult> {
    return await RSSService.fetchRSSFeed(feedId, options)
  }

  /**
   * 测试网络连接和RSS获取（用于调试）
   */
  static async testRSSConnection(): Promise<void> {
    try {
      // 测试一个简单的RSS地址
      const testUrl = 'https://www.ruanyifeng.com/blog/atom.xml'
      const testOptions: RSSSyncOptions = { timeout: 10000 }
      const xmlContent = await RSSService.fetchRSSContent(testUrl, testOptions)
      
      // 测试解析
      const parserData = ParserData.create(xmlContent, testUrl)
      const parseResult = await FeedParser.parse(parserData)
      
    } catch (error) {
      throw new Error(error instanceof Error ? error.message : '测试失败')
    }
  }

  /**
   * 获取RSS源统计信息
   */
  static async getRSSStatistics(): Promise<RSSStatistics> {
    try {
      const allFeeds = await FeedDAO.getAllActiveFeeds()
      const totalFeeds = allFeeds.length
      const activeFeeds = allFeeds.filter(feed => feed.isActive).length
      
      const totalArticles = (await ArticleDAO.getArticles()).length
      const unreadArticles = await StatusDAO.getUnreadCount()

      return {
        totalFeeds: totalFeeds,
        activeFeeds: activeFeeds,
        totalArticles: totalArticles,
        unreadArticles: unreadArticles
      }
    } catch (error) {
      return {
        totalFeeds: 0,
        activeFeeds: 0,
        totalArticles: 0,
        unreadArticles: 0
      }
    }
  }

  /**
   * 获取RSS源的备用URL列表
   */
  private static getAlternativeRSSUrls(originalUrl: string): string[] {
    const alternatives: string[] = []
    
    // 通用的URL变体
    if (originalUrl.endsWith('/feed')) {
      alternatives.push(originalUrl + '/')
      alternatives.push(originalUrl.replace('/feed', '/rss.xml'))
      alternatives.push(originalUrl.replace('/feed', '/index.xml'))
    }
    
    // HTTPS到HTTP的降级
    if (originalUrl.startsWith('https://')) {
      alternatives.push(originalUrl.replace('https://', 'http://'))
    }
    
    return alternatives.filter(alt => alt !== originalUrl)
  }

  /**
   * 尝试备用URL获取RSS内容
   */
  private static async tryAlternativeUrls(originalUrl: string, options: RSSSyncOptions): Promise<string> {
    const alternativeUrls = RSSService.getAlternativeRSSUrls(originalUrl)
    
    for (const altUrl of alternativeUrls) {
      try {
        return await RSSService.fetchRSSContent(altUrl, options)
      } catch (error) {
        continue
      }
    }
    
    throw new Error(`所有备用URL都失败了，原始URL: ${originalUrl}`)
  }
}

interface RSSTestResult {
  success: boolean
  title?: string
  error?: string
}

interface RSSStatistics {
  totalFeeds: number
  activeFeeds: number
  totalArticles: number
  unreadArticles: number
}

export default RSSService 