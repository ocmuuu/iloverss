import { RSSDataService } from './RSSModel'
import { PreferencesUtil } from '../utils/PreferencesUtil'

/**
 * 简化的文章信息接口
 */
interface SimplifiedArticle {
  id: string
  title: string
  readStatus: boolean
  starredStatus: boolean
}

/**
 * 全局状态管理类
 * 使用 AppStorage 进行跨组件状态管理
 */
export class GlobalState {
  
  /**
   * 初始化全局状态
   */
  static init() {
    console.info('GlobalState', '初始化全局状态管理')
    
    // 当前选中的Feed ID
    AppStorage.setAndLink('selectedFeedId', '')
    
    // 当前选中的文章ID
    AppStorage.setAndLink('selectedArticleId', '')
    
    // 当前文章在列表中的索引
    AppStorage.setAndLink('currentArticleIndex', -1)
    
    // 文章列表总数
    AppStorage.setAndLink('articleListTotal', 0)
    
    // Feed未读数量映射 - 使用字符串存储，因为 AppStorage 不支持 Map
    AppStorage.setAndLink('feedUnreadCountsJson', '{}')
    
    // 文章已读状态映射 - 使用字符串存储
    AppStorage.setAndLink('articleReadStatusJson', '{}')
    
    // 文章收藏状态映射 - 使用字符串存储
    AppStorage.setAndLink('articleStarStatusJson', '{}')
    
    // 键盘导航状态
    AppStorage.setAndLink('keyboardNavigationEnabled', true)
    
    // 刷新触发器
    AppStorage.setAndLink('refreshTrigger', 0)
    
    // 快捷键提示显示状态
    AppStorage.setAndLink('showKeyboardHints', true)
    
    // UI状态管理
    AppStorage.setAndLink('isFirstColumnCollapsed', false)
    AppStorage.setAndLink('isSecondColumnCollapsed', false)
    
    // 文章列表缓存（JSON字符串格式）
    AppStorage.setAndLink('currentArticleListJson', '[]')
    
    console.info('GlobalState', '全局状态初始化完成')
  }
  
  /**
   * 获取Feed未读数量
   */
  static getFeedUnreadCount(feedId: string): number {
    const json = AppStorage.get<string>('feedUnreadCountsJson') || '{}'
    try {
      const counts: ESObject = JSON.parse(json) as ESObject
      if (counts && (counts as ESObject)[feedId] !== undefined) {
        return Number((counts as ESObject)[feedId] as number) || 0
      }
      return 0
    } catch (error) {
      console.error('GlobalState', 'getFeedUnreadCount解析失败:', error)
      return 0
    }
  }
  
  /**
   * 设置Feed未读数量
   */
  static setFeedUnreadCount(feedId: string, count: number) {
    const json = AppStorage.get<string>('feedUnreadCountsJson') || '{}'
    try {
      const counts: ESObject = JSON.parse(json) as ESObject
      if (counts && (counts as ESObject)[feedId] !== undefined) {
        (counts as ESObject)[feedId] = count
        AppStorage.set('feedUnreadCountsJson', JSON.stringify(counts))
      } else {
        const newCounts: ESObject = JSON.parse('{}') as ESObject
        newCounts[feedId] = count
        AppStorage.set('feedUnreadCountsJson', JSON.stringify(newCounts))
      }
    } catch (error) {
      console.error('GlobalState', 'setFeedUnreadCount解析失败:', error)
      const newCounts: ESObject = JSON.parse('{}') as ESObject
      newCounts[feedId] = count
      AppStorage.set('feedUnreadCountsJson', JSON.stringify(newCounts))
    }
  }
  
  /**
   * 获取文章已读状态
   */
  static getArticleReadStatus(articleId: string): boolean {
    const json = AppStorage.get<string>('articleReadStatusJson') || '{}'
    try {
      const status: ESObject = JSON.parse(json) as ESObject
      if (status && (status as ESObject)[articleId] !== undefined) {
        return Boolean((status as ESObject)[articleId])
      }
      return false
    } catch (error) {
      console.error('GlobalState', 'getArticleReadStatus解析失败:', error)
      return false
    }
  }
  
