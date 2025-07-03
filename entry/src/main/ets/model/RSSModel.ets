/**
 * RSS阅读器数据模型
 */
import FeedDAO, { RSSFeedDB } from './FeedDAO'
import ArticleDAO, { RSSArticleDB, RSSArticleDBExtended } from './ArticleDAO'
import StatusDAO from './StatusDAO'
import FolderDAO, { RSSFolderDB } from './FolderDAO'
import hilog from '@ohos.hilog'

// RSS文件夹数据结构（前端使用）
export interface RSSFolder {
  id: string
  name: string
  description: string
  icon: string
  color: string
  sortOrder: number
  isActive: boolean
  unreadCount: number
  feedCount: number
}

// RSS订阅源数据结构（前端使用）
export interface RSSFeed {
  id: string
  folderId: string | null // 添加文件夹ID
  title: string
  description: string
  url: string
  favicon?: Resource
  faviconPath?: string  // 本地下载的favicon路径
  unreadCount: number
}

// RSS文章数据结构（前端使用）
export interface RSSArticle {
  id: string
  feedId: string
  title: string
  summary: string
  content: string
  author: string
  publishDate: string
  readStatus: boolean
  starredStatus: boolean // 收藏状态
  link: string
}

// Mock数据定义 - 提前定义避免循环引用
export const mockRSSFeeds: RSSFeed[] = [
  {
    id: "1",
    folderId: null,
    title: "阮一峰的网络日志",
    description: "阮一峰的个人博客，分享技术和思考",
    url: "https://www.ruanyifeng.com/blog/atom.xml",
    favicon: $r("app.media.rss"),
    unreadCount: 0
  },
  {
    id: "2", 
    folderId: null,
    title: "少数派",
    description: "致力于更好地运用数字产品或科学方法，帮助用户提升工作效率和生活品质",
    url: "https://sspai.com/feed",
    favicon: $r("app.media.rss"),
    unreadCount: 0
  }
]

export const mockRSSArticles: RSSArticle[] = [
  {
    id: "1",
    feedId: "1",
    title: "今天的技术文章 - HarmonyOS新特性介绍",
    summary: "本文介绍了HarmonyOS最新版本的一些新特性和改进...",
    content: "HarmonyOS作为华为推出的分布式操作系统，在最新版本中引入了许多令人兴奋的新特性...",
    author: "技术作者",
    publishDate: new Date().toISOString(), // 今天的文章
    readStatus: false,
    starredStatus: false,
    link: "https://example.com/today-article-1"
  },
  {
    id: "2", 
    feedId: "1",
    title: "今天的开发教程 - ArkTS编程进阶",
    summary: "深入学习ArkTS语言的高级特性和最佳实践...",
    content: "ArkTS是HarmonyOS应用开发的主要编程语言，本文将带你深入了解其高级特性...",
    author: "开发专家",
    publishDate: new Date().toISOString(), // 今天的文章
    readStatus: false,
    starredStatus: false,
    link: "https://example.com/today-article-2"
  },
  {
    id: "3",
    feedId: "1", 
    title: "昨天的新闻 - 移动应用开发趋势",
    summary: "分析当前移动应用开发的最新趋势和技术方向...",
    content: "移动应用开发领域正在经历快速的变化，本文分析了当前的技术趋势...",
    author: "行业分析师", 
    publishDate: new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString(), // 昨天的文章
    readStatus: true,
    starredStatus: false,
    link: "https://example.com/yesterday-article"
  },
  {
    id: "4",
    feedId: "2",
    title: "今天的效率工具推荐", 
    summary: "推荐几款提高工作效率的实用工具...",
    content: "在快节奏的工作环境中，选择合适的效率工具可以大大提升我们的工作效率...",
    author: "效率专家",
    publishDate: new Date().toISOString(), // 今天的文章
    readStatus: false,
    starredStatus: false,
    link: "https://example.com/today-tools"
  },
  {
    id: "5",
    feedId: "2",
    title: "数字产品使用心得分享",
    summary: "分享一些数字产品的使用经验和技巧...", 
    content: "作为数字产品的重度用户，我想分享一些实用的使用技巧和心得...",
    author: "产品体验师",
    publishDate: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toISOString(), // 前天的文章
    readStatus: true,
    starredStatus: false,
    link: "https://example.com/product-tips"
  },
  {
    id: "6",
    feedId: "1",
    title: "未读的技术新闻",
    summary: "最新的技术行业动态和新闻汇总...",
    content: "本周技术行业发生了许多重要事件，让我们来一起回顾...", 
    author: "新闻编辑",
    publishDate: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000).toISOString(), // 3天前的文章
    readStatus: false,
    starredStatus: false,
    link: "https://example.com/tech-news"
  }
]

