import dataPreferences from '@ohos.data.preferences'
import { RSSFeed } from '../model/RSSModel'

// 首选项名称
const PREFERENCES_NAME = 'RSSReaderPreferences'

// 存储键名接口
interface KeysInterface {
  IS_FIRST_COLUMN_COLLAPSED: string
  SELECTED_FEED_ID: string
  AUTO_REFRESH_ENABLED: string
  AUTO_REFRESH_INTERVAL: string
  FIRST_COLUMN_WIDTH: string
  SECOND_COLUMN_WIDTH: string
  IMAGE_CACHE_ENABLED: string
}

// 存储键名
const KEYS: KeysInterface = {
  IS_FIRST_COLUMN_COLLAPSED: 'isFirstColumnCollapsed', // 第一栏是否折叠
  SELECTED_FEED_ID: 'selectedFeedId', // 当前选中的RSS源ID
  AUTO_REFRESH_ENABLED: 'autoRefreshEnabled', // 自动刷新是否启用
  AUTO_REFRESH_INTERVAL: 'autoRefreshInterval', // 自动刷新间隔（分钟）
  FIRST_COLUMN_WIDTH: 'firstColumnWidth', // 第一栏宽度
  SECOND_COLUMN_WIDTH: 'secondColumnWidth', // 第二栏宽度
  IMAGE_CACHE_ENABLED: 'imageCacheEnabled' // 图片缓存是否启用
}

/**
 * 首选项工具类
 * 用于管理应用的状态持久化
 */
export class PreferencesUtil {
  private static preferences: dataPreferences.Preferences | null = null

  /**
   * 检查是否已初始化
   * @returns 是否已初始化
   */
  static isInitialized(): boolean {
    return PreferencesUtil.preferences !== null
  }

  /**
   * 初始化首选项
   * @param context 应用上下文
   */
  static async init(context: Context): Promise<boolean> {
    try {
      PreferencesUtil.preferences = await dataPreferences.getPreferences(context, PREFERENCES_NAME)
      return true
    } catch (error) {
      return false
    }
  }

  /**
   * 同步方式初始化首选项（可选）
   * @param context 应用上下文
   */
  static initSync(context: Context): boolean {
    try {
      const options: dataPreferences.Options = { name: PREFERENCES_NAME }
      PreferencesUtil.preferences = dataPreferences.getPreferencesSync(context, options)
      return true
    } catch (error) {
      return false
    }
  }

  /**
   * 保存第一栏折叠状态
   * @param isCollapsed 是否折叠
   */
  static async saveFirstColumnCollapseState(isCollapsed: boolean): Promise<void> {
    if (!PreferencesUtil.preferences) {
      console.error('PreferencesUtil', '首选项未初始化')
      return
    }

    try {
      await PreferencesUtil.preferences.put(KEYS.IS_FIRST_COLUMN_COLLAPSED, isCollapsed)
      await PreferencesUtil.preferences.flush()
      console.info('PreferencesUtil', `保存第一栏折叠状态: ${isCollapsed}`)
    } catch (error) {
      console.error('PreferencesUtil', '保存第一栏折叠状态失败:', JSON.stringify(error))
    }
  }

  /**
   * 同步保存第一栏折叠状态
   * @param isCollapsed 是否折叠
   */
  static saveFirstColumnCollapseStateSync(isCollapsed: boolean): void {
    if (!PreferencesUtil.preferences) {
      console.error('PreferencesUtil', '首选项未初始化')
      return
    }

    try {
      PreferencesUtil.preferences.putSync(KEYS.IS_FIRST_COLUMN_COLLAPSED, isCollapsed)
      PreferencesUtil.preferences.flush() // 异步刷新到磁盘
      console.info('PreferencesUtil', `同步保存第一栏折叠状态: ${isCollapsed}`)
    } catch (error) {
      console.error('PreferencesUtil', '同步保存第一栏折叠状态失败:', JSON.stringify(error))
    }
  }