  /**
   * 设置文章已读状态
   */
  static setArticleReadStatus(articleId: string, isRead: boolean) {
    const json = AppStorage.get<string>('articleReadStatusJson') || '{}'
    try {
      const status: ESObject = JSON.parse(json) as ESObject
      if (status && (status as ESObject)[articleId] !== undefined) {
        (status as ESObject)[articleId] = isRead
        AppStorage.set('articleReadStatusJson', JSON.stringify(status))
      } else {
        const newStatus: ESObject = JSON.parse('{}') as ESObject
        newStatus[articleId] = isRead
        AppStorage.set('articleReadStatusJson', JSON.stringify(newStatus))
      }
    } catch (error) {
      console.error('GlobalState', 'setArticleReadStatus解析失败:', error)
      const newStatus: ESObject = JSON.parse('{}') as ESObject
      newStatus[articleId] = isRead
      AppStorage.set('articleReadStatusJson', JSON.stringify(newStatus))
    }
    
    console.info('GlobalState', `文章 ${articleId} 已读状态更新为: ${isRead}`)
  }
  
  /**
   * 获取文章收藏状态
   */
  static getArticleStarStatus(articleId: string): boolean {
    const json = AppStorage.get<string>('articleStarStatusJson') || '{}'
    try {
      const status: ESObject = JSON.parse(json) as ESObject
      if (status && (status as ESObject)[articleId] !== undefined) {
        return Boolean((status as ESObject)[articleId])
      }
      return false
    } catch (error) {
      console.error('GlobalState', 'getArticleStarStatus解析失败:', error)
      return false
    }
  }
  
  /**
   * 设置文章收藏状态
   */
  static setArticleStarStatus(articleId: string, isStarred: boolean) {
    const json = AppStorage.get<string>('articleStarStatusJson') || '{}'
    try {
      const status: ESObject = JSON.parse(json) as ESObject
      if (status && (status as ESObject)[articleId] !== undefined) {
        (status as ESObject)[articleId] = isStarred
        AppStorage.set('articleStarStatusJson', JSON.stringify(status))
      } else {
        const newStatus: ESObject = JSON.parse('{}') as ESObject
        newStatus[articleId] = isStarred
        AppStorage.set('articleStarStatusJson', JSON.stringify(newStatus))
      }
    } catch (error) {
      console.error('GlobalState', 'setArticleStarStatus解析失败:', error)
      const newStatus: ESObject = JSON.parse('{}') as ESObject
      newStatus[articleId] = isStarred
      AppStorage.set('articleStarStatusJson', JSON.stringify(newStatus))
    }
    
    console.info('GlobalState', `文章 ${articleId} 收藏状态更新为: ${isStarred}`)
  }
  
  /**
   * 切换到下一篇文章
   */
  static switchToNextArticle(): Promise<boolean> {
    return new Promise((resolve) => {
      const articles = GlobalState.getCurrentArticleList()
      const totalArticles = articles.length
      const currentId = AppStorage.get<string>('selectedArticleId')
      
      let currentIndex = AppStorage.get<number>('currentArticleIndex') ?? -1
      
      // 索引校正：如果当前ID对应的索引与存储的索引不一致，以ID为准
      if (currentId) {
        const actualIndex = articles.findIndex(a => a.id === currentId)
        if (actualIndex !== -1 && actualIndex !== currentIndex) {
          console.warn('GlobalState', `Next: Index mismatch (Store: ${currentIndex}, Actual: ${actualIndex}). Correcting...`)
          currentIndex = actualIndex
          AppStorage.set('currentArticleIndex', currentIndex)
        }
      }
      
      if (currentIndex < totalArticles - 1) {
        const newIndex = currentIndex + 1
        AppStorage.set('currentArticleIndex', newIndex)
        
        if (articles[newIndex]) {
          AppStorage.set('selectedArticleId', articles[newIndex].id)
          console.info('GlobalState', `Next: Switched to ${articles[newIndex].title} (${newIndex}/${totalArticles})`)
        }
        
        AppStorage.set('refreshTrigger', Date.now())
        resolve(true)
      } else {
        console.info('GlobalState', 'Next: Already at last article')
        resolve(false)
      }
    })
  }

  static switchToPreviousArticle(): Promise<boolean> {
    return new Promise((resolve) => {
      const articles = GlobalState.getCurrentArticleList()
      const currentId = AppStorage.get<string>('selectedArticleId')
      
      let currentIndex = AppStorage.get<number>('currentArticleIndex') ?? -1

      // 索引校正
      if (currentId) {
        const actualIndex = articles.findIndex(a => a.id === currentId)
        if (actualIndex !== -1 && actualIndex !== currentIndex) {
          console.warn('GlobalState', `Prev: Index mismatch (Store: ${currentIndex}, Actual: ${actualIndex}). Correcting...`)
          currentIndex = actualIndex
          AppStorage.set('currentArticleIndex', currentIndex)
        }
      }

      if (currentIndex > 0) {
        const newIndex = currentIndex - 1
        AppStorage.set('currentArticleIndex', newIndex)
        
        if (articles[newIndex]) {
          AppStorage.set('selectedArticleId', articles[newIndex].id)
          console.info('GlobalState', `Prev: Switched to ${articles[newIndex].title} (${newIndex})`)
        }
        
        AppStorage.set('refreshTrigger', Date.now())
        resolve(true)
      } else {
        console.info('GlobalState', 'Prev: Already at first article')
        resolve(false)
      }
    })
  }
  