/**
 * 数据库到前端模型的转换器
 */
export class RSSModelConverter {
  
  /**
   * 将数据库RSS源转换为前端模型
   */
  static dbFeedToFeed(dbFeed: RSSFeedDB): RSSFeed {
    return {
      id: dbFeed.id?.toString() || '',
      folderId: dbFeed.folderId?.toString() || null,
      title: dbFeed.title || '未知RSS源',
      description: dbFeed.description || '',
      url: dbFeed.url || '',
      favicon: $r("app.media.rss"), // 默认图标
      faviconPath: dbFeed.faviconPath || '',
      unreadCount: 0 // 需要单独查询
    }
  }

  /**
   * 将数据库文件夹转换为前端模型
   */
  static dbFolderToFolder(dbFolder: RSSFolderDB): RSSFolder {
    return {
      id: dbFolder.id?.toString() || '',
      name: dbFolder.name || '未命名文件夹',
      description: dbFolder.description || '',
      icon: dbFolder.icon || '',
      color: dbFolder.color || '',
      sortOrder: dbFolder.sortOrder || 0,
      isActive: dbFolder.isActive || false,
      unreadCount: 0, // 需要单独查询
      feedCount: 0 // 需要单独查询
    }
  }

  /**
   * 将数据库文章转换为前端模型
   */
  static dbArticleToArticle(dbArticle: RSSArticleDBExtended): RSSArticle {
    return {
      id: dbArticle.articleID || '',
      feedId: dbArticle.feedID?.toString() || '',
      title: dbArticle.title || '无标题',
      summary: dbArticle.summary || '',
      content: dbArticle.contentHTML || dbArticle.summary || '',
      author: dbArticle.authorName || '', // 从扩展字段获取作者信息
      publishDate: RSSModelConverter.formatDate(dbArticle.datePublished || ''),
      readStatus: (dbArticle.read === 1) || false, // 从状态表获取已读状态
      starredStatus: (dbArticle.starred === 1) || false, // 从状态表获取收藏状态
      link: dbArticle.url || ''
    }
  }

  /**
   * 格式化日期
   */
  private static formatDate(dateStr: string): string {
    if (!dateStr) {
      return new Date().toLocaleString('zh-CN')
    }
    
    try {
      const date = new Date(dateStr)
      return date.toLocaleString('zh-CN')
    } catch (error) {
      return dateStr
    }
  }

  /**
   * 批量转换RSS源
   */
  static dbFeedsToFeeds(dbFeeds: RSSFeedDB[]): RSSFeed[] {
    return dbFeeds.map(feed => RSSModelConverter.dbFeedToFeed(feed))
  }

  /**
   * 批量转换文件夹
   */
  static dbFoldersToFolders(dbFolders: RSSFolderDB[]): RSSFolder[] {
    return dbFolders.map(folder => RSSModelConverter.dbFolderToFolder(folder))
  }

  /**
   * 批量转换文章
   */
  static dbArticlesToArticles(dbArticles: RSSArticleDBExtended[]): RSSArticle[] {
    return dbArticles.map(article => RSSModelConverter.dbArticleToArticle(article))
  }
}

/**
 * RSS数据服务
 * 提供统一的数据访问接口，兼容原有mock数据接口
 */
export class RSSDataService {
  
