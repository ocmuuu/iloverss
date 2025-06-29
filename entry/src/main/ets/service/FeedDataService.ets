import { DatabaseManager } from '../model/DatabaseManager'
import type { RSSFeedDB } from '../model/FeedDAO'
import { FolderDAO, type RSSFolderWithUnread } from '../model/FolderDAO'
import type { RSSFolderDB } from '../model/FolderDAO'

/**
 * 扩展的源接口，包含未读数量和图标
 */
export interface RSSFeedWithUnread extends RSSFeedDB {
  unreadCount: number
  favicon?: Resource | string
}

/**
 * 未读数量集合
 */
export interface UnreadCounts {
  today: number
  favorites: number
  total: number
}

/**
 * 提供加载订阅列表所需数据的服务
 */
export class FeedDataService {

  /**
   * 加载所有活跃的RSS源及其未读数量
   */
  static async loadFeeds(): Promise<RSSFeedWithUnread[]> {
    const store = DatabaseManager.getStore()
    if (!store) throw new Error('数据库未初始化')

    const dbStatus = await DatabaseManager.checkDatabaseStatus()
    if (!dbStatus) throw new Error('数据库状态异常')

    const sql = `
      SELECT f.*,
             COALESCE((
               SELECT COUNT(*)
               FROM articles a
               LEFT JOIN statuses s ON a.articleID = s.articleID
               WHERE a.feedID = f.id AND (s.read IS NULL OR s.read = 0)
             ), 0) as unread_count
      FROM feeds f
      WHERE f.is_active = 1
      ORDER BY f.sort_order ASC, f.title ASC
    `
    const resultSet = await store.querySql(sql)
    const feeds: RSSFeedWithUnread[] = []

    if (resultSet.rowCount > 0) {
      resultSet.goToFirstRow()
      do {
        const folderIdIndex = resultSet.getColumnIndex('folder_id')
        let folderId: number | null = null
        if (!resultSet.isColumnNull(folderIdIndex)) {
          folderId = resultSet.getLong(folderIdIndex)
        }

        const feed: RSSFeedWithUnread = {
          id: resultSet.getLong(resultSet.getColumnIndex('id')),
          folderId: folderId,
          url: resultSet.getString(resultSet.getColumnIndex('url')),
          title: resultSet.getString(resultSet.getColumnIndex('title')),
          description: resultSet.getString(resultSet.getColumnIndex('description')) || '',
          link: resultSet.getString(resultSet.getColumnIndex('link')) || '',
          language: resultSet.getString(resultSet.getColumnIndex('language')) || '',
          lastBuildDate: resultSet.getString(resultSet.getColumnIndex('last_build_date')) || '',
          imageUrl: resultSet.getString(resultSet.getColumnIndex('image_url')) || '',
          category: resultSet.getString(resultSet.getColumnIndex('category')) || '',
          isActive: resultSet.getLong(resultSet.getColumnIndex('is_active')) === 1,
          sortOrder: resultSet.getLong(resultSet.getColumnIndex('sort_order')),
          createdAt: resultSet.getString(resultSet.getColumnIndex('created_at')),
          updatedAt: resultSet.getString(resultSet.getColumnIndex('updated_at')),
          lastFetchAt: resultSet.getString(resultSet.getColumnIndex('last_fetch_at')),
          errorCount: resultSet.getLong(resultSet.getColumnIndex('error_count')),
          lastError: resultSet.getString(resultSet.getColumnIndex('last_error')),
          unreadCount: resultSet.getLong(resultSet.getColumnIndex('unread_count')),
          favicon: $r("app.media.rss"), // 默认图标
          faviconPath: resultSet.getString(resultSet.getColumnIndex('favicon_path'))
        }
        feeds.push(feed)
      } while (resultSet.goToNextRow())
    }
    resultSet.close()
    return feeds
  }

  /**
   * 加载所有文件夹
   */
  static async loadFolders(): Promise<RSSFolderWithUnread[]> {
    return await FolderDAO.getAllFoldersWithUnreadCounts()
  }