  /**
   * 获取第一栏折叠状态
   * @returns 折叠状态，默认为false
   */
  static async getFirstColumnCollapseState(): Promise<boolean> {
    if (!PreferencesUtil.preferences) {
      console.error('PreferencesUtil', '首选项未初始化')
      return false
    }

    try {
      const isCollapsed = await PreferencesUtil.preferences.get(KEYS.IS_FIRST_COLUMN_COLLAPSED, false) as boolean
      console.info('PreferencesUtil', `获取第一栏折叠状态: ${isCollapsed}`)
      return isCollapsed
    } catch (error) {
      console.error('PreferencesUtil', '获取第一栏折叠状态失败:', JSON.stringify(error))
      return false
    }
  }

  /**
   * 同步获取第一栏折叠状态
   * @returns 折叠状态，默认为false
   */
  static getFirstColumnCollapseStateSync(): boolean {
    if (!PreferencesUtil.preferences) {
      console.error('PreferencesUtil', '首选项未初始化')
      return false
    }

    try {
      const isCollapsed = PreferencesUtil.preferences.getSync(KEYS.IS_FIRST_COLUMN_COLLAPSED, false) as boolean
      return isCollapsed
    } catch (error) {
      return false
    }
  }

  /**
   * 保存当前选中的RSS源ID
   * @param feedId RSS源ID
   */
  static async saveSelectedFeedId(feedId: string): Promise<void> {
    if (!PreferencesUtil.preferences) {
      return
    }

    try {
      await PreferencesUtil.preferences.put(KEYS.SELECTED_FEED_ID, feedId)
      await PreferencesUtil.preferences.flush()
    } catch (error) {
      console.error('PreferencesUtil', '保存选中的RSS源ID失败:', JSON.stringify(error))
    }
  }

  /**
   * 同步保存当前选中的RSS源ID
   * @param feedId RSS源ID
   */
  static saveSelectedFeedIdSync(feedId: string): void {
    if (!PreferencesUtil.preferences) {
      return
    }

    try {
      PreferencesUtil.preferences.putSync(KEYS.SELECTED_FEED_ID, feedId)
      PreferencesUtil.preferences.flush() // 异步刷新到磁盘
      console.info('PreferencesUtil', `同步保存选中的RSS源ID: ${feedId}`)
    } catch (error) {
      console.error('PreferencesUtil', '同步保存选中的RSS源ID失败:', JSON.stringify(error))
    }
  }

  /**
   * 获取当前选中的RSS源ID
   * @returns RSS源ID，如果没有则返回空字符串
   */
  static async getSelectedFeedId(): Promise<string> {
    if (!PreferencesUtil.preferences) {
      return ''
    }

    try {
      const feedId = await PreferencesUtil.preferences.get(KEYS.SELECTED_FEED_ID, '') as string
      return feedId
    } catch (error) {
      console.error('PreferencesUtil', '获取选中的RSS源ID失败:', JSON.stringify(error))
      return ''
    }
  }

  /**
   * 同步获取当前选中的RSS源ID
   * @returns RSS源ID，如果没有则返回空字符串
   */
  static getSelectedFeedIdSync(): string {
    if (!PreferencesUtil.preferences) {
      return ''
    }

    try {
      const feedId = PreferencesUtil.preferences.getSync(KEYS.SELECTED_FEED_ID, '') as string
      console.info('PreferencesUtil', `同步获取选中的RSS源ID: ${feedId}`)
      return feedId
    } catch (error) {
      console.error('PreferencesUtil', '同步获取选中的RSS源ID失败:', JSON.stringify(error))
      return ''
    }
  }

  /**
   * 检查是否有保存的状态
   * @returns 是否有保存的状态
   */
  static hasSavedState(): boolean {
    if (!PreferencesUtil.preferences) {
      return false
    }

    try {
      const hasCollapsedState = PreferencesUtil.preferences.hasSync(KEYS.IS_FIRST_COLUMN_COLLAPSED)
      const hasFeedId = PreferencesUtil.preferences.hasSync(KEYS.SELECTED_FEED_ID)
      return hasCollapsedState || hasFeedId
    } catch (error) {
      console.error('PreferencesUtil', '检查保存状态失败:', JSON.stringify(error))
      return false
    }
  }