  /**
   * 获取所有RSS源
   */
  static async getAllFeeds(): Promise<RSSFeed[]> {
    try {
      const dbFeeds = await FeedDAO.getAllActiveFeeds()
      const feeds = RSSModelConverter.dbFeedsToFeeds(dbFeeds)
      
      // 为每个RSS源获取未读文章数
      for (const feed of feeds) {
        try {
          feed.unreadCount = await ArticleDAO.getUnreadCount(parseInt(feed.id))
        } catch (error) {
          hilog.warn(0x0000, 'RSSDataService', `获取RSS源${feed.id}未读数失败`)
          feed.unreadCount = 0
        }
      }
      
      return feeds
    } catch (error) {
      hilog.error(0x0000, 'RSSDataService', '获取RSS源列表失败，使用mock数据: %{public}s', JSON.stringify(error) ?? '')
      return mockRSSFeeds // 降级到mock数据
    }
  }

  /**
   * 获取所有文件夹
   */
  static async getAllFolders(): Promise<RSSFolder[]> {
    try {
      const dbFolders = await FolderDAO.getAllFolders()
      const folders = RSSModelConverter.dbFoldersToFolders(dbFolders)
      
      // 为每个文件夹获取未读文章数和订阅源数量
      for (const folder of folders) {
        try {
          folder.feedCount = await FolderDAO.getFeedCount(parseInt(folder.id))
          
          // 获取文件夹下所有订阅源的未读文章数
          const feeds = await FeedDAO.getFeedsByFolderId(parseInt(folder.id))
          let totalUnread = 0
          for (const feed of feeds) {
            const unreadCount = await ArticleDAO.getUnreadCount(feed.id)
            totalUnread += unreadCount
          }
          folder.unreadCount = totalUnread
        } catch (error) {
          hilog.warn(0x0000, 'RSSDataService', `获取文件夹${folder.id}统计信息失败`)
          folder.feedCount = 0
          folder.unreadCount = 0
        }
      }
      
      return folders
    } catch (error) {
      hilog.error(0x0000, 'RSSDataService', '获取文件夹列表失败: %{public}s', JSON.stringify(error) ?? '')
      return []
    }
  }

  /**
   * 获取指定文件夹下的RSS源
   */
  static async getFeedsByFolderId(folderId: string | null): Promise<RSSFeed[]> {
    try {
      const folderIdNum = folderId ? parseInt(folderId) : null
      const dbFeeds = await FeedDAO.getFeedsByFolderId(folderIdNum)
      const feeds = RSSModelConverter.dbFeedsToFeeds(dbFeeds)
      
      // 为每个RSS源获取未读文章数
      for (const feed of feeds) {
        try {
          feed.unreadCount = await ArticleDAO.getUnreadCount(parseInt(feed.id))
        } catch (error) {
          hilog.warn(0x0000, 'RSSDataService', `获取RSS源${feed.id}未读数失败`)
          feed.unreadCount = 0
        }
      }
      
      return feeds
    } catch (error) {
      hilog.error(0x0000, 'RSSDataService', `获取文件夹${folderId}的RSS源失败: %{public}s`, JSON.stringify(error) ?? '')
      return []
    }
  }

  /**
   * 创建新文件夹
   */
  static async createFolder(name: string, description?: string, color?: string): Promise<boolean> {
    try {
      const folderId = await FolderDAO.createFolder({
        name,
        description,
        color
      })
      hilog.info(0x0000, 'RSSDataService', `文件夹创建成功: ${folderId}`)
      return true
    } catch (error) {
      hilog.error(0x0000, 'RSSDataService', '创建文件夹失败: %{public}s', JSON.stringify(error) ?? '')
      return false
    }
  }

  /**
   * 将RSS源移动到指定文件夹
   */
  static async moveFeedToFolder(feedId: string, folderId: string | null): Promise<boolean> {
    try {
      const folderIdNum = folderId ? parseInt(folderId) : null
      return await FeedDAO.moveFeedToFolder(parseInt(feedId), folderIdNum)
    } catch (error) {
      hilog.error(0x0000, 'RSSDataService', '移动RSS源到文件夹失败: %{public}s', JSON.stringify(error) ?? '')
      return false
    }
  }

