import relationalStore from '@ohos.data.relationalStore'
import hilog from '@ohos.hilog'
import { DatabaseManager } from './DatabaseManager'

/**
 * 文件夹数据库实体
 */
export interface RSSFolderDB {
  id: number
  name: string
  description: string
  icon: string
  color: string
  sortOrder: number
  isActive: boolean
  createdAt: string
  updatedAt: string
}

/**
 * 创建文件夹时的数据结构
 */
export interface RSSFolderCreateData {
  name: string
  description?: string
  icon?: string
  color?: string
  sortOrder?: number
  isActive?: boolean
}

/**
 * 文件夹更新参数
 */
export interface RSSFolderUpdateParams {
  name?: string
  description?: string
  icon?: string
  color?: string
  sortOrder?: number
  isActive?: boolean
}

/**
 * SQL参数类型
 */
type SQLParams = Array<string | number | boolean | null>

/**
 * 文件夹数据访问对象
 */
export class FolderDAO {
  
  /**
   * 获取所有文件夹
   */
  static async getAllFolders(includeInactive: boolean = false): Promise<RSSFolderDB[]> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      let sql = 'SELECT * FROM folders'
      const params: SQLParams = []
      
      if (!includeInactive) {
        sql += ' WHERE is_active = 1'
      }
      
      sql += ' ORDER BY sort_order ASC, name ASC'
      
      const resultSet = await store.querySql(sql, params)
      const folders: RSSFolderDB[] = []
      
      if (resultSet.rowCount > 0) {
        resultSet.goToFirstRow()
        do {
          folders.push(FolderDAO.mapResultSetToFolder(resultSet))
        } while (resultSet.goToNextRow())
      }
      
