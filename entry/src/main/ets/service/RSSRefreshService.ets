import hilog from '@ohos.hilog'
import backgroundTaskManager from '@ohos.resourceschedule.backgroundTaskManager'
import RSSService, { RSSFetchResult, RSSSyncOptions } from './RSSService'
import PreferencesUtil from '../utils/PreferencesUtil'
import FeedDAO from '../model/FeedDAO'

/**
 * RSS刷新完成回调函数类型
 */
type RefreshCompleteCallback = () => void

/**
 * 刷新状态接口
 */
interface RefreshStatus {
  isRefreshing: boolean
  hasInitialRefreshCompleted: boolean
}

/**
 * RSS刷新服务
 * 负责RSS内容的手动和自动刷新
 */
export class RSSRefreshService {
  private static refreshTimer: number | null = null
  private static isRefreshing: boolean = false
  private static hasInitialRefreshCompleted: boolean = false
  private static readonly AUTO_REFRESH_INTERVAL_MS = 10 * 60 * 1000 // 10分钟
  private static refreshCompleteCallbacks: Set<RefreshCompleteCallback> = new Set()

  /**
   * 注册刷新完成回调
   */
  static registerRefreshCompleteCallback(callback: RefreshCompleteCallback): void {
    RSSRefreshService.refreshCompleteCallbacks.add(callback)
  }

  /**
   * 取消注册刷新完成回调
   */
  static unregisterRefreshCompleteCallback(callback: RefreshCompleteCallback): void {
    RSSRefreshService.refreshCompleteCallbacks.delete(callback)
  }

  /**
   * 通知所有回调函数刷新已完成
   */
  private static notifyRefreshComplete(): void {
    RSSRefreshService.refreshCompleteCallbacks.forEach(callback => {
      try {
        callback()
      } catch (error) {
        // 静默处理回调执行失败
      }
    })
  }

  /**
   * 手动刷新所有RSS源
   */
  static async refreshAllFeeds(): Promise<void> {
    if (RSSRefreshService.isRefreshing) {
      return
    }

    RSSRefreshService.isRefreshing = true

    try {
      const feeds = await FeedDAO.getAllActiveFeeds()
      
      if (feeds.length === 0) {
        return
      }

      let successCount = 0
      let failCount = 0

      for (let i = 0; i < feeds.length; i++) {
        const feed = feeds[i]
        try {
          const result = await RSSService.updateFeedAndArticles(feed.id, { timeout: 5000 })
          successCount++
        } catch (error) {
          failCount++
        }
      }

    } catch (error) {
      // 静默处理刷新错误
    } finally {
      RSSRefreshService.isRefreshing = false
      // 通知所有注册的回调函数刷新已完成
      RSSRefreshService.notifyRefreshComplete()
    }
  }

  /**
   * 执行首次启动刷新
   */
  static async performInitialRefresh(): Promise<void> {
    if (RSSRefreshService.hasInitialRefreshCompleted) {
      return
    }

    try {
      await RSSRefreshService.refreshAllFeeds()
      RSSRefreshService.hasInitialRefreshCompleted = true
      
      // 首次刷新完成后启动定时刷新
      RSSRefreshService.startAutoRefresh()
      
    } catch (error) {
      // 即使首次刷新失败，也要启动定时刷新
      RSSRefreshService.hasInitialRefreshCompleted = true
      RSSRefreshService.startAutoRefresh()
    }
  }

  /**
   * 刷新单个RSS源
   */
  static async refreshSingleFeed(feedId: number): Promise<void> {
    try {
      // 设置5秒超时
      await RSSService.updateFeedAndArticles(feedId, { timeout: 5000 })
    } catch (error) {
      throw new Error('刷新失败')
    }
  }

  /**
   * 启动自动刷新（每10分钟）
   */
  static startAutoRefresh(): void {
    // 如果用户未启用自动刷新，则直接返回
    if (!PreferencesUtil.getAutoRefreshEnabledSync()) {
      return
    }

    try {
      // 停止现有的定时器
      if (RSSRefreshService.refreshTimer) {
        clearInterval(RSSRefreshService.refreshTimer)
      }

      // 启动新的定时器，每10分钟刷新一次
      RSSRefreshService.refreshTimer = setInterval(() => {
        RSSRefreshService.refreshAllFeeds().catch((error: Error) => {
          // 静默处理定时刷新失败
        })
      }, RSSRefreshService.AUTO_REFRESH_INTERVAL_MS)

    } catch (error) {
      // 静默处理启动失败
    }
  }

  /**
   * 停止自动刷新
   */
  static stopAutoRefresh(): void {
    if (RSSRefreshService.refreshTimer) {
      clearInterval(RSSRefreshService.refreshTimer)
      RSSRefreshService.refreshTimer = null
    }
  }

  /**
   * 获取刷新状态
   */
  static getRefreshStatus(): RefreshStatus {
    return {
      isRefreshing: RSSRefreshService.isRefreshing,
      hasInitialRefreshCompleted: RSSRefreshService.hasInitialRefreshCompleted
    }
  }

  /**
   * 重置首次刷新标志
   */
  static resetInitialRefreshFlag(): void {
    RSSRefreshService.hasInitialRefreshCompleted = false
  }

  /**
   * 获取是否正在刷新
   */
  static getIsRefreshing(): boolean {
    return RSSRefreshService.isRefreshing
  }

  /**
   * 初始化RSS刷新服务
   */
  static async initialize(): Promise<void> {
    // 读取首选项，决定是否启用自动刷新
    const enabled = PreferencesUtil.getAutoRefreshEnabledSync()
    if (enabled) {
      // 启动时执行一次刷新并开启定时刷新
      await RSSRefreshService.performInitialRefresh()
    }
  }

  /**
   * 清理资源
   */
  static cleanup(): void {
    RSSRefreshService.stopAutoRefresh()
    RSSRefreshService.isRefreshing = false
    RSSRefreshService.refreshCompleteCallbacks.clear()
  }
}

export default RSSRefreshService 