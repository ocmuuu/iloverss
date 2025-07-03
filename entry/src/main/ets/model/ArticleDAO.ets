import relationalStore from '@ohos.data.relationalStore'
import hilog from '@ohos.hilog'
import { DatabaseManager } from './DatabaseManager'

/**
 * 文章数据库实体 
 */
export interface RSSArticleDB {
  articleID: string
  feedID: number
  uniqueID: string
  title: string
  contentHTML: string
  contentText: string
  url: string
  externalURL: string
  summary: string
  imageURL: string
  bannerImageURL: string
  datePublished: string
  dateModified: string
  searchRowID: number
  language: string
  createdAt: string
  updatedAt: string
}

/**
 * 扩展的文章数据库实体（包含状态和作者信息）
 */
export interface RSSArticleDBExtended extends RSSArticleDB {
  read?: number
  starred?: number
  authorName?: string
}

/**
 * 创建文章时的数据结构
 */
export interface RSSArticleCreateData {
  articleID: string
  feedID: number
  uniqueID: string
  title: string
  contentHTML: string
  contentText: string
  url: string
  externalURL: string
  summary: string
  imageURL: string
  bannerImageURL: string
  datePublished: string
  dateModified: string
  language: string
}

/**
 * 文章查询选项
 */
interface ArticleQueryOptions {
  feedID?: number
  isRead?: boolean
  isStarred?: boolean
  limit?: number
  offset?: number
  orderBy?: string
  sortOrder?: 'ASC' | 'DESC'
  searchTerm?: string
  dateFrom?: string // 发布日期大于等于 (ISO字符串)
}

/**
 * 文章更新参数
 */
export interface RSSArticleUpdateParams {
  title?: string
  contentHTML?: string
  contentText?: string
  url?: string
  externalURL?: string
  summary?: string
  imageURL?: string
  bannerImageURL?: string
  datePublished?: string
  dateModified?: string
  language?: string
}

/**
 * SQL参数类型
 */
type SQLParams = Array<string | number | boolean | null>

/**
 * 文章数据访问对象
 */
export class ArticleDAO {
  
  /**
   * 查询文章
   */
  static async getArticles(options: ArticleQueryOptions = {}): Promise<RSSArticleDBExtended[]> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      let sql = `
        SELECT a.*, s.read, s.starred, 
               GROUP_CONCAT(au.name, ', ') as authorName
        FROM articles a 
        LEFT JOIN statuses s ON a.articleID = s.articleID 
        LEFT JOIN authorsarticles al ON a.articleID = al.articleID
        LEFT JOIN authors au ON al.authorID = au.authorID
        WHERE 1=1
      `
      const params: SQLParams = []

      // 构建查询条件 - 必须在GROUP BY之前
      if (options.feedID !== undefined) {
        sql += ' AND a.feedID = ?'
        params.push(options.feedID)
      }

      if (options.isRead !== undefined) {
        sql += ' AND s.read = ?'
        params.push(options.isRead ? 1 : 0)
      }

      if (options.isStarred !== undefined) {
        sql += ' AND s.starred = ?'
        params.push(options.isStarred ? 1 : 0)
      }

      if (options.searchTerm) {
        sql += ' AND (a.title LIKE ? OR a.contentText LIKE ? OR a.summary LIKE ?)'
        const searchPattern = `%${options.searchTerm}%`
        params.push(searchPattern, searchPattern, searchPattern)
      }

      // 日期过滤 - 发布时间大于等于指定时间
      if (options.dateFrom) {
        sql += ' AND a.datePublished >= ?'
        params.push(options.dateFrom)
      }

      // 添加GROUP BY子句
      sql += ' GROUP BY a.articleID'

      // 排序
      const orderBy = options.orderBy || 'datePublished'
      const sortOrder = options.sortOrder || 'DESC'
      sql += ` ORDER BY a.${orderBy} ${sortOrder}`

      // 分页
      if (options.limit !== undefined) {
        sql += ' LIMIT ?'
        params.push(options.limit)
        
        if (options.offset !== undefined) {
          sql += ' OFFSET ?'
          params.push(options.offset)
        }
      }

      const resultSet = await store.querySql(sql, params)
      
      const articles: RSSArticleDBExtended[] = []

      if (resultSet.rowCount > 0) {
        resultSet.goToFirstRow()
        do {
          articles.push(ArticleDAO.mapResultSetToArticle(resultSet))
        } while (resultSet.goToNextRow())
      }

      resultSet.close()
      