      resultSet.close()
      return folders
    } catch (error) {
      hilog.error(0x0000, 'FolderDAO', '获取文件夹列表失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('获取文件夹列表失败')
    }
  }

  /**
   * 根据ID获取文件夹
   */
  static async getFolderByID(id: number): Promise<RSSFolderDB | null> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      const sql = 'SELECT * FROM folders WHERE id = ?'
      const resultSet = await store.querySql(sql, [id])
      
      if (resultSet.rowCount > 0) {
        resultSet.goToFirstRow()
        const folder = FolderDAO.mapResultSetToFolder(resultSet)
        resultSet.close()
        return folder
      }
      
      resultSet.close()
      return null
    } catch (error) {
      hilog.error(0x0000, 'FolderDAO', '根据ID获取文件夹失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('根据ID获取文件夹失败')
    }
  }

  /**
   * 创建文件夹
   */
  static async createFolder(data: RSSFolderCreateData): Promise<number> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      // 获取最大的排序号
      let maxSortOrder = 0
      if (data.sortOrder === undefined) {
        const resultSet = await store.querySql('SELECT MAX(sort_order) as maxOrder FROM folders')
        if (resultSet.rowCount > 0) {
          resultSet.goToFirstRow()
          maxSortOrder = resultSet.getLong(0)
        }
        resultSet.close()
      }

      const sql = `
        INSERT INTO folders (
          name, description, icon, color, sort_order, is_active
        ) VALUES (?, ?, ?, ?, ?, ?)
      `
      const params: SQLParams = [
        data.name,
        data.description || '',
        data.icon || '',
        data.color || '',
        data.sortOrder !== undefined ? data.sortOrder : maxSortOrder + 1,
        data.isActive !== undefined ? (data.isActive ? 1 : 0) : 1
      ]
      
      await store.executeSql(sql, params)
      
      // 获取插入的ID
      const idResultSet = await store.querySql('SELECT last_insert_rowid() as id')
      idResultSet.goToFirstRow()
      const id = idResultSet.getLong(0)
      idResultSet.close()
      
      hilog.info(0x0000, 'FolderDAO', `文件夹创建成功: ${id}`)
      return id
    } catch (error) {
      hilog.error(0x0000, 'FolderDAO', '创建文件夹失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('创建文件夹失败')
    }
  }

  /**
   * 更新文件夹
   */
  static async updateFolder(id: number, params: RSSFolderUpdateParams): Promise<boolean> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      const updates: string[] = []
      const values: SQLParams = []
      
      if (params.name !== undefined) {
        updates.push('name = ?')
        values.push(params.name)
      }
      
      if (params.description !== undefined) {
        updates.push('description = ?')
        values.push(params.description)
      }
      
      if (params.icon !== undefined) {
        updates.push('icon = ?')
        values.push(params.icon)
      }
      
      if (params.color !== undefined) {
        updates.push('color = ?')
        values.push(params.color)
      }
      
      if (params.sortOrder !== undefined) {
        updates.push('sort_order = ?')
        values.push(params.sortOrder)
      }
      
      if (params.isActive !== undefined) {
        updates.push('is_active = ?')
        values.push(params.isActive ? 1 : 0)
      }
      
      if (updates.length === 0) {
        return false
      }
      
      updates.push('updated_at = CURRENT_TIMESTAMP')
      
      const sql = `UPDATE folders SET ${updates.join(', ')} WHERE id = ?`
      values.push(id)
      
      await store.executeSql(sql, values)
      
      hilog.info(0x0000, 'FolderDAO', `文件夹更新成功: ${id}`)
      return true
    } catch (error) {
      hilog.error(0x0000, 'FolderDAO', '更新文件夹失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('更新文件夹失败')
    }
  }

  /**
   * 删除文件夹
   */
  static async deleteFolder(id: number): Promise<boolean> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      // 先将关联的feeds的folder_id设为null
      await store.executeSql('UPDATE feeds SET folder_id = NULL WHERE folder_id = ?', [id])
      
      // 删除文件夹
      await store.executeSql('DELETE FROM folders WHERE id = ?', [id])
      
      hilog.info(0x0000, 'FolderDAO', `文件夹删除成功: ${id}`)
      return true
    } catch (error) {
      hilog.error(0x0000, 'FolderDAO', '删除文件夹失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('删除文件夹失败')
    }
  }

  /**
   * 获取文件夹中的订阅源数量
   */
  static async getFeedCount(id: number): Promise<number> {
    const store = DatabaseManager.getStore()
    if (!store) {
      throw new Error('数据库未初始化')
    }

    try {
      const sql = 'SELECT COUNT(*) as count FROM feeds WHERE folder_id = ?'
      const resultSet = await store.querySql(sql, [id])
      
      let count = 0
      if (resultSet.rowCount > 0) {
        resultSet.goToFirstRow()
        count = resultSet.getLong(0)
      }
      
      resultSet.close()
      return count
    } catch (error) {
      hilog.error(0x0000, 'FolderDAO', '获取文件夹订阅源数量失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('获取文件夹订阅源数量失败')
    }
  }

  /**
   * 将ResultSet映射为文件夹对象
   */
  private static mapResultSetToFolder(resultSet: relationalStore.ResultSet): RSSFolderDB {
    return {
      id: resultSet.getLong(resultSet.getColumnIndex('id')),
      name: resultSet.getString(resultSet.getColumnIndex('name')),
      description: resultSet.getString(resultSet.getColumnIndex('description')) || '',
      icon: resultSet.getString(resultSet.getColumnIndex('icon')) || '',
      color: resultSet.getString(resultSet.getColumnIndex('color')) || '',
      sortOrder: resultSet.getLong(resultSet.getColumnIndex('sort_order')),
      isActive: resultSet.getLong(resultSet.getColumnIndex('is_active')) === 1,
      createdAt: resultSet.getString(resultSet.getColumnIndex('created_at')),
      updatedAt: resultSet.getString(resultSet.getColumnIndex('updated_at'))
    }
  }
}

export default FolderDAO 