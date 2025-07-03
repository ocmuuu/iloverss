import relationalStore from '@ohos.data.relationalStore'
import hilog from '@ohos.hilog'
import { DatabaseManager } from './DatabaseManager'

/**
 * RSS源数据库实体
 */
export interface RSSFeedDB {
  id: number
  folderId: number | null
  url: string
  title: string
  description: string
  link: string
  language: string
  lastBuildDate: string
  imageUrl: string
  category: string
  isActive: boolean
  sortOrder: number
  createdAt: string
  updatedAt: string
  lastFetchAt: string | null
  errorCount: number
  lastError: string | null
  faviconPath?: string | null
}

/**
 * 创建RSS源时的数据结构
 */
export interface RSSFeedCreateData {
  url: string
  title: string
  description: string
  link: string
  language: string
  lastBuildDate: string
  imageUrl: string
  category: string
  isActive: boolean
  sortOrder: number
  folderId?: number | null
}

/**
 * RSS源更新参数
 */
export interface RSSFeedUpdateParams {
  title?: string
  description?: string
  link?: string
  language?: string
  lastBuildDate?: string
  imageUrl?: string
  category?: string
  isActive?: boolean
  sortOrder?: number
  lastFetchAt?: string
  errorCount?: number
  lastError?: string
  folderId?: number | null
}

/**
 * SQL参数类型
 */
type SQLParams = Array<string | number | boolean | null>

/**
 * RSS源数据访问对象
 */
export class FeedDAO {
  
  /**
   * 获取所有活跃的RSS源
   */
  static async getAllActiveFeeds(): Promise<RSSFeedDB[]> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      const resultSet = await store.querySql(
        'SELECT * FROM feeds WHERE is_active = 1 ORDER BY sort_order ASC, created_at ASC'
      )
      
      const feeds: RSSFeedDB[] = []
      if (resultSet.rowCount > 0) {
        resultSet.goToFirstRow()
        do {
          feeds.push(FeedDAO.mapResultSetToFeed(resultSet))
        } while (resultSet.goToNextRow())
      }
      