  /**
   * 加载各类未读文章数量
   */
  static async loadUnreadCounts(): Promise<UnreadCounts> {
    const store = DatabaseManager.getStore()
    if (!store) throw new Error('数据库未初始化')

    const dbStatus = await DatabaseManager.checkDatabaseStatus()
    if (!dbStatus) throw new Error('数据库状态异常')

    const counts: UnreadCounts = { today: 0, favorites: 0, total: 0 }

    try {
      // 今天的未读
      const todaySql = `
        SELECT COUNT(*) as count FROM articles a LEFT JOIN statuses s ON a.articleID = s.articleID 
        WHERE DATE(a.datePublished) = DATE('now', 'localtime') AND (s.read IS NULL OR s.read = 0)
      `
      const todayResult = await store.querySql(todaySql)
      if (todayResult.rowCount > 0) {
        todayResult.goToFirstRow()
        counts.today = todayResult.getLong(todayResult.getColumnIndex('count'))
      }
      todayResult.close()

      // 收藏的未读
      const favoriteSql = `
        SELECT COUNT(*) as count FROM articles a LEFT JOIN statuses s ON a.articleID = s.articleID 
        WHERE s.starred = 1 AND (s.read IS NULL OR s.read = 0)
      `
      const favoriteResult = await store.querySql(favoriteSql)
      if (favoriteResult.rowCount > 0) {
        favoriteResult.goToFirstRow()
        counts.favorites = favoriteResult.getLong(favoriteResult.getColumnIndex('count'))
      }
      favoriteResult.close()

      // 全部未读
      const totalSql = `
        SELECT COUNT(*) as count FROM articles a LEFT JOIN statuses s ON a.articleID = s.articleID 
        WHERE (s.read IS NULL OR s.read = 0)
      `
      const totalResult = await store.querySql(totalSql)
      if (totalResult.rowCount > 0) {
        totalResult.goToFirstRow()
        counts.total = totalResult.getLong(totalResult.getColumnIndex('count'))
      }
      totalResult.close()
    } catch (e) {
      // 查询失败时返回0
      return { today: 0, favorites: 0, total: 0 };
    }

    return counts
  }

  /**
   * 批量获取指定 Feed 的未读数量
   */
  static async getFeedsUnreadCounts(feedIds: number[]): Promise<Map<number, number>> {
    const result = new Map<number, number>()
    if (feedIds.length === 0) return result

    const store = DatabaseManager.getStore()
    if (!store) return result

    const placeholders = feedIds.map(() => '?').join(',')
    const sql = `
      SELECT f.id,
             COALESCE((
               SELECT COUNT(*)
               FROM articles a
               LEFT JOIN statuses s ON a.articleID = s.articleID
               WHERE a.feedID = f.id AND (s.read IS NULL OR s.read = 0)
             ), 0) as unread_count
      FROM feeds f
      WHERE f.id IN (${placeholders})
    `
    const resultSet = await store.querySql(sql, feedIds)
    if (resultSet.rowCount > 0) {
      resultSet.goToFirstRow()
      do {
        const id = resultSet.getLong(0)
        const count = resultSet.getLong(1)
        result.set(id, count)
      } while (resultSet.goToNextRow())
    }
    resultSet.close()
    return result
  }

  /**
   * 删除指定 Feed 及其相关数据（文章、状态等）
   */
  static async deleteFeed(feedId: number): Promise<void> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    // 1. 获取该 Feed 的所有文章 ID
    const articleResultSet = await store.querySql('SELECT articleID FROM articles WHERE feedID = ?', [feedId])
    const articleIds: string[] = []
    if (articleResultSet.rowCount > 0) {
      articleResultSet.goToFirstRow()
      do {
        articleIds.push(articleResultSet.getString(0))
      } while (articleResultSet.goToNextRow())
    }
    articleResultSet.close()

    // 2. 逐个删除文章相关记录
    for (const articleId of articleIds) {
      try {
        await store.executeSql('DELETE FROM statuses WHERE articleID = ?', [articleId])
        await store.executeSql('DELETE FROM authorsarticles WHERE articleID = ?', [articleId])
        await store.executeSql('DELETE FROM search WHERE articleID = ?', [articleId])
        await store.executeSql('DELETE FROM syncstatus WHERE articleID = ?', [articleId])
        await store.executeSql('DELETE FROM attachments WHERE articleID = ?', [articleId])
      } catch (_) {
        // 忽略单条删除失败，继续
      }
    }

    // 3. 删除该 Feed 下的所有文章
    await store.executeSql('DELETE FROM articles WHERE feedID = ?', [feedId])

    // 4. 删除 Hub 信息（如果存在）
    try {
      await store.executeSql('DELETE FROM hubs WHERE feedID = ?', [feedId])
    } catch (_) {
      // 忽略失败
    }

    // 5. 最后删除 Feed 本身
    await store.executeSql('DELETE FROM feeds WHERE id = ?', [feedId])
  }
} 