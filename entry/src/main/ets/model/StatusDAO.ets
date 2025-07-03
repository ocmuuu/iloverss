import relationalStore from '@ohos.data.relationalStore'
import hilog from '@ohos.hilog'
import { DatabaseManager } from './DatabaseManager'

/**
 * 文章状态数据库实体 
 */
export interface RSSArticleStatusDB {
  articleID: string
  read: boolean
  starred: boolean
  dateArrived: string
  createdAt: string
  updatedAt: string
}

/**
 * 状态更新参数
 */
export interface StatusUpdateParams {
  read?: boolean
  starred?: boolean
}

/**
 * 批量状态操作参数
 */
export interface BatchStatusParams {
  articleIDs: string[]
  read?: boolean
  starred?: boolean
}

/**
 * SQL参数类型
 */
type SQLParams = Array<string | number | boolean | null>

/**
 * 文章状态数据访问对象
 */
export class StatusDAO {
  
  /**
   * 获取文章状态
   */
  static async getArticleStatus(articleID: string): Promise<RSSArticleStatusDB | null> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      const sql = 'SELECT * FROM statuses WHERE articleID = ?'
      const resultSet = await store.querySql(sql, [articleID])
      
      if (resultSet.rowCount > 0) {
        resultSet.goToFirstRow()
        const status = StatusDAO.mapResultSetToStatus(resultSet)
        resultSet.close()
        return status
      }
      