      return articles
    } catch (error) {
      hilog.error(0x0000, 'ArticleDAO', '查询文章失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('查询文章失败')
    }
  }

  /**
   * 根据RSS源ID获取文章
   */
  static async getArticlesByFeedID(feedID: number, limit?: number): Promise<RSSArticleDB[]> {
    return await ArticleDAO.getArticles({
      feedID,
      limit,
      orderBy: 'datePublished',
      sortOrder: 'DESC'
    })
  }

  /**
   * 根据articleID获取文章
   */
  static async getArticleByID(articleID: string): Promise<RSSArticleDB | null> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      const sql = `
        SELECT a.*, s.read, s.starred, 
               GROUP_CONCAT(au.name, ', ') as authorName
        FROM articles a 
        LEFT JOIN statuses s ON a.articleID = s.articleID 
        LEFT JOIN authorsarticles al ON a.articleID = al.articleID
        LEFT JOIN authors au ON al.authorID = au.authorID
        WHERE a.articleID = ?
        GROUP BY a.articleID
      `
      const resultSet = await store.querySql(sql, [articleID])
      
      if (resultSet.rowCount > 0) {
        resultSet.goToFirstRow()
        const article = ArticleDAO.mapResultSetToArticle(resultSet)
        resultSet.close()
        return article
      }
      
      resultSet.close()
      return null
    } catch (error) {
      hilog.error(0x0000, 'ArticleDAO', '根据ID获取文章失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('根据ID获取文章失败')
    }
  }

  /**
   * 根据uniqueID获取文章
   */
  static async getArticleByUniqueID(feedID: number, uniqueID: string): Promise<RSSArticleDB | null> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      const sql = `
        SELECT a.*, s.read, s.starred, 
               GROUP_CONCAT(au.name, ', ') as authorName
        FROM articles a 
        LEFT JOIN statuses s ON a.articleID = s.articleID 
        LEFT JOIN authorsarticles al ON a.articleID = al.articleID
        LEFT JOIN authors au ON al.authorID = au.authorID
        WHERE a.feedID = ? AND a.uniqueID = ?
        GROUP BY a.articleID
      `
      const resultSet = await store.querySql(sql, [feedID, uniqueID])
      
      if (resultSet.rowCount > 0) {
        resultSet.goToFirstRow()
        const article = ArticleDAO.mapResultSetToArticle(resultSet)
        resultSet.close()
        return article
      }
      
      resultSet.close()
      return null
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : JSON.stringify(error)
      hilog.error(0x0000, 'ArticleDAO', `根据uniqueID获取文章失败: feedID=${feedID}, uniqueID=${uniqueID}, 错误: ${errorMessage}`)
      throw new Error(`根据uniqueID获取文章失败: ${errorMessage}`)
    }
  }

  /**
   * 添加新文章
   */
  static async addArticle(article: RSSArticleCreateData): Promise<boolean> {
    const store = DatabaseManager.getStore()
    if (!store) {
      hilog.error(0x0000, 'ArticleDAO', '数据库未初始化，无法添加文章')
      throw new Error('数据库未初始化')
    }

    try {
      // 检查文章是否已存在
      const existingArticle = await ArticleDAO.getArticleByUniqueID(article.feedID, article.uniqueID)
      if (existingArticle) {
        return false
      }

      const sql = `
        INSERT INTO articles (
          articleID, feedID, uniqueID, title, contentHTML, contentText,
          url, externalURL, summary, imageURL, bannerImageURL,
          datePublished, dateModified, language
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `
      
      const sqlParams = [
        article.articleID,
        article.feedID,
        article.uniqueID,
        article.title || '',
        article.contentHTML || '',
        article.contentText || '',
        article.url || '',
        article.externalURL || '',
        article.summary || '',
        article.imageURL || '',
        article.bannerImageURL || '',
        article.datePublished || '',
        article.dateModified || '',
        article.language || ''
      ]
      
      await store.executeSql(sql, sqlParams)

      // 创建默认状态
      await ArticleDAO.createArticleStatus(article.articleID)

      // 添加到搜索表
      await ArticleDAO.addToSearchIndex(article.articleID, article.title, article.contentText || article.summary)

      return true
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : JSON.stringify(error)
      hilog.error(0x0000, 'ArticleDAO', `添加文章失败: ${article.title}, 错误: ${errorMessage}`)
      throw new Error(`添加文章失败: ${errorMessage}`)
    }
  }

  /**
   * 更新文章信息
   */
  static async updateArticle(articleID: string, updates: RSSArticleUpdateParams): Promise<boolean> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      const updateFields: string[] = []
      const params: SQLParams = []

      // 构建更新字段
      Object.keys(updates).forEach(key => {
        let value: string | number | undefined
        
        // 手动处理键访问，替代索引访问
        switch (key) {
          case 'title':
            value = updates.title
            break
          case 'contentHTML':
            value = updates.contentHTML
            break
          case 'contentText':
            value = updates.contentText
            break
          case 'url':
            value = updates.url
            break
          case 'externalURL':
            value = updates.externalURL
            break
          case 'summary':
            value = updates.summary
            break
          case 'imageURL':
            value = updates.imageURL
            break
          case 'bannerImageURL':
            value = updates.bannerImageURL
            break
          case 'datePublished':
            value = updates.datePublished
            break
          case 'dateModified':
            value = updates.dateModified
            break
          case 'language':
            value = updates.language
            break
          default:
            value = undefined
        }
        
        if (value !== undefined) {
          updateFields.push(`${key} = ?`)
          params.push(value)
        }
      })

      if (updateFields.length === 0) {
        return false
      }

      updateFields.push('updated_at = CURRENT_TIMESTAMP')
      params.push(articleID)

      const sql = `UPDATE articles SET ${updateFields.join(', ')} WHERE articleID = ?`
      await store.executeSql(sql, params)

      // 更新搜索索引
      if (updates.title || updates.contentText || updates.summary) {
        const article = await ArticleDAO.getArticleByID(articleID)
        if (article) {
          await ArticleDAO.updateSearchIndex(
            articleID, 
            updates.title || article.title,
            updates.contentText || article.contentText || article.summary
          )
        }
      }

      hilog.info(0x0000, 'ArticleDAO', `文章更新成功: ${articleID}`)
      return true
    } catch (error) {
      hilog.error(0x0000, 'ArticleDAO', '更新文章失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('更新文章失败')
    }
  }

  /**
   * 删除文章
   */
  static async deleteArticle(articleID: string): Promise<boolean> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      // 删除文章（级联删除会自动处理相关表）
      await store.executeSql('DELETE FROM articles WHERE articleID = ?', [articleID])
      
      hilog.info(0x0000, 'ArticleDAO', `文章删除成功: ${articleID}`)
      return true
    } catch (error) {
      hilog.error(0x0000, 'ArticleDAO', '删除文章失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('删除文章失败')
    }
  }

  /**
   * 获取未读文章数量
   */
  static async getUnreadCount(feedID?: number): Promise<number> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      let sql = `
        SELECT COUNT(*) as count 
        FROM articles a 
        LEFT JOIN statuses s ON a.articleID = s.articleID 
        WHERE (s.read IS NULL OR s.read = 0)
      `
      const params: number[] = []

      if (feedID !== undefined) {
        sql += ' AND a.feedID = ?'
        params.push(feedID)
      }

      const resultSet = await store.querySql(sql, params)
      let count = 0
      
      if (resultSet.rowCount > 0) {
        resultSet.goToFirstRow()
        count = resultSet.getLong(0)
      }
      
      resultSet.close()
      return count
    } catch (error) {
      hilog.error(0x0000, 'ArticleDAO', '获取未读文章数量失败: %{public}s', JSON.stringify(error) ?? '')
      return 0
    }
  }

  /**
   * 获取加星文章数量
   */
  static async getStarredCount(feedID?: number): Promise<number> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      let sql = `
        SELECT COUNT(*) as count 
        FROM articles a 
        INNER JOIN statuses s ON a.articleID = s.articleID 
        WHERE s.starred = 1
      `
      const params: number[] = []

      if (feedID !== undefined) {
        sql += ' AND a.feedID = ?'
        params.push(feedID)
      }

      const resultSet = await store.querySql(sql, params)
      let count = 0
      
      if (resultSet.rowCount > 0) {
        resultSet.goToFirstRow()
        count = resultSet.getLong(0)
      }
      
      resultSet.close()
      return count
    } catch (error) {
      hilog.error(0x0000, 'ArticleDAO', '获取加星文章数量失败: %{public}s', JSON.stringify(error) ?? '')
      return 0
    }
  }

  /**
   * 清理旧文章
   */
  static async cleanupOldArticles(feedID: number, keepCount: number): Promise<void> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      // 获取需要删除的文章ID
      const sql = `
        SELECT articleID 
        FROM articles 
        WHERE feedID = ? 
        ORDER BY datePublished DESC 
        LIMIT -1 OFFSET ?
      `
      const resultSet = await store.querySql(sql, [feedID, keepCount])
      
      const articlesToDelete: string[] = []
      if (resultSet.rowCount > 0) {
        resultSet.goToFirstRow()
        do {
          articlesToDelete.push(resultSet.getString(0))
        } while (resultSet.goToNextRow())
      }
      resultSet.close()

      // 删除旧文章
      for (const articleID of articlesToDelete) {
        await ArticleDAO.deleteArticle(articleID)
      }

    } catch (error) {
      hilog.error(0x0000, 'ArticleDAO', '清理旧文章失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('清理旧文章失败')
    }
  }

  /**
   * 创建文章状态
   */
  private static async createArticleStatus(articleID: string): Promise<void> {
    const store = DatabaseManager.getStore()
    if (!store) {
      hilog.warn(0x0000, 'ArticleDAO', '数据库未初始化，无法创建文章状态')
      return
    }

    try {
      const sql = `
        INSERT OR IGNORE INTO statuses (articleID, read, starred, dateArrived) 
        VALUES (?, 0, 0, CURRENT_TIMESTAMP)
      `
      await store.executeSql(sql, [articleID])
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : JSON.stringify(error)
      hilog.warn(0x0000, 'ArticleDAO', `创建文章状态失败: ${articleID}, 错误: ${errorMessage}`)
    }
  }

  /**
   * 添加到搜索索引
   */
  private static async addToSearchIndex(articleID: string, title: string, body: string): Promise<void> {
    const store = DatabaseManager.getStore()
    if (!store) {
      hilog.warn(0x0000, 'ArticleDAO', '数据库未初始化，无法添加搜索索引')
      return
    }

    try {
      const sql = `
        INSERT OR REPLACE INTO search (articleID, title, body) 
        VALUES (?, ?, ?)
      `
      await store.executeSql(sql, [articleID, title || '', body || ''])
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : JSON.stringify(error)
      hilog.warn(0x0000, 'ArticleDAO', `添加搜索索引失败: ${articleID}, 错误: ${errorMessage}`)
    }
  }

  /**
   * 更新搜索索引
   */
  private static async updateSearchIndex(articleID: string, title: string, body: string): Promise<void> {
    const store = DatabaseManager.getStore()
    if (!store) {
      return
    }

    try {
      const sql = `
        UPDATE search SET title = ?, body = ? WHERE articleID = ?
      `
      await store.executeSql(sql, [title || '', body || '', articleID])
    } catch (error) {
      hilog.warn(0x0000, 'ArticleDAO', '更新搜索索引失败: %{public}s', JSON.stringify(error) ?? '')
    }
  }

  /**
   * 将ResultSet映射为文章对象（包含状态和作者信息）
   */
  private static mapResultSetToArticle(resultSet: relationalStore.ResultSet): RSSArticleDBExtended {
    const article: RSSArticleDBExtended = {
      articleID: resultSet.getString(resultSet.getColumnIndex('articleID')),
      feedID: resultSet.getLong(resultSet.getColumnIndex('feedID')),
      uniqueID: resultSet.getString(resultSet.getColumnIndex('uniqueID')),
      title: resultSet.getString(resultSet.getColumnIndex('title')) || '',
      contentHTML: resultSet.getString(resultSet.getColumnIndex('contentHTML')) || '',
      contentText: resultSet.getString(resultSet.getColumnIndex('contentText')) || '',
      url: resultSet.getString(resultSet.getColumnIndex('url')) || '',
      externalURL: resultSet.getString(resultSet.getColumnIndex('externalURL')) || '',
      summary: resultSet.getString(resultSet.getColumnIndex('summary')) || '',
      imageURL: resultSet.getString(resultSet.getColumnIndex('imageURL')) || '',
      bannerImageURL: resultSet.getString(resultSet.getColumnIndex('bannerImageURL')) || '',
      datePublished: resultSet.getString(resultSet.getColumnIndex('datePublished')) || '',
      dateModified: resultSet.getString(resultSet.getColumnIndex('dateModified')) || '',
      searchRowID: resultSet.getLong(resultSet.getColumnIndex('searchRowID')),
      language: resultSet.getString(resultSet.getColumnIndex('language')) || '',
      createdAt: resultSet.getString(resultSet.getColumnIndex('created_at')) || '',
      updatedAt: resultSet.getString(resultSet.getColumnIndex('updated_at')) || ''
    }

    // 添加状态信息（如果存在）
    try {
      const readIndex = resultSet.getColumnIndex('read')
      if (readIndex >= 0) {
        article.read = resultSet.getLong(readIndex)
      }
    } catch (error) {
      // 列不存在，忽略
    }

    try {
      const starredIndex = resultSet.getColumnIndex('starred')
      if (starredIndex >= 0) {
        article.starred = resultSet.getLong(starredIndex)
      }
    } catch (error) {
      // 列不存在，忽略
    }

    // 添加作者信息（如果存在）
    try {
      const authorIndex = resultSet.getColumnIndex('authorName')
      if (authorIndex >= 0) {
        article.authorName = resultSet.getString(authorIndex) || ''
      }
    } catch (error) {
      // 列不存在，忽略
    }

    return article
  }
}

export default ArticleDAO 