  /**
   * 根据RSS源ID获取文章列表
   */
  static async getArticlesByFeedId(feedId: string): Promise<RSSArticle[]> {
    try {
      
      // 使用ArticleDAO.getArticles来获取包含状态和作者信息的文章
      const dbArticles = await ArticleDAO.getArticles({
        feedID: parseInt(feedId),
        limit: 50,
        orderBy: 'datePublished',
        sortOrder: 'DESC'
      })
      
      
      const articles = RSSModelConverter.dbArticlesToArticles(dbArticles)
      
      return articles
    } catch (error) {
      hilog.error(0x0000, 'RSSDataService', `获取RSS源${feedId}文章失败，使用mock数据: %{public}s`, JSON.stringify(error) ?? '')
      console.error('RSSDataService', `获取RSS源${feedId}文章失败: ${JSON.stringify(error)}`)
      return mockRSSArticles.filter(article => article.feedId === feedId) // 降级到mock数据
    }
  }

  /**
   * 获取所有文章
   */
  static async getAllArticles(): Promise<RSSArticle[]> {
    try {
      const dbArticles = await ArticleDAO.getArticles()
      return RSSModelConverter.dbArticlesToArticles(dbArticles)
    } catch (error) {
      hilog.error(0x0000, 'RSSDataService', `获取所有文章失败: %{public}s`, JSON.stringify(error) ?? '')
      return mockRSSArticles // 降级到mock数据
    }
  }

  /**
   * 获取今天发布的文章
   */
  static async getTodayArticles(): Promise<RSSArticle[]> {
    try {
      const today = new Date()
      const todayStart = new Date(today.getFullYear(), today.getMonth(), today.getDate())
      
      
      const dbArticles = await ArticleDAO.getArticles({
        dateFrom: todayStart.toISOString(),
        orderBy: 'datePublished',
        sortOrder: 'DESC'
      })
      
      const articles = RSSModelConverter.dbArticlesToArticles(dbArticles)
      
      return articles
    } catch (error) {
      hilog.error(0x0000, 'RSSDataService', `获取今天文章失败: %{public}s`, JSON.stringify(error) ?? '')
      console.error('RSSDataService', '获取今天文章失败，仅在数据库完全不可用时使用mock数据')
      
      // 只有在数据库完全不可用时才使用mock数据
      return RSSDataService.filterTodayArticlesFromMock()
    }
  }

  /**
   * 获取所有未读文章
   */
  static async getUnreadArticles(): Promise<RSSArticle[]> {
    try {
      const dbArticles = await ArticleDAO.getArticles({
        isRead: false,
        orderBy: 'datePublished',
        sortOrder: 'DESC'
      })
      
      const articles = RSSModelConverter.dbArticlesToArticles(dbArticles)
      
      return articles
    } catch (error) {
      hilog.error(0x0000, 'RSSDataService', `获取未读文章失败: %{public}s`, JSON.stringify(error) ?? '')
      console.error('RSSDataService', '获取未读文章失败，仅在数据库完全不可用时使用mock数据')
      
      // 只有在数据库完全不可用时才使用mock数据
      return mockRSSArticles.filter(article => !article.readStatus)
        .sort((a, b) => new Date(b.publishDate).getTime() - new Date(a.publishDate).getTime())
    }
  }

  /**
   * 获取收藏的文章
   */
  static async getFavoriteArticles(): Promise<RSSArticle[]> {
    try {
      const dbArticles = await ArticleDAO.getArticles({
        isStarred: true,
        orderBy: 'datePublished',
        sortOrder: 'DESC'
      })
      
      const articles = RSSModelConverter.dbArticlesToArticles(dbArticles)
      
      return articles
    } catch (error) {
      hilog.error(0x0000, 'RSSDataService', `获取收藏文章失败: %{public}s`, JSON.stringify(error) ?? '')
      console.error('RSSDataService', '获取收藏文章失败，返回空列表')
      
      // 数据库不可用时返回空数组，不使用mock数据
      return []
    }
  }

  /**
   * 从mock数据中过滤今天的文章（降级方案）
   */
  private static filterTodayArticlesFromMock(): RSSArticle[] {
    const today = new Date()
    const todayStart = new Date(today.getFullYear(), today.getMonth(), today.getDate())
    
    
    const filtered = mockRSSArticles.filter(article => {
      try {
        const publishDate = new Date(article.publishDate)
        const isToday = publishDate >= todayStart
        return isToday
      } catch (error) {
        console.error('RSSDataService', `解析mock文章"${article.title}"的发布时间失败: ${article.publishDate}`, error)
        return false
      }
    }).sort((a, b) => new Date(b.publishDate).getTime() - new Date(a.publishDate).getTime())
    
    return filtered
  }