  /**
   * 更新文章已读状态（通过数据服务）
   */
  static async updateArticleReadStatus(articleId: string, isRead: boolean): Promise<boolean> {
    try {
      const success = await RSSDataService.markArticleAsRead(articleId, isRead)
      if (success) {
        // 更新全局状态
        GlobalState.setArticleReadStatus(articleId, isRead)
        
        // 触发刷新
        AppStorage.set('refreshTrigger', Date.now())
        
        // 重新计算未读数量
        GlobalState.recalculateUnreadCount()
        
        return true
      }
      return false
    } catch (error) {
      console.error('GlobalState', '更新文章已读状态失败:', error)
      return false
    }
  }
  
  /**
   * 更新文章收藏状态（通过数据服务）
   */
  static async updateArticleStarStatus(articleId: string, currentStarStatus: boolean): Promise<boolean> {
    try {
      const success = await RSSDataService.toggleArticleStar(articleId, currentStarStatus)
      if (success) {
        const newStatus = !currentStarStatus
        
        // 更新全局状态
        GlobalState.setArticleStarStatus(articleId, newStatus)
        
        // 触发刷新
        AppStorage.set('refreshTrigger', Date.now())
        
        return true
      }
      return false
    } catch (error) {
      console.error('GlobalState', '更新文章收藏状态失败:', error)
      return false
    }
  }
  
  /**
   * 重新计算未读数量
   */
  static recalculateUnreadCount() {
    const selectedFeedId = AppStorage.get<string>('selectedFeedId') || ''
    if (selectedFeedId) {
      // 这里可以添加具体的未读数量计算逻辑
      // 触发刷新
      AppStorage.set('refreshTrigger', Date.now())
      console.info('GlobalState', '触发未读数量重新计算')
    }
  }
  
  /**
   * 触发全局刷新
   */
  static triggerRefresh() {
    AppStorage.set('refreshTrigger', Date.now())
    console.info('GlobalState', '触发全局刷新')
  }
  
  /**
   * 设置当前选中的文章
   */
  static setSelectedArticle(articleId: string, index: number) {
    AppStorage.set('selectedArticleId', articleId)
    AppStorage.set('currentArticleIndex', index)
    console.info('GlobalState', `设置选中文章: ${articleId}, 索引: ${index}`)
  }
  
  /**
   * 设置文章列表总数
   */
  static setArticleListTotal(total: number) {
    AppStorage.set('articleListTotal', total)
    console.info('GlobalState', `设置文章列表总数: ${total}`)
  }
  
  /**
   * 获取当前是否可以切换到上一篇
   */
  static canGoPrevious(): boolean {
    const currentIndex = AppStorage.get<number>('currentArticleIndex') || 0
    return currentIndex > 0
  }
  
  /**
   * 获取当前是否可以切换到下一篇
   */
  static canGoNext(): boolean {
    const currentIndex = AppStorage.get<number>('currentArticleIndex') || 0
    const totalArticles = AppStorage.get<number>('articleListTotal') || 0
    return currentIndex < totalArticles - 1
  }

  /**
   * 切换第一栏折叠状态
   */
  private static toggleFirstColumnNoPersist() {
    const current = AppStorage.get<boolean>('isFirstColumnCollapsed') || false
    AppStorage.set('isFirstColumnCollapsed', !current)
    console.info('GlobalState', `切换第一栏折叠状态: ${!current}`)
  }

  /**
   * 获取第一栏折叠状态（运行时）
   */
  static getFirstColumnCollapsed(): boolean {
    return AppStorage.get<boolean>('isFirstColumnCollapsed') ?? false
  }

