import relationalStore from '@ohos.data.relationalStore'
import hilog from '@ohos.hilog'
import { DatabaseManager } from './DatabaseManager'

/**
 * 作者数据库实体
 */
export interface RSSAuthorDB {
  authorID: string
  name: string
  url: string
  avatarURL: string
  emailAddress: string
  createdAt: string
  updatedAt: string
}

/**
 * 作者创建数据
 */
export interface RSSAuthorCreateData {
  authorID: string
  name: string
  url?: string
  avatarURL?: string
  emailAddress?: string
}

/**
 * 作者更新参数
 */
export interface RSSAuthorUpdateParams {
  name?: string
  url?: string
  avatarURL?: string
  emailAddress?: string
}

/**
 * 作者关联数据 
 */
export interface AuthorLookupDB {
  authorID: string
  articleID: string
  createdAt: string
}

/**
 * SQL参数类型
 */
type SQLParams = Array<string | number | boolean | null>

/**
 * 作者数据访问对象 
 */
export class AuthorDAO {
  
  /**
   * 根据ID获取作者
   */
  static async getAuthorByID(authorID: string): Promise<RSSAuthorDB | null> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      const sql = 'SELECT * FROM authors WHERE authorID = ?'
      const resultSet = await store.querySql(sql, [authorID])
      
      if (resultSet.rowCount > 0) {
        resultSet.goToFirstRow()
        const author = AuthorDAO.mapResultSetToAuthor(resultSet)
        resultSet.close()
        return author
      }
      