  /**
   * 清除所有保存的数据
   */
  static async clear(): Promise<void> {
    if (!PreferencesUtil.preferences) {
      console.error('PreferencesUtil', '首选项未初始化')
      return
    }

    try {
      await PreferencesUtil.preferences.clear()
      await PreferencesUtil.preferences.flush()
      console.info('PreferencesUtil', '清除所有数据成功')
    } catch (error) {
      console.error('PreferencesUtil', '清除所有数据失败:', JSON.stringify(error))
    }
  }

  /**
   * 保存自动刷新启用状态
   * @param enabled 是否启用自动刷新
   */
  static async saveAutoRefreshEnabled(enabled: boolean): Promise<void> {
    if (!PreferencesUtil.preferences) {
      console.error('PreferencesUtil', '首选项未初始化')
      return
    }

    try {
      await PreferencesUtil.preferences.put(KEYS.AUTO_REFRESH_ENABLED, enabled)
      await PreferencesUtil.preferences.flush()
      console.info('PreferencesUtil', `保存自动刷新启用状态: ${enabled}`)
    } catch (error) {
      console.error('PreferencesUtil', '保存自动刷新启用状态失败:', JSON.stringify(error))
    }
  }

  /**
   * 同步保存自动刷新启用状态
   * @param enabled 是否启用自动刷新
   */
  static saveAutoRefreshEnabledSync(enabled: boolean): void {
    if (!PreferencesUtil.preferences) {
      console.error('PreferencesUtil', '首选项未初始化')
      return
    }

    try {
      PreferencesUtil.preferences.putSync(KEYS.AUTO_REFRESH_ENABLED, enabled)
      PreferencesUtil.preferences.flush()
      console.info('PreferencesUtil', `同步保存自动刷新启用状态: ${enabled}`)
    } catch (error) {
      console.error('PreferencesUtil', '同步保存自动刷新启用状态失败:', JSON.stringify(error))
    }
  }

  /**
   * 获取自动刷新启用状态
   * @returns 自动刷新启用状态，默认为true
   */
  static async getAutoRefreshEnabled(): Promise<boolean> {
    if (!PreferencesUtil.preferences) {
      console.error('PreferencesUtil', '首选项未初始化')
      return true
    }

    try {
      const enabled = await PreferencesUtil.preferences.get(KEYS.AUTO_REFRESH_ENABLED, true) as boolean
      console.info('PreferencesUtil', `获取自动刷新启用状态: ${enabled}`)
      return enabled
    } catch (error) {
      console.error('PreferencesUtil', '获取自动刷新启用状态失败:', JSON.stringify(error))
      return true
    }
  }

  /**
   * 同步获取自动刷新启用状态
   * @returns 自动刷新启用状态，默认为true
   */
  static getAutoRefreshEnabledSync(): boolean {
    if (!PreferencesUtil.preferences) {
      console.error('PreferencesUtil', '首选项未初始化')
      return true
    }

    try {
      const enabled = PreferencesUtil.preferences.getSync(KEYS.AUTO_REFRESH_ENABLED, true) as boolean
      console.info('PreferencesUtil', `同步获取自动刷新启用状态: ${enabled}`)
      return enabled
    } catch (error) {
      console.error('PreferencesUtil', '同步获取自动刷新启用状态失败:', JSON.stringify(error))
      return true
    }
  }

  /**
   * 保存图片缓存启用状态
   * @param enabled 是否启用图片缓存
   */
  static async saveImageCacheEnabled(enabled: boolean): Promise<void> {
    if (!PreferencesUtil.preferences) {
      console.error('PreferencesUtil', '首选项未初始化')
      return
    }

    try {
      await PreferencesUtil.preferences.put(KEYS.IMAGE_CACHE_ENABLED, enabled)
      await PreferencesUtil.preferences.flush()
      console.info('PreferencesUtil', `保存图片缓存启用状态: ${enabled}`)
    } catch (error) {
      console.error('PreferencesUtil', '保存图片缓存启用状态失败:', JSON.stringify(error))
    }
  }

