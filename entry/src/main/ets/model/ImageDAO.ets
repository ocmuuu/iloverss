import relationalStore from '@ohos.data.relationalStore'
import hilog from '@ohos.hilog'
import { DatabaseManager } from './DatabaseManager'

/**
 * 图片缓存数据库实体
 */
export interface ImageCacheDB {
  id: number
  articleID: string
  imageID: string
  url: string
  localPath: string
  mimeType: string | null
  width: number | null
  height: number | null
  sizeInBytes: number | null
  createdAt: string
  updatedAt: string
}

/**
 * 图片缓存写入数据结构
 */
export interface ImageInsertData {
  articleID: string
  imageID: string
  url: string
  localPath: string
  mimeType?: string
  width?: number
  height?: number
  sizeInBytes?: number
}

/**
 * SQL 参数类型
 */
 type SQLParams = Array<string | number | boolean | null>

/**
 * 图片缓存数据访问对象
 */
export class ImageDAO {
  /**
   * ResultSet 映射为 ImageCacheDB
   */
  private static mapResultSetToImage(resultSet: relationalStore.ResultSet): ImageCacheDB {
    const id: number = resultSet.getLong(resultSet.getColumnIndex('id'))
    const articleID: string = resultSet.getString(resultSet.getColumnIndex('articleID'))
    const imageID: string = resultSet.getString(resultSet.getColumnIndex('imageID'))
    const url: string = resultSet.getString(resultSet.getColumnIndex('url'))
    const localPath: string = resultSet.getString(resultSet.getColumnIndex('local_path'))
    const mimeType: string = resultSet.getString(resultSet.getColumnIndex('mimeType'))
    const widthVal: number | null = resultSet.isColumnNull(resultSet.getColumnIndex('width')) ? null : resultSet.getLong(resultSet.getColumnIndex('width'))
    const heightVal: number | null = resultSet.isColumnNull(resultSet.getColumnIndex('height')) ? null : resultSet.getLong(resultSet.getColumnIndex('height'))
    const sizeInBytesVal: number | null = resultSet.isColumnNull(resultSet.getColumnIndex('sizeInBytes')) ? null : resultSet.getLong(resultSet.getColumnIndex('sizeInBytes'))
    const createdAt: string = resultSet.getString(resultSet.getColumnIndex('created_at'))
    const updatedAt: string = resultSet.getString(resultSet.getColumnIndex('updated_at'))

    return {
      id: id,
      articleID: articleID,
      imageID: imageID,
      url: url,
      localPath: localPath,
      mimeType: mimeType,
      width: widthVal,
      height: heightVal,
      sizeInBytes: sizeInBytesVal,
      createdAt: createdAt,
      updatedAt: updatedAt
    }
  }

  /**
   * 根据 URL 获取图片缓存
   */
  static async getImageByUrl(url: string): Promise<ImageCacheDB | null> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      const resultSet = await store.querySql('SELECT * FROM images WHERE url = ?', [url])
      if (resultSet.rowCount > 0) {
        resultSet.goToFirstRow()
        const image: ImageCacheDB = ImageDAO.mapResultSetToImage(resultSet)
        resultSet.close()
        return image
      }
      resultSet.close()
      return null
    } catch (error) {
      hilog.error(0x0000, 'ImageDAO', '根据URL获取图片缓存失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('根据URL获取图片缓存失败')
    }
  }

  /**
   * 写入或更新图片缓存记录
   */
  static async saveOrUpdateImage(data: ImageInsertData): Promise<boolean> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      const sql = `
        INSERT INTO images (articleID, imageID, url, local_path, mimeType, width, height, sizeInBytes, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        ON CONFLICT(articleID, imageID) DO UPDATE SET
          local_path = excluded.local_path,
          mimeType = excluded.mimeType,
          width = excluded.width,
          height = excluded.height,
          sizeInBytes = excluded.sizeInBytes,
          updated_at = CURRENT_TIMESTAMP
      `

      const params: SQLParams = [
        data.articleID,
        data.imageID,
        data.url,
        data.localPath,
        data.mimeType ?? null,
        data.width ?? null,
        data.height ?? null,
        data.sizeInBytes ?? null
      ]

      await store.executeSql(sql, params)
      // hilog.info(0x0000, 'ImageDAO', '图片缓存写入成功: %{public}s', data.url)
      return true
    } catch (error) {
      hilog.error(0x0000, 'ImageDAO', '保存图片缓存失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('保存图片缓存失败')
    }
  }

  /**
   * 根据 URL 删除图片缓存
   */
  static async deleteImageByUrl(url: string): Promise<boolean> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      await store.executeSql('DELETE FROM images WHERE url = ?', [url])
      hilog.info(0x0000, 'ImageDAO', '删除图片缓存成功: %{public}s', url)
      return true
    } catch (error) {
      hilog.error(0x0000, 'ImageDAO', '删除图片缓存失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('删除图片缓存失败')
    }
  }

  /**
   * 根据文章ID获取所有图片记录
   */
  static async getImagesByArticleID(articleID: string): Promise<ImageCacheDB[]> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      const resultSet = await store.querySql('SELECT * FROM images WHERE articleID = ?', [articleID])
      const list: ImageCacheDB[] = []
      if (resultSet.rowCount > 0) {
        resultSet.goToFirstRow()
        do {
          list.push(ImageDAO.mapResultSetToImage(resultSet))
        } while (resultSet.goToNextRow())
      }
      resultSet.close()
      return list
    } catch (error) {
      hilog.error(0x0000, 'ImageDAO', '根据文章ID获取图片失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('根据文章ID获取图片失败')
    }
  }

  /**
   * 更新图片的本地路径
   */
  static async updateLocalPath(articleID: string, imageID: string, localPath: string): Promise<boolean> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      await store.executeSql('UPDATE images SET local_path = ?, updated_at = CURRENT_TIMESTAMP WHERE articleID = ? AND imageID = ?', [localPath, articleID, imageID])
      return true
    } catch (error) {
      hilog.error(0x0000, 'ImageDAO', '更新图片路径失败: %{public}s', JSON.stringify(error) ?? '')
      return false
    }
  }
} 