      resultSet.close()
      hilog.info(0x0000, 'FeedDAO', `获取到 ${feeds.length} 个活跃RSS源`)
      feeds.forEach((feed, index) => {
      })
      return feeds
    } catch (error) {
      hilog.error(0x0000, 'FeedDAO', '获取所有RSS源失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('获取所有RSS源失败')
    }
  }

  /**
   * 获取所有RSS源
   */
  static async getAllFeeds(includeInactive: boolean = false): Promise<RSSFeedDB[]> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      let sql = 'SELECT * FROM feeds'
      const params: Array<string | number | boolean | null> = []

      if (!includeInactive) {
        sql += ' WHERE is_active = 1'
      }

      sql += ' ORDER BY sort_order ASC, created_at ASC'

      const resultSet = await store.querySql(sql, params)

      const feeds: RSSFeedDB[] = []
      if (resultSet.rowCount > 0) {
        resultSet.goToFirstRow()
        do {
          feeds.push(FeedDAO.mapResultSetToFeed(resultSet))
        } while (resultSet.goToNextRow())
      }

      resultSet.close()
      hilog.info(0x0000, 'FeedDAO', `获取到 ${feeds.length} 个RSS源`)
      return feeds
    } catch (error) {
      hilog.error(0x0000, 'FeedDAO', '获取所有RSS源失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('获取所有RSS源失败')
    }
  }

  /**
   * 根据ID获取RSS源
   */
  static async getFeedById(id: number): Promise<RSSFeedDB | null> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      const resultSet = await store.querySql('SELECT * FROM feeds WHERE id = ?', [id])
      
      if (resultSet.rowCount > 0) {
        resultSet.goToFirstRow()
        const feed = FeedDAO.mapResultSetToFeed(resultSet)
        resultSet.close()
        return feed
      }
      
      resultSet.close()
      return null
    } catch (error) {
      hilog.error(0x0000, 'FeedDAO', '根据ID获取RSS源失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('根据ID获取RSS源失败')
    }
  }

  /**
   * 根据URL获取RSS源
   */
  static async getFeedByUrl(url: string): Promise<RSSFeedDB | null> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      const resultSet = await store.querySql('SELECT * FROM feeds WHERE url = ?', [url])
      
      if (resultSet.rowCount > 0) {
        resultSet.goToFirstRow()
        const feed = FeedDAO.mapResultSetToFeed(resultSet)
        resultSet.close()
        return feed
      }
      
      resultSet.close()
      return null
    } catch (error) {
      hilog.error(0x0000, 'FeedDAO', '根据URL获取RSS源失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('根据URL获取RSS源失败')
    }
  }

  /**
   * 获取指定文件夹下的RSS源
   */
  static async getFeedsByFolderId(folderId: number | null): Promise<RSSFeedDB[]> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      let sql: string
      let params: SQLParams
      
      if (folderId === null) {
        // 获取未分类的RSS源（folder_id为null）
        sql = 'SELECT * FROM feeds WHERE folder_id IS NULL AND is_active = 1 ORDER BY sort_order ASC, created_at ASC'
        params = []
      } else {
        // 获取指定文件夹下的RSS源
        sql = 'SELECT * FROM feeds WHERE folder_id = ? AND is_active = 1 ORDER BY sort_order ASC, created_at ASC'
        params = [folderId]
      }
      
      const resultSet = await store.querySql(sql, params)
      const feeds: RSSFeedDB[] = []
      
      if (resultSet.rowCount > 0) {
        resultSet.goToFirstRow()
        do {
          feeds.push(FeedDAO.mapResultSetToFeed(resultSet))
        } while (resultSet.goToNextRow())
      }
      
      resultSet.close()
      return feeds
    } catch (error) {
      hilog.error(0x0000, 'FeedDAO', '获取文件夹RSS源失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('获取文件夹RSS源失败')
    }
  }

  /**
   * 将RSS源移动到指定文件夹
   */
  static async moveFeedToFolder(feedId: number, folderId: number | null): Promise<boolean> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      const sql = 'UPDATE feeds SET folder_id = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?'
      await store.executeSql(sql, [folderId, feedId])
      
      hilog.info(0x0000, 'FeedDAO', `RSS源${feedId}移动到文件夹${folderId}成功`)
      return true
    } catch (error) {
      hilog.error(0x0000, 'FeedDAO', '移动RSS源到文件夹失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('移动RSS源到文件夹失败')
    }
  }

  /**
   * 添加新的RSS源
   */
  static async addFeed(feed: RSSFeedCreateData): Promise<number> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      // 检查URL是否已存在
      const existingFeed = await FeedDAO.getFeedByUrl(feed.url)
      if (existingFeed) {
        throw new Error(`RSS源URL已存在: ${feed.url}`)
      }

      const sql = `
        INSERT INTO feeds (
          url, title, description, link, language, last_build_date, 
          image_url, category, is_active, sort_order, folder_id,
          created_at, updated_at, error_count, last_error
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 0, NULL)
      `

      await store.executeSql(sql, [
        feed.url,
        feed.title,
        feed.description || '',
        feed.link || '',
        feed.language || '',
        feed.lastBuildDate || '',
        feed.imageUrl || '',
        feed.category || '',
        feed.isActive !== false ? 1 : 0,
        feed.sortOrder || 0,
        feed.folderId || null
      ])

      const newFeed = await FeedDAO.getFeedByUrl(feed.url)
      if (newFeed) {
        hilog.info(0x0000, 'FeedDAO', `RSS源添加成功: ${newFeed.title}`)
        return newFeed.id
      } else {
        throw new Error("添加RSS源后无法获取到新ID")
      }
    } catch (error) {
      hilog.error(0x0000, 'FeedDAO', '添加RSS源失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error(`添加RSS源失败: ${error.message}`)
    }
  }

  /**
   * 更新RSS源信息
   */
  static async updateFeed(id: number, feed: RSSFeedUpdateParams): Promise<boolean> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      const updateFields: string[] = []
      const updateValues: (string | number | null)[] = []

      // 动态构建更新字段
      if (feed.title !== undefined) {
        updateFields.push('title = ?')
        updateValues.push(feed.title)
      }
      if (feed.description !== undefined) {
        updateFields.push('description = ?')
        updateValues.push(feed.description)
      }
      if (feed.link !== undefined) {
        updateFields.push('link = ?')
        updateValues.push(feed.link)
      }
      if (feed.language !== undefined) {
        updateFields.push('language = ?')
        updateValues.push(feed.language)
      }
      if (feed.lastBuildDate !== undefined) {
        updateFields.push('last_build_date = ?')
        updateValues.push(feed.lastBuildDate)
      }
      if (feed.imageUrl !== undefined) {
        updateFields.push('image_url = ?')
        updateValues.push(feed.imageUrl)
      }
      if (feed.category !== undefined) {
        updateFields.push('category = ?')
        updateValues.push(feed.category)
      }
      if (feed.isActive !== undefined) {
        updateFields.push('is_active = ?')
        updateValues.push(feed.isActive ? 1 : 0)
      }
      if (feed.sortOrder !== undefined) {
        updateFields.push('sort_order = ?')
        updateValues.push(feed.sortOrder)
      }
      if (feed.lastFetchAt !== undefined) {
        updateFields.push('last_fetch_at = ?')
        updateValues.push(feed.lastFetchAt || '')
      }
      if (feed.errorCount !== undefined) {
        updateFields.push('error_count = ?')
        updateValues.push(feed.errorCount)
      }
      if (feed.lastError !== undefined) {
        updateFields.push('last_error = ?')
        updateValues.push(feed.lastError || '')
      }
      if (feed.folderId !== undefined) {
        updateFields.push('folder_id = ?')
        updateValues.push(feed.folderId || null)
      }

      if (updateFields.length === 0) {
        return true // 没有需要更新的字段
      }

      // 添加更新时间
      updateFields.push('updated_at = CURRENT_TIMESTAMP')
      updateValues.push(id)

      const sql = `UPDATE feeds SET ${updateFields.join(', ')} WHERE id = ?`
      await store.executeSql(sql, updateValues)

      hilog.info(0x0000, 'FeedDAO', `RSS源更新成功: ${id}`)
      return true
    } catch (error) {
      hilog.error(0x0000, 'FeedDAO', '更新RSS源失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('更新RSS源失败')
    }
  }

  /**
   * 更新RSS源的获取状态
   */
  static async updateFeedFetchStatus(id: number, success: boolean, error?: string): Promise<boolean> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      if (success) {
        // 成功时重置错误计数
        await store.executeSql(
          'UPDATE feeds SET last_fetch_at = CURRENT_TIMESTAMP, error_count = 0, last_error = NULL WHERE id = ?',
          [id]
        )
      } else {
        // 失败时增加错误计数
        await store.executeSql(
          'UPDATE feeds SET error_count = error_count + 1, last_error = ? WHERE id = ?',
          [error || '未知错误', id]
        )
      }

      return true
    } catch (error) {
      hilog.error(0x0000, 'FeedDAO', '更新RSS源获取状态失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('更新RSS源获取状态失败')
    }
  }

  /**
   * 删除RSS源
   */
  static async deleteFeed(id: number): Promise<boolean> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      await store.executeSql('DELETE FROM feeds WHERE id = ?', [id])
      hilog.info(0x0000, 'FeedDAO', `RSS源删除成功: ${id}`)
      return true
    } catch (error) {
      hilog.error(0x0000, 'FeedDAO', '删除RSS源失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('删除RSS源失败')
    }
  }

  /**
   * 设置RSS源的活跃状态
   */
  static async setFeedActive(id: number, isActive: boolean): Promise<boolean> {
    return await FeedDAO.updateFeed(id, { isActive })
  }

  /**
   * 将ResultSet映射为RSSFeedDB对象
   */
  private static mapResultSetToFeed(resultSet: relationalStore.ResultSet): RSSFeedDB {
    const folderIdIndex = resultSet.getColumnIndex('folder_id')
    let folderId: number | null = null
    try {
      if (!resultSet.isColumnNull(folderIdIndex)) {
        folderId = resultSet.getLong(folderIdIndex)
      }
    } catch (error) {
      folderId = null
    }
    
    return {
      id: resultSet.getLong(resultSet.getColumnIndex('id')),
      folderId: folderId,
      url: resultSet.getString(resultSet.getColumnIndex('url')),
      title: resultSet.getString(resultSet.getColumnIndex('title')),
      description: resultSet.getString(resultSet.getColumnIndex('description')),
      link: resultSet.getString(resultSet.getColumnIndex('link')),
      language: resultSet.getString(resultSet.getColumnIndex('language')),
      lastBuildDate: resultSet.getString(resultSet.getColumnIndex('last_build_date')),
      imageUrl: resultSet.getString(resultSet.getColumnIndex('image_url')),
      category: resultSet.getString(resultSet.getColumnIndex('category')),
      isActive: resultSet.getLong(resultSet.getColumnIndex('is_active')) === 1,
      sortOrder: resultSet.getLong(resultSet.getColumnIndex('sort_order')),
      createdAt: resultSet.getString(resultSet.getColumnIndex('created_at')),
      updatedAt: resultSet.getString(resultSet.getColumnIndex('updated_at')),
      lastFetchAt: resultSet.getString(resultSet.getColumnIndex('last_fetch_at')),
      errorCount: resultSet.getLong(resultSet.getColumnIndex('error_count')),
      lastError: resultSet.getString(resultSet.getColumnIndex('last_error')),
      faviconPath: resultSet.getString(resultSet.getColumnIndex('favicon_path')) || undefined
    }
  }

  /**
   * 更新Feed的本地favicon路径
   * @param feedId Feed ID
   * @param faviconPath 本地favicon路径
   */
  static async updateFaviconPath(feedId: number, faviconPath: string): Promise<void> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    const sql = `
      UPDATE feeds 
      SET favicon_path = ?, updated_at = CURRENT_TIMESTAMP 
      WHERE id = ?
    `
    
    await store.executeSql(sql, [faviconPath, feedId])
    hilog.info(0x0000, 'FeedDAO', `Feed ${feedId} favicon路径已更新: ${faviconPath}`)
  }

  /**
   * 获取Feed的本地favicon路径
   * @param feedId Feed ID
   * @returns 本地favicon路径或null
   */
  static async getFaviconPath(feedId: number): Promise<string | null> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    const sql = `SELECT favicon_path FROM feeds WHERE id = ?`
    const resultSet = await store.querySql(sql, [feedId])
    
    if (resultSet.rowCount > 0) {
      resultSet.goToFirstRow()
      const faviconPath = resultSet.getString(resultSet.getColumnIndex('favicon_path'))
      resultSet.close()
      return faviconPath || null
    } else {
      resultSet.close()
      return null
    }
  }

  /**
   * 清除Feed的本地favicon路径
   * @param feedId Feed ID
   */
  static async clearFaviconPath(feedId: number): Promise<void> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    const sql = `
      UPDATE feeds 
      SET favicon_path = NULL, updated_at = CURRENT_TIMESTAMP 
      WHERE id = ?
    `
    
    await store.executeSql(sql, [feedId])
    hilog.info(0x0000, 'FeedDAO', `Feed ${feedId} favicon路径已清除`)
  }
}

export default FeedDAO 