  /**
   * 同步保存图片缓存启用状态
   * @param enabled 是否启用图片缓存
   */
  static saveImageCacheEnabledSync(enabled: boolean): void {
    if (!PreferencesUtil.preferences) {
      console.error('PreferencesUtil', '首选项未初始化')
      return
    }

    try {
      PreferencesUtil.preferences.putSync(KEYS.IMAGE_CACHE_ENABLED, enabled)
      PreferencesUtil.preferences.flush()
      console.info('PreferencesUtil', `同步保存图片缓存启用状态: ${enabled}`)
    } catch (error) {
      console.error('PreferencesUtil', '同步保存图片缓存启用状态失败:', JSON.stringify(error))
    }
  }

  /**
   * 获取图片缓存启用状态
   * @returns 图片缓存启用状态，默认为false
   */
  static async getImageCacheEnabled(): Promise<boolean> {
    if (!PreferencesUtil.preferences) {
      console.error('PreferencesUtil', '首选项未初始化')
      return false
    }

    try {
      const enabled = await PreferencesUtil.preferences.get(KEYS.IMAGE_CACHE_ENABLED, false) as boolean
      console.info('PreferencesUtil', `获取图片缓存启用状态: ${enabled}`)
      return enabled
    } catch (error) {
      console.error('PreferencesUtil', '获取图片缓存启用状态失败:', JSON.stringify(error))
      return false
    }
  }

  /**
   * 同步获取图片缓存启用状态
   * @returns 图片缓存启用状态，默认为false
   */
  static getImageCacheEnabledSync(): boolean {
    if (!PreferencesUtil.preferences) {
      console.error('PreferencesUtil', '首选项未初始化')
      return false
    }

    try {
      const enabled = PreferencesUtil.preferences.getSync(KEYS.IMAGE_CACHE_ENABLED, false) as boolean
      console.info('PreferencesUtil', `同步获取图片缓存启用状态: ${enabled}`)
      return enabled
    } catch (error) {
      console.error('PreferencesUtil', '同步获取图片缓存启用状态失败:', JSON.stringify(error))
      return false
    }
  }

  /**
   * 保存自动刷新间隔（分钟）
   * @param minutes 刷新间隔（分钟）
   */
  static async saveAutoRefreshInterval(minutes: number): Promise<void> {
    if (!PreferencesUtil.preferences) {
      console.error('PreferencesUtil', '首选项未初始化')
      return
    }

    try {
      await PreferencesUtil.preferences.put(KEYS.AUTO_REFRESH_INTERVAL, minutes)
      await PreferencesUtil.preferences.flush()
      console.info('PreferencesUtil', `保存自动刷新间隔: ${minutes}分钟`)
    } catch (error) {
      console.error('PreferencesUtil', '保存自动刷新间隔失败:', JSON.stringify(error))
    }
  }

  /**
   * 同步保存自动刷新间隔（分钟）
   * @param minutes 刷新间隔（分钟）
   */
  static saveAutoRefreshIntervalSync(minutes: number): void {
    if (!PreferencesUtil.preferences) {
      console.error('PreferencesUtil', '首选项未初始化')
      return
    }

    try {
      PreferencesUtil.preferences.putSync(KEYS.AUTO_REFRESH_INTERVAL, minutes)
      PreferencesUtil.preferences.flush()
      console.info('PreferencesUtil', `同步保存自动刷新间隔: ${minutes}分钟`)
    } catch (error) {
      console.error('PreferencesUtil', '同步保存自动刷新间隔失败:', JSON.stringify(error))
    }
  }

  /**
   * 获取自动刷新间隔（分钟）
   * @returns 刷新间隔，默认为30分钟
   */
  static async getAutoRefreshInterval(): Promise<number> {
    if (!PreferencesUtil.preferences) {
      console.error('PreferencesUtil', '首选项未初始化')
      return 30
    }

    try {
      const minutes = await PreferencesUtil.preferences.get(KEYS.AUTO_REFRESH_INTERVAL, 30) as number
      console.info('PreferencesUtil', `获取自动刷新间隔: ${minutes}分钟`)
      return minutes
    } catch (error) {
      console.error('PreferencesUtil', '获取自动刷新间隔失败:', JSON.stringify(error))
      return 30
    }
  }