  /**
   * 设置第一栏折叠状态，同时持久化到首选项
   */
  static setFirstColumnCollapsed(isCollapsed: boolean) {
    AppStorage.set('isFirstColumnCollapsed', isCollapsed)
    // 持久化
    try {
      // 使用同步方法，避免异步未完成就退出
      // 此处直接调用会在未初始化时抛错，所以捕获
      // eslint-disable-next-line @typescript-eslint/no-unused-vars
      PreferencesUtil.saveFirstColumnCollapseStateSync(isCollapsed)
    } catch (e) {
      console.warn('GlobalState', '首选项未初始化或保存失败, err=', JSON.stringify(e))
    }
  }

  /**
   * 切换折叠状态（供旧代码调用）
   */
  static toggleFirstColumn() {
    const current = AppStorage.get<boolean>('isFirstColumnCollapsed') ?? false
    GlobalState.setFirstColumnCollapsed(!current)
  }

  /**
   * 获取第二栏折叠状态（运行时）
   */
  static getSecondColumnCollapsed(): boolean {
    return AppStorage.get<boolean>('isSecondColumnCollapsed') ?? false
  }

  /**
   * 设置第二栏折叠状态，同时持久化到首选项
   */
  static setSecondColumnCollapsed(isCollapsed: boolean) {
    AppStorage.set('isSecondColumnCollapsed', isCollapsed)
    // 持久化
    try {
      PreferencesUtil.saveSecondColumnCollapseStateSync(isCollapsed)
    } catch (e) {
      console.warn('GlobalState', '首选项未初始化或保存失败, err=', JSON.stringify(e))
    }
  }

  /**
   * 切换第二栏折叠状态
   */
  static toggleSecondColumn() {
    const current = AppStorage.get<boolean>('isSecondColumnCollapsed') ?? false
    GlobalState.setSecondColumnCollapsed(!current)
  }

  /**
   * 处理Feed点击（全局状态管理）
   */
  static selectFeed(feedId: string) {
    AppStorage.set('selectedFeedId', feedId)
    AppStorage.set('selectedArticleId', '')
    AppStorage.set('currentArticleIndex', -1)
    AppStorage.set('articleListTotal', 0)
    AppStorage.set('currentArticleListJson', '[]')
    console.info('GlobalState', `选择Feed: ${feedId}`)
  }

  /**
   * 处理文章点击（全局状态管理）
   */
  static selectArticle(articleId: string, index: number) {
    AppStorage.set('selectedArticleId', articleId)
    AppStorage.set('currentArticleIndex', index)
    console.info('GlobalState', `选择文章: ${articleId}, 索引: ${index}`)
  }

  /**
   * 设置当前文章列表
   */
  static setCurrentArticleList(articles: SimplifiedArticle[]) {
    // 只保存文章的基本信息，不缓存内容和摘要以节省内存
    const simpleList: SimplifiedArticle[] = articles.map((item): SimplifiedArticle => {
      const simple: SimplifiedArticle = {
        id: item.id,
        title: item.title,
        readStatus: item.readStatus,
        starredStatus: item.starredStatus
      }
      return simple
    })
    AppStorage.set('currentArticleListJson', JSON.stringify(simpleList))
    console.info('GlobalState', `设置当前文章列表: ${articles.length} 篇文章`)
  }

  /**
   * 获取当前文章列表
   */
  static getCurrentArticleList(): SimplifiedArticle[] {
    const json = AppStorage.get<string>('currentArticleListJson') || '[]'
    try {
      return JSON.parse(json) as SimplifiedArticle[]
    } catch (error) {
      console.error('GlobalState', '解析文章列表失败:', error)
      return []
    }
  }

  /**
   * 获取当前文章
   */
  static getCurrentArticle(): SimplifiedArticle | undefined {
    const articles = GlobalState.getCurrentArticleList()
    const currentIndex = AppStorage.get<number>('currentArticleIndex') || -1
    
    if (currentIndex >= 0 && currentIndex < articles.length) {
      return articles[currentIndex]
    }
    return undefined
  }

  /**
   * 获取下一篇文章
   */
  static getNextArticle(): SimplifiedArticle | undefined {
    const articles = GlobalState.getCurrentArticleList()
    const currentIndex = AppStorage.get<number>('currentArticleIndex') || -1
    
    if (currentIndex >= 0 && currentIndex < articles.length - 1) {
      return articles[currentIndex + 1]
    }
    return undefined
  }

  /**
   * 获取上一篇文章
   */
  static getPreviousArticle(): SimplifiedArticle | undefined {
    const articles = GlobalState.getCurrentArticleList()
    const currentIndex = AppStorage.get<number>('currentArticleIndex') || -1
    
    if (currentIndex > 0 && currentIndex < articles.length) {
      return articles[currentIndex - 1]
    }
    return undefined
  }
} 