  /**
   * 标记文章为已读/未读
   */
  static async markArticleAsRead(articleId: string, readStatus: boolean = true): Promise<boolean> {
    try {
      if (readStatus) {
        // 标记为已读
        return await StatusDAO.markAsRead(articleId)
      } else {
        // 标记为未读
        return await StatusDAO.markAsUnread(articleId)
      }
    } catch (error) {
      hilog.error(0x0000, 'RSSDataService', `标记文章${articleId}${readStatus ? '已读' : '未读'}失败: %{public}s`, JSON.stringify(error) ?? '')
      
      // 降级到mock数据处理
      const article = mockRSSArticles.find(a => a.id === articleId)
      if (article) {
        article.readStatus = readStatus
        return true
      }
      return false
    }
  }

  /**
   * 批量标记RSS源的所有文章为已读
   */
  static async markAllAsReadByFeedId(feedId: string): Promise<number> {
    try {
      const updatedCount = await StatusDAO.markAllAsReadByFeedID(parseInt(feedId))
      return updatedCount
    } catch (error) {
      hilog.error(0x0000, 'RSSDataService', `批量标记RSS源${feedId}文章已读失败: %{public}s`, JSON.stringify(error) ?? '')
      
      // 降级到mock数据处理
      const articlesToUpdate = mockRSSArticles.filter(a => a.feedId === feedId && !a.readStatus)
      articlesToUpdate.forEach(article => {
        article.readStatus = true
      })
      return articlesToUpdate.length
    }
  }

  /**
   * 获取今天文章的未读数量
   */
  static async getTodayUnreadCount(): Promise<number> {
    try {
      const todayArticles = await RSSDataService.getTodayArticles()
      return todayArticles.filter(article => !article.readStatus).length
    } catch (error) {
      console.error('RSSDataService', '获取今天未读数量失败:', error)
      return 0
    }
  }

  /**
   * 获取收藏文章的未读数量
   */
  static async getFavoriteUnreadCount(): Promise<number> {
    try {
      const favoriteArticles = await RSSDataService.getFavoriteArticles()
      return favoriteArticles.filter(article => !article.readStatus).length
    } catch (error) {
      console.error('RSSDataService', '获取收藏未读数量失败:', error)
      return 0
    }
  }

  /**
   * 获取全部未读文章数量
   */
  static async getTotalUnreadCount(): Promise<number> {
    try {
      const unreadArticles = await RSSDataService.getUnreadArticles()
      return unreadArticles.length
    } catch (error) {
      console.error('RSSDataService', '获取全部未读数量失败:', error)
      return 0
    }
  }

  /**
   * 收藏文章
   */
  static async starArticle(articleId: string): Promise<boolean> {
    try {
      return await StatusDAO.addStar(articleId)
    } catch (error) {
      hilog.error(0x0000, 'RSSDataService', `收藏文章${articleId}失败: %{public}s`, JSON.stringify(error) ?? '')
      
      // 降级到mock数据处理
      const article = mockRSSArticles.find(a => a.id === articleId)
      if (article) {
        article.starredStatus = true
        return true
      }
      return false
    }
  }

  /**
   * 取消收藏文章
   */
  static async unstarArticle(articleId: string): Promise<boolean> {
    try {
      return await StatusDAO.removeStar(articleId)
    } catch (error) {
      hilog.error(0x0000, 'RSSDataService', `取消收藏文章${articleId}失败: %{public}s`, JSON.stringify(error) ?? '')
      
      // 降级到mock数据处理
      const article = mockRSSArticles.find(a => a.id === articleId)
      if (article) {
        article.starredStatus = false
        return true
      }
      return false
    }
  }

  /**
   * 切换文章收藏状态
   */
  static async toggleArticleStar(articleId: string, currentStarredStatus: boolean): Promise<boolean> {
    if (currentStarredStatus) {
      return await RSSDataService.unstarArticle(articleId)
    } else {
      return await RSSDataService.starArticle(articleId)
    }
  }
} 