  /**
   * 同步获取自动刷新间隔（分钟）
   * @returns 刷新间隔，默认为30分钟
   */
  static getAutoRefreshIntervalSync(): number {
    if (!PreferencesUtil.preferences) {
      console.error('PreferencesUtil', '首选项未初始化')
      return 30
    }

    try {
      const minutes = PreferencesUtil.preferences.getSync(KEYS.AUTO_REFRESH_INTERVAL, 30) as number
      console.info('PreferencesUtil', `同步获取自动刷新间隔: ${minutes}分钟`)
      return minutes
    } catch (error) {
      console.error('PreferencesUtil', '同步获取自动刷新间隔失败:', JSON.stringify(error))
      return 30
    }
  }

  /**
   * 获取所有存储的数据（用于调试）
   */
  static async getAllData(): Promise<Record<string, dataPreferences.ValueType>> {
    if (!PreferencesUtil.preferences) {
      console.error('PreferencesUtil', '首选项未初始化')
      return {}
    }

    try {
      const allData = await PreferencesUtil.preferences.getAll()
      console.info('PreferencesUtil', '获取所有数据:', JSON.stringify(allData))
      return allData as Record<string, dataPreferences.ValueType>
    } catch (error) {
      console.error('PreferencesUtil', '获取所有数据失败:', JSON.stringify(error))
      return {}
    }
  }

  /**
   * 同步保存第一栏宽度（像素）
   * @param width 宽度
   */
  static saveFirstColumnWidthSync(width: number): void {
    if (!PreferencesUtil.preferences) {
      console.error('PreferencesUtil', '首选项未初始化')
      return
    }

    try {
      PreferencesUtil.preferences.putSync(KEYS.FIRST_COLUMN_WIDTH, width)
      PreferencesUtil.preferences.flush()
      console.info('PreferencesUtil', `同步保存第一栏宽度: ${width}`)
    } catch (error) {
      console.error('PreferencesUtil', '同步保存第一栏宽度失败:', JSON.stringify(error))
    }
  }

  /**
   * 同步获取第一栏宽度（像素）
   * @returns 宽度，默认为250
   */
  static getFirstColumnWidthSync(): number {
    if (!PreferencesUtil.preferences) {
      console.error('PreferencesUtil', '首选项未初始化')
      return 250
    }

    try {
      const width = PreferencesUtil.preferences.getSync(KEYS.FIRST_COLUMN_WIDTH, 250) as number
      return width
    } catch (error) {
      console.error('PreferencesUtil', '同步获取第一栏宽度失败:', JSON.stringify(error))
      return 250
    }
  }

  /**
   * 同步保存第二栏宽度（像素）
   * @param width 宽度
   */
  static saveSecondColumnWidthSync(width: number): void {
    if (!PreferencesUtil.preferences) {
      console.error('PreferencesUtil', '首选项未初始化')
      return
    }

    try {
      PreferencesUtil.preferences.putSync(KEYS.SECOND_COLUMN_WIDTH, width)
      PreferencesUtil.preferences.flush()
      console.info('PreferencesUtil', `同步保存第二栏宽度: ${width}`)
    } catch (error) {
      console.error('PreferencesUtil', '同步保存第二栏宽度失败:', JSON.stringify(error))
    }
  }

  /**
   * 同步获取第二栏宽度（像素）
   * @returns 宽度，默认为310
   */
  static getSecondColumnWidthSync(): number {
    if (!PreferencesUtil.preferences) {
      console.error('PreferencesUtil', '首选项未初始化')
      return 310
    }

    try {
      const width = PreferencesUtil.preferences.getSync(KEYS.SECOND_COLUMN_WIDTH, 310) as number
      return width
    } catch (error) {
      console.error('PreferencesUtil', '同步获取第二栏宽度失败:', JSON.stringify(error))
      return 310
    }
  }
}

export default PreferencesUtil 