      resultSet.close()
      return null
    } catch (error) {
      hilog.error(0x0000, 'AuthorDAO', '根据ID获取作者失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('根据ID获取作者失败')
    }
  }

  /**
   * 根据名称获取作者
   */
  static async getAuthorByName(name: string): Promise<RSSAuthorDB | null> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      const sql = 'SELECT * FROM authors WHERE name = ? LIMIT 1'
      const resultSet = await store.querySql(sql, [name])
      
      if (resultSet.rowCount > 0) {
        resultSet.goToFirstRow()
        const author = AuthorDAO.mapResultSetToAuthor(resultSet)
        resultSet.close()
        return author
      }
      
      resultSet.close()
      return null
    } catch (error) {
      hilog.error(0x0000, 'AuthorDAO', '根据名称获取作者失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('根据名称获取作者失败')
    }
  }

  /**
   * 根据邮箱获取作者
   */
  static async getAuthorByEmail(emailAddress: string): Promise<RSSAuthorDB | null> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      const sql = 'SELECT * FROM authors WHERE emailAddress = ? LIMIT 1'
      const resultSet = await store.querySql(sql, [emailAddress])
      
      if (resultSet.rowCount > 0) {
        resultSet.goToFirstRow()
        const author = AuthorDAO.mapResultSetToAuthor(resultSet)
        resultSet.close()
        return author
      }
      
      resultSet.close()
      return null
    } catch (error) {
      hilog.error(0x0000, 'AuthorDAO', '根据邮箱获取作者失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('根据邮箱获取作者失败')
    }
  }

  /**
   * 获取所有作者
   */
  static async getAllAuthors(limit?: number, offset?: number): Promise<RSSAuthorDB[]> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      let sql = 'SELECT * FROM authors ORDER BY name ASC'
      const params: number[] = []

      if (limit !== undefined) {
        sql += ' LIMIT ?'
        params.push(limit)
        
        if (offset !== undefined) {
          sql += ' OFFSET ?'
          params.push(offset)
        }
      }

      const resultSet = await store.querySql(sql, params)
      
      const authors: RSSAuthorDB[] = []
      if (resultSet.rowCount > 0) {
        resultSet.goToFirstRow()
        do {
          authors.push(AuthorDAO.mapResultSetToAuthor(resultSet))
        } while (resultSet.goToNextRow())
      }

      resultSet.close()
      hilog.info(0x0000, 'AuthorDAO', `获取到 ${authors.length} 个作者`)
      return authors
    } catch (error) {
      hilog.error(0x0000, 'AuthorDAO', '获取所有作者失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('获取所有作者失败')
    }
  }

  /**
   * 添加作者
   */
  static async addAuthor(author: RSSAuthorCreateData): Promise<boolean> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      // 检查作者是否已存在
      const existingAuthor = await AuthorDAO.getAuthorByID(author.authorID)
      if (existingAuthor) {
        hilog.debug(0x0000, 'AuthorDAO', `作者已存在，跳过: ${author.name}`)
        return false
      }

      const sql = `
        INSERT INTO authors (authorID, name, url, avatarURL, emailAddress) 
        VALUES (?, ?, ?, ?, ?)
      `
      
      await store.executeSql(sql, [
        author.authorID,
        author.name || '',
        author.url || '',
        author.avatarURL || '',
        author.emailAddress || ''
      ])

      hilog.info(0x0000, 'AuthorDAO', `作者添加成功: ${author.name}`)
      return true
    } catch (error) {
      hilog.error(0x0000, 'AuthorDAO', '添加作者失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('添加作者失败')
    }
  }

  /**
   * 更新作者信息
   */
  static async updateAuthor(authorID: string, updates: RSSAuthorUpdateParams): Promise<boolean> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      const updateFields: string[] = []
      const params: (string | number)[] = []

      // 构建更新字段
      if (updates.name !== undefined) {
        updateFields.push('name = ?')
        params.push(updates.name)
      }
      if (updates.url !== undefined) {
        updateFields.push('url = ?')
        params.push(updates.url)
      }
      if (updates.avatarURL !== undefined) {
        updateFields.push('avatarURL = ?')
        params.push(updates.avatarURL)
      }
      if (updates.emailAddress !== undefined) {
        updateFields.push('emailAddress = ?')
        params.push(updates.emailAddress)
      }

      if (updateFields.length === 0) {
        return false
      }

      updateFields.push('updated_at = CURRENT_TIMESTAMP')
      params.push(authorID)

      const sql = `UPDATE authors SET ${updateFields.join(', ')} WHERE authorID = ?`
      await store.executeSql(sql, params)

      hilog.info(0x0000, 'AuthorDAO', `作者更新成功: ${authorID}`)
      return true
    } catch (error) {
      hilog.error(0x0000, 'AuthorDAO', '更新作者失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('更新作者失败')
    }
  }

  /**
   * 删除作者
   */
  static async deleteAuthor(authorID: string): Promise<boolean> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      // 删除作者（级联删除会自动处理authorsarticles表）
      await store.executeSql('DELETE FROM authors WHERE authorID = ?', [authorID])
      
      hilog.info(0x0000, 'AuthorDAO', `作者删除成功: ${authorID}`)
      return true
    } catch (error) {
      hilog.error(0x0000, 'AuthorDAO', '删除作者失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('删除作者失败')
    }
  }

  /**
   * 获取文章的作者列表
   */
  static async getAuthorsByArticleID(articleID: string): Promise<RSSAuthorDB[]> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      const sql = `
        SELECT a.* 
        FROM authors a 
        INNER JOIN authorsarticles al ON a.authorID = al.authorID 
        WHERE al.articleID = ?
        ORDER BY a.name ASC
      `
      const resultSet = await store.querySql(sql, [articleID])
      
      const authors: RSSAuthorDB[] = []
      if (resultSet.rowCount > 0) {
        resultSet.goToFirstRow()
        do {
          authors.push(AuthorDAO.mapResultSetToAuthor(resultSet))
        } while (resultSet.goToNextRow())
      }

      resultSet.close()
      return authors
    } catch (error) {
      hilog.error(0x0000, 'AuthorDAO', '获取文章作者失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('获取文章作者失败')
    }
  }

  /**
   * 获取作者的文章列表
   */
  static async getArticlesByAuthorID(authorID: string, limit?: number): Promise<string[]> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      let sql = `
        SELECT articleID 
        FROM authorsarticles 
        WHERE authorID = ?
        ORDER BY created_at DESC
      `
      const params: (string | number)[] = [authorID]

      if (limit !== undefined) {
        sql += ' LIMIT ?'
        params.push(limit)
      }

      const resultSet = await store.querySql(sql, params)
      
      const articleIDs: string[] = []
      if (resultSet.rowCount > 0) {
        resultSet.goToFirstRow()
        do {
          articleIDs.push(resultSet.getString(0))
        } while (resultSet.goToNextRow())
      }

      resultSet.close()
      return articleIDs
    } catch (error) {
      hilog.error(0x0000, 'AuthorDAO', '获取作者文章失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('获取作者文章失败')
    }
  }

  /**
   * 关联作者和文章
   */
  static async linkAuthorToArticle(authorID: string, articleID: string): Promise<boolean> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      const sql = `
        INSERT OR IGNORE INTO authorsarticles (authorID, articleID) 
        VALUES (?, ?)
      `
      await store.executeSql(sql, [authorID, articleID])

      hilog.debug(0x0000, 'AuthorDAO', `作者文章关联成功: ${authorID} -> ${articleID}`)
      return true
    } catch (error) {
      hilog.error(0x0000, 'AuthorDAO', '关联作者文章失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('关联作者文章失败')
    }
  }

  /**
   * 取消作者和文章的关联
   */
  static async unlinkAuthorFromArticle(authorID: string, articleID: string): Promise<boolean> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      await store.executeSql(
        'DELETE FROM authorsarticles WHERE authorID = ? AND articleID = ?', 
        [authorID, articleID]
      )

      hilog.info(0x0000, 'AuthorDAO', `作者文章关联取消成功: ${authorID} -> ${articleID}`)
      return true
    } catch (error) {
      hilog.error(0x0000, 'AuthorDAO', '取消作者文章关联失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('取消作者文章关联失败')
    }
  }

  /**
   * 批量关联作者和文章
   */
  static async batchLinkAuthorsToArticle(authorIDs: string[], articleID: string): Promise<number> {
    if (authorIDs.length === 0) {
      return 0
    }

    let successCount = 0
    for (const authorID of authorIDs) {
      try {
        await AuthorDAO.linkAuthorToArticle(authorID, articleID)
        successCount++
      } catch (error) {
        hilog.warn(0x0000, 'AuthorDAO', `批量关联失败: ${authorID} -> ${articleID}`)
      }
    }

    hilog.info(0x0000, 'AuthorDAO', `批量关联完成: ${successCount}/${authorIDs.length}`)
    return successCount
  }

  /**
   * 获取作者统计信息
   */
  static async getAuthorStatistics(authorID: string): Promise<AuthorStatistics> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      const sql = `
        SELECT COUNT(*) as articleCount
        FROM authorsarticles 
        WHERE authorID = ?
      `
      const resultSet = await store.querySql(sql, [authorID])
      
      let articleCount = 0
      if (resultSet.rowCount > 0) {
        resultSet.goToFirstRow()
        articleCount = resultSet.getLong(0)
      }
      
      resultSet.close()

      return {
        authorID,
        articleCount
      }
    } catch (error) {
      hilog.error(0x0000, 'AuthorDAO', '获取作者统计失败: %{public}s', JSON.stringify(error) ?? '')
      return {
        authorID,
        articleCount: 0
      }
    }
  }

  /**
   * 搜索作者
   */
  static async searchAuthors(searchTerm: string, limit?: number): Promise<RSSAuthorDB[]> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      let sql = `
        SELECT * FROM authors 
        WHERE name LIKE ? OR emailAddress LIKE ?
        ORDER BY name ASC
      `
      const params: (string | number)[] = [`%${searchTerm}%`, `%${searchTerm}%`]

      if (limit !== undefined) {
        sql += ' LIMIT ?'
        params.push(limit)
      }

      const resultSet = await store.querySql(sql, params)
      
      const authors: RSSAuthorDB[] = []
      if (resultSet.rowCount > 0) {
        resultSet.goToFirstRow()
        do {
          authors.push(AuthorDAO.mapResultSetToAuthor(resultSet))
        } while (resultSet.goToNextRow())
      }

      resultSet.close()
      return authors
    } catch (error) {
      hilog.error(0x0000, 'AuthorDAO', '搜索作者失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('搜索作者失败')
    }
  }

  /**
   * 获取作者总数
   */
  static async getAuthorCount(): Promise<number> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      const resultSet = await store.querySql('SELECT COUNT(*) as count FROM authors')
      let count = 0
      
      if (resultSet.rowCount > 0) {
        resultSet.goToFirstRow()
        count = resultSet.getLong(0)
      }
      
      resultSet.close()
      return count
    } catch (error) {
      hilog.error(0x0000, 'AuthorDAO', '获取作者总数失败: %{public}s', JSON.stringify(error) ?? '')
      return 0
    }
  }

  /**
   * 清理未关联的作者
   */
  static async cleanupOrphanedAuthors(): Promise<number> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      const sql = `
        DELETE FROM authors 
        WHERE authorID NOT IN (
          SELECT DISTINCT authorID FROM authorsarticles
        )
      `
      await store.executeSql(sql)
      const deletedCount = 1

      hilog.info(0x0000, 'AuthorDAO', `清理了 ${deletedCount} 个未关联的作者`)
      return deletedCount
    } catch (error) {
      hilog.error(0x0000, 'AuthorDAO', '清理未关联作者失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('清理未关联作者失败')
    }
  }

  /**
   * 将ResultSet映射为作者对象
   */
  private static mapResultSetToAuthor(resultSet: relationalStore.ResultSet): RSSAuthorDB {
    return {
      authorID: resultSet.getString(resultSet.getColumnIndex('authorID')),
      name: resultSet.getString(resultSet.getColumnIndex('name')) || '',
      url: resultSet.getString(resultSet.getColumnIndex('url')) || '',
      avatarURL: resultSet.getString(resultSet.getColumnIndex('avatarURL')) || '',
      emailAddress: resultSet.getString(resultSet.getColumnIndex('emailAddress')) || '',
      createdAt: resultSet.getString(resultSet.getColumnIndex('created_at')) || '',
      updatedAt: resultSet.getString(resultSet.getColumnIndex('updated_at')) || ''
    }
  }
}

/**
 * 作者统计信息
 */
export interface AuthorStatistics {
  authorID: string
  articleCount: number
}

export default AuthorDAO 