      resultSet.close()
      return null
    } catch (error) {
      hilog.error(0x0000, 'StatusDAO', '获取文章状态失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('获取文章状态失败')
    }
  }

  /**
   * 创建文章状态
   */
  static async createArticleStatus(articleID: string): Promise<boolean> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      const sql = `
        INSERT OR IGNORE INTO statuses (articleID, read, starred, dateArrived) 
        VALUES (?, 0, 0, CURRENT_TIMESTAMP)
      `
      await store.executeSql(sql, [articleID])
      
      hilog.info(0x0000, 'StatusDAO', `文章状态创建成功: ${articleID}`)
      return true
    } catch (error) {
      hilog.error(0x0000, 'StatusDAO', '创建文章状态失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('创建文章状态失败')
    }
  }

  /**
   * 更新文章状态
   */
  static async updateArticleStatus(articleID: string, updates: StatusUpdateParams): Promise<boolean> {
    const store = DatabaseManager.getStore()
    if (!store) {
      console.error('StatusDAO', '数据库未初始化，无法更新文章状态')
      throw new Error('数据库未初始化')
    }

    try {
      
      // 先确保文章状态记录存在，如果不存在则创建
      const checkSql = 'SELECT articleID FROM statuses WHERE articleID = ?'
      const checkResult = await store.querySql(checkSql, [articleID])
      const exists = checkResult.rowCount > 0
      checkResult.close()
      
      
      if (!exists) {
        // 创建默认状态记录
        await StatusDAO.createArticleStatus(articleID)
      }
      
      const updateFields: string[] = []
      const params: SQLParams = []

      // 构建更新字段
      if (updates.read !== undefined) {
        updateFields.push('read = ?')
        params.push(updates.read ? 1 : 0)
      }

      if (updates.starred !== undefined) {
        updateFields.push('starred = ?')
        params.push(updates.starred ? 1 : 0)
      }

      if (updateFields.length === 0) {
        console.warn('StatusDAO', '没有要更新的字段')
        return false
      }

      updateFields.push('updated_at = CURRENT_TIMESTAMP')
      params.push(articleID)

      const sql = `UPDATE statuses SET ${updateFields.join(', ')} WHERE articleID = ?`
      
      await store.executeSql(sql, params)
      
      hilog.info(0x0000, 'StatusDAO', `文章状态更新成功: ${articleID}`)
      return true
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : JSON.stringify(error)
      hilog.error(0x0000, 'StatusDAO', `更新文章状态失败: ${articleID}, 错误: ${errorMessage}`)
      console.error('StatusDAO', `更新文章状态失败: ${articleID}, 错误: ${errorMessage}`)
      throw new Error(`更新文章状态失败: ${errorMessage}`)
    }
  }

  /**
   * 标记文章为已读
   */
  static async markAsRead(articleID: string): Promise<boolean> {
    
    try {
      const result = await StatusDAO.updateArticleStatus(articleID, { read: true })
      return result
    } catch (error) {
      console.error('StatusDAO', `标记文章已读失败: ${articleID}, 错误: ${JSON.stringify(error)}`)
      throw new Error(`标记文章已读失败: ${error instanceof Error ? error.message : JSON.stringify(error)}`)
    }
  }

  /**
   * 标记文章为未读
   */
  static async markAsUnread(articleID: string): Promise<boolean> {
    return await StatusDAO.updateArticleStatus(articleID, { read: false })
  }

  /**
   * 加星标
   */
  static async addStar(articleID: string): Promise<boolean> {
    return await StatusDAO.updateArticleStatus(articleID, { starred: true })
  }

  /**
   * 取消星标
   */
  static async removeStar(articleID: string): Promise<boolean> {
    return await StatusDAO.updateArticleStatus(articleID, { starred: false })
  }

  /**
   * 批量更新文章状态
   */
  static async batchUpdateStatus(params: BatchStatusParams): Promise<number> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    if (params.articleIDs.length === 0) {
      return 0
    }

    try {
      const updateFields: string[] = []
      const sqlParams: SQLParams = []

      // 构建更新字段
      if (params.read !== undefined) {
        updateFields.push('read = ?')
        sqlParams.push(params.read ? 1 : 0)
      }

      if (params.starred !== undefined) {
        updateFields.push('starred = ?')
        sqlParams.push(params.starred ? 1 : 0)
      }

      if (updateFields.length === 0) {
        return 0
      }

      updateFields.push('updated_at = CURRENT_TIMESTAMP')

      // 构建IN子句的占位符
      const placeholders = params.articleIDs.map(() => '?').join(', ')
      sqlParams.push(...params.articleIDs)

      const sql = `
        UPDATE statuses 
        SET ${updateFields.join(', ')} 
        WHERE articleID IN (${placeholders})
      `
      
      await store.executeSql(sql, sqlParams)

      hilog.info(0x0000, 'StatusDAO', `批量状态更新成功，影响 ${params.articleIDs.length} 篇文章`)
      return params.articleIDs.length
    } catch (error) {
      hilog.error(0x0000, 'StatusDAO', '批量更新状态失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('批量更新状态失败')
    }
  }

  /**
   * 批量标记为已读
   */
  static async batchMarkAsRead(articleIDs: string[]): Promise<number> {
    return await StatusDAO.batchUpdateStatus({
      articleIDs,
      read: true
    })
  }

  /**
   * 批量标记为未读
   */
  static async batchMarkAsUnread(articleIDs: string[]): Promise<number> {
    return await StatusDAO.batchUpdateStatus({
      articleIDs,
      read: false
    })
  }

  /**
   * 批量加星标
   */
  static async batchAddStar(articleIDs: string[]): Promise<number> {
    return await StatusDAO.batchUpdateStatus({
      articleIDs,
      starred: true
    })
  }

  /**
   * 批量取消星标
   */
  static async batchRemoveStar(articleIDs: string[]): Promise<number> {
    return await StatusDAO.batchUpdateStatus({
      articleIDs,
      starred: false
    })
  }

  /**
   * 根据Feed ID标记所有文章为已读
   */
  static async markAllAsReadByFeedID(feedID: number): Promise<number> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      const sql = `
        UPDATE statuses 
        SET read = 1, updated_at = CURRENT_TIMESTAMP 
        WHERE articleID IN (
          SELECT articleID FROM articles WHERE feedID = ?
        ) AND read = 0
      `
      
      await store.executeSql(sql, [feedID])
      const affectedRows = 1

      hilog.info(0x0000, 'StatusDAO', `Feed ${feedID} 的 ${affectedRows} 篇文章标记为已读`)
      return affectedRows
    } catch (error) {
      hilog.error(0x0000, 'StatusDAO', '批量标记已读失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('批量标记已读失败')
    }
  }

  /**
   * 标记所有文章为已读
   */
  static async markAllAsRead(): Promise<number> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      const sql = `
        UPDATE statuses 
        SET read = 1, updated_at = CURRENT_TIMESTAMP 
        WHERE read = 0
      `
      
      await store.executeSql(sql)
      const affectedRows = 1

      hilog.info(0x0000, 'StatusDAO', `${affectedRows} 篇文章标记为已读`)
      return affectedRows
    } catch (error) {
      hilog.error(0x0000, 'StatusDAO', '标记全部已读失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('标记全部已读失败')
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
        FROM statuses s
        INNER JOIN articles a ON s.articleID = a.articleID
        WHERE s.read = 0
      `
      const params: SQLParams = []

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
      hilog.error(0x0000, 'StatusDAO', '获取未读数量失败: %{public}s', JSON.stringify(error) ?? '')
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
        FROM statuses s
        INNER JOIN articles a ON s.articleID = a.articleID
        WHERE s.starred = 1
      `
      const params: SQLParams = []

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
      hilog.error(0x0000, 'StatusDAO', '获取加星数量失败: %{public}s', JSON.stringify(error) ?? '')
      return 0
    }
  }

  /**
   * 获取状态统计信息
   */
  static async getStatusStatistics(feedID?: number): Promise<StatusStatistics> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      let sql = `
        SELECT 
          COUNT(*) as total,
          SUM(CASE WHEN s.read = 1 THEN 1 ELSE 0 END) as read,
          SUM(CASE WHEN s.read = 0 THEN 1 ELSE 0 END) as unread,
          SUM(CASE WHEN s.starred = 1 THEN 1 ELSE 0 END) as starred
        FROM statuses s
        INNER JOIN articles a ON s.articleID = a.articleID
      `
      const params: SQLParams = []

      if (feedID !== undefined) {
        sql += ' WHERE a.feedID = ?'
        params.push(feedID)
      }

      const resultSet = await store.querySql(sql, params)
      let statistics: StatusStatistics = {
        total: 0,
        read: 0,
        unread: 0,
        starred: 0
      }
      
      if (resultSet.rowCount > 0) {
        resultSet.goToFirstRow()
        statistics = {
          total: resultSet.getLong(0),
          read: resultSet.getLong(1),
          unread: resultSet.getLong(2),
          starred: resultSet.getLong(3)
        }
      }
      
      resultSet.close()
      return statistics
    } catch (error) {
      hilog.error(0x0000, 'StatusDAO', '获取状态统计失败: %{public}s', JSON.stringify(error) ?? '')
      return {
        total: 0,
        read: 0,
        unread: 0,
        starred: 0
      }
    }
  }

  /**
   * 删除文章状态
   */
  static async deleteArticleStatus(articleID: string): Promise<boolean> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      await store.executeSql('DELETE FROM statuses WHERE articleID = ?', [articleID])
      
      hilog.info(0x0000, 'StatusDAO', `文章状态删除成功: ${articleID}`)
      return true
    } catch (error) {
      hilog.error(0x0000, 'StatusDAO', '删除文章状态失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('删除文章状态失败')
    }
  }

  /**
   * 将ResultSet映射为状态对象
   */
  private static mapResultSetToStatus(resultSet: relationalStore.ResultSet): RSSArticleStatusDB {
    return {
      articleID: resultSet.getString(resultSet.getColumnIndex('articleID')),
      read: resultSet.getLong(resultSet.getColumnIndex('read')) === 1,
      starred: resultSet.getLong(resultSet.getColumnIndex('starred')) === 1,
      dateArrived: resultSet.getString(resultSet.getColumnIndex('dateArrived')) || '',
      createdAt: resultSet.getString(resultSet.getColumnIndex('created_at')) || '',
      updatedAt: resultSet.getString(resultSet.getColumnIndex('updated_at')) || ''
    }
  }
}

/**
 * 状态统计信息
 */
export interface StatusStatistics {
  total: number
  read: number
  unread: number
  starred: number
}

export default StatusDAO 