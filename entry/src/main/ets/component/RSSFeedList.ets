import { RSSFeed, RSSArticle, mockRSSFeeds, RSSDataService } from '../model/RSSModel'
import RSSRefreshService from '../service/RSSRefreshService'
import relationalStore from '@ohos.data.relationalStore'
import { DatabaseManager } from '../model/DatabaseManager'
import type { RSSFeedDB } from '../model/FeedDAO'
import { FeedDAO, type RSSFeedCreateData } from '../model/FeedDAO'
import type { RSSFolderDB } from '../model/FolderDAO'
import { FolderDAO } from '../model/FolderDAO'
import pasteboard from '@ohos.pasteboard'
import { FaviconDownloader } from '../utils/FaviconDownloader'
import RSSService from '../service/RSSService'
import { ParsedFeed } from '../utils/feed/ParsedFeed'
import { common } from '@kit.AbilityKit'
import { FeedDataService, type RSSFeedWithUnread } from '../service/FeedDataService'
import type { RSSFolderWithUnread } from '../model/FolderDAO'
import { OPMLService } from '../service/OPMLService'
import PreferencesUtil from '../utils/PreferencesUtil'

@Component
export struct RSSFeedList {
  @State feeds: RSSFeedWithUnread[] = []
  @State folders: RSSFolderWithUnread[] = []
  @State expandedFolders: Set<number> = new Set() // 展开的文件夹ID集合
  @State isLoading: boolean = false
  @State error: string | null = null
  @State operationError: string | null = null // 操作错误信息（显示在底部）
  @State specialFeeds: RSSFeed[] = []
  @State todayUnreadCount: number = 0
  @State favoriteUnreadCount: number = 0
  @State totalUnreadCount: number = 0
  @State selectedFeedId: string | null = null // 当前选中的源ID
  @State uiUpdateTrigger: number = 0  // 用于强制触发UI更新

  
  // 刷新进度相关状态
  @State refreshProgress: string = '' // 刷新进度文本
  @State totalFeedsToRefresh: number = 0 // 总共需要刷新的FEED数量
  @State currentRefreshIndex: number = 0 // 当前刷新的FEED索引
  @State currentRefreshingFeed: string = '' // 当前正在刷新的FEED名称
  
  // 文件夹重命名相关状态
  @State editingFolderId: number | null = null // 正在编辑的文件夹ID
  @State editingFolderName: string = '' // 编辑中的文件夹名称
  
  // 添加功能相关状态
  @State showAddInput: boolean = false // 是否显示添加输入框
  @State addInputType: 'subscription' | 'folder' | 'icon' | null = null // 添加类型：订阅、文件夹或图标
  @State addInputValue: string = '' // 添加输入框的值
  
  // 图标设置相关状态
  @State settingIconFeedId: number | null = null // 正在设置图标的FEED ID
  
  // 自动刷新开关状态
  @State autoRefreshEnabled: boolean = true
  @State imageCacheEnabled: boolean = false // 图片缓存开关，默认关闭
  
  // 点击RSS源的回调
  onFeedClick?: (feed: RSSFeed) => void
  // 组件引用回调
  onRef?: (ref: RSSFeedList) => void

  // RSS刷新完成后的回调，用于在刷新结束后更新未读数量
  private refreshCompleteHandler: () => void = async () => {
    await this.refreshUnreadCounts()
  }

  @State isRefreshing: boolean = false // 刷新状态

  async aboutToAppear() {
    // 注册刷新完成回调，确保刷新结束后更新未读数量
    RSSRefreshService.registerRefreshCompleteCallback(this.refreshCompleteHandler)

    this.initializeSpecialFeeds()
    
    // 读取自动刷新设置
    try {
      this.autoRefreshEnabled = await PreferencesUtil.getAutoRefreshEnabled()
    } catch(_) {
      this.autoRefreshEnabled = true
    }

    // 读取图片缓存设置
    try {
      this.imageCacheEnabled = await PreferencesUtil.getImageCacheEnabled()
    } catch(_) {
      this.imageCacheEnabled = false // 默认关闭
    }
    
    // 等待数据库准备就绪
    let retryCount = 0
    const maxRetries = 30  // 进一步增加重试次数
    let dbReady = false
    
    while (retryCount < maxRetries) {
      // 首先检查DatabaseManager是否已初始化
      if (DatabaseManager.isInitializedSync()) {
      const store = DatabaseManager.getStore()
      if (store) {
          // 检查数据库状态，确保表已创建
          try {
            const dbStatus = await DatabaseManager.checkDatabaseStatus()
            if (dbStatus) {
              dbReady = true
        break
            }
          } catch (error) {
            // 继续等待
          }
        }
      }
      
      await new Promise<void>(resolve => setTimeout(resolve, 300))
      retryCount++
    }
    
    if (!dbReady) {
      this.error = '数据库初始化失败，请重启应用'
      return
    }
    
    // 使用与手动刷新相同的逻辑来确保UI正确更新
    this.isLoading = true
    
    try {
      // 并行加载feeds、文件夹和未读数量（与手动刷新保持一致）
      await Promise.all([
        this.loadFeeds(),
        this.loadFolders(),
        this.loadUnreadCounts()
      ])
      
      // 设置组件引用（在数据加载完成后）
    if (this.onRef) {
      this.onRef(this)
    }

      // 初始加载后，静默更新各级未读数量（包括文件夹）
      await this.updateUnreadCountsSilently()

    } catch (error) {
      this.error = '数据加载失败'
    } finally {
      this.isLoading = false
    }
  }

  aboutToDisappear() {
    // 注销刷新完成回调，防止内存泄漏
    RSSRefreshService.unregisterRefreshCompleteCallback(this.refreshCompleteHandler)
  }

  // 初始化特殊标签
  private initializeSpecialFeeds() {
    this.specialFeeds = [
      {
        id: "today",
        folderId: null,
        title: "今天",
        description: "今日文章",
        url: "",
        favicon: $r("app.media.today"),
        unreadCount: 0
      },
      {
        id: "favorites",
        folderId: null,
        title: "收藏",
        description: "收藏的文章",
        url: "",
        favicon: $r("app.media.star"),
        unreadCount: 0
      },
      {
        id: "unread",
        folderId: null,
        title: "全部未读",
        description: "所有未读文章",
        url: "",
        favicon: $r("app.media.unread"),
        unreadCount: 0
      }
    ]
  }

  // 加载未读数量
  private async loadUnreadCounts() {
    try {
      const counts = await FeedDataService.loadUnreadCounts()
      this.todayUnreadCount = counts.today
      this.favoriteUnreadCount = counts.favorites
      this.totalUnreadCount = counts.total

      // 调用静默更新方法来更新特殊标签显示
      this.updateSpecialFeedsUnreadCountsSilently()
    } catch (error) {
      // 如果查询失败，设置为0
      this.todayUnreadCount = 0
      this.favoriteUnreadCount = 0
      this.totalUnreadCount = 0

      // 即使查询失败，也要更新特殊标签显示
      this.updateSpecialFeedsUnreadCountsSilently()
    }
  }

  async loadFeeds() {
    try {
      this.error = null
      this.feeds = await FeedDataService.loadFeeds()
    } catch (error) {
      if (error instanceof Error) {
        this.error = error.message
      } else {
        this.error = String(error)
      }
    }
  }

  async loadFolders() {
    try {
      this.folders = await FeedDataService.loadFolders()
    } catch (error) {
      // 即使文件夹加载失败，也不影响RSS源的显示
      this.folders = []
    }
  }

  // 设置选中的源
  setSelectedFeed(feedId: string | null) {
    this.selectedFeedId = feedId
  }

  // 切换文件夹展开状态
  toggleFolderExpanded(folderId: number) {
    const newExpandedFolders = new Set(this.expandedFolders)
    if (newExpandedFolders.has(folderId)) {
      newExpandedFolders.delete(folderId)
    } else {
      newExpandedFolders.add(folderId)
    }
    this.expandedFolders = newExpandedFolders
  }

  // 复制FEED地址到剪贴板
  async copyFeedUrl(feed: RSSFeedWithUnread) {
    try {
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, feed.url)
      const systemPasteboard = pasteboard.getSystemPasteboard()
      await systemPasteboard.setData(pasteData)
      // 这里可以添加Toast提示
    } catch (error) {
      // 复制失败
    }
  }

  // 移动FEED到指定文件夹
  async moveFeedToFolder(feed: RSSFeedWithUnread, folderId: number | null) {
    try {
      // 更新数据库中的FEED文件夹关联
      await FeedDAO.updateFeed(feed.id, { folderId: folderId })
      
      // 重新加载数据
      await Promise.all([
        this.loadFeeds(),
        this.loadFolders()
      ])
      
      // 更新未读数量并刷新UI
      await this.updateUnreadCountsSilently()
      
    } catch (error) {
      // 将错误信息显示在底部
      this.operationError = `移动失败: ${error}`
      
      // 3秒后自动清除错误信息
      setTimeout(() => {
        this.operationError = null
      }, 3000)
    }
  }

  // 刷新单个FEED
  async refreshSingleFeed(feed: RSSFeedWithUnread) {
    try {
      // 清除之前的操作错误信息
      this.operationError = null
      
      // 显示刷新进度
      this.refreshProgress = `正在刷新: ${feed.title}`
      
      // 调用RSS刷新服务来更新FEED内容
      await RSSRefreshService.refreshSingleFeed(feed.id)
      
      // 刷新完成后更新未读数量
      await this.loadUnreadCounts()
      
      // 静默更新未读数量，确保UI正确显示
      await this.updateUnreadCountsSilently()
      
      this.refreshProgress = `刷新完成: ${feed.title}`
      
      // 2秒后清除成功信息
      setTimeout(() => {
        this.refreshProgress = ''
      }, 2000)
      
    } catch (error) {
      this.refreshProgress = ''
      this.operationError = `刷新失败: ${error}`
      
      // 3秒后自动清除错误信息
      setTimeout(() => {
        this.operationError = null
      }, 3000)
    }
  }

  // 开始编辑文件夹名称
  startEditingFolder(folder: RSSFolderWithUnread) {
    this.editingFolderId = folder.id
    this.editingFolderName = folder.name
  }

  // 确认重命名文件夹
  async confirmRenameFolder() {
    if (this.editingFolderId === null || this.editingFolderName.trim() === '') {
      this.cancelRenameFolder()
      return
    }

    try {
      const newName = this.editingFolderName.trim()
      const editingId = this.editingFolderId
      
      // 检查名称是否重复
      const existingFolder = this.folders.find(f => f.name === newName && f.id !== editingId)
      if (existingFolder) {
        // 将错误信息显示在底部
        this.operationError = '文件夹名称已存在'
        // 3秒后自动清除错误信息
        setTimeout(() => {
          this.operationError = null
        }, 3000)
        return
      }

      // 先退出编辑状态
      this.editingFolderId = null
      this.editingFolderName = ''

      // 立即更新本地状态
      const updatedFolders: RSSFolderWithUnread[] = []
      for (const folder of this.folders) {
        if (folder.id === editingId) {
          // 创建新的文件夹对象，更新名称
          const updatedFolder: RSSFolderWithUnread = {
            id: folder.id,
            name: newName,
            description: folder.description,
            icon: folder.icon,
            color: folder.color,
            sortOrder: folder.sortOrder,
            isActive: folder.isActive,
            createdAt: folder.createdAt,
            updatedAt: folder.updatedAt,
            unreadCount: folder.unreadCount
          }
          updatedFolders.push(updatedFolder)
        } else {
          updatedFolders.push(folder)
        }
      }
      this.folders = updatedFolders
      
      // 触发UI更新，确保重命名立即反映到界面
      this.uiUpdateTrigger++

      // 更新数据库
      await FolderDAO.updateFolder(editingId, { name: newName })
      
    } catch (error) {
      // 将错误信息显示在底部
      this.operationError = `重命名失败: ${error}`
      
      // 3秒后自动清除错误信息
      setTimeout(() => {
        this.operationError = null
      }, 3000)
      
      // 如果数据库更新失败，恢复原始数据
      await this.loadFolders()
    }
  }

  // 取消重命名文件夹
  cancelRenameFolder() {
    this.editingFolderId = null
    this.editingFolderName = ''
  }

  // 删除文件夹
  async deleteFolder(folder: RSSFolderWithUnread) {
    try {
      // 1. 先将文件夹内的所有FEED移动到根目录
      const folderFeeds = this.feeds.filter(feed => feed.folderId === folder.id)
      
      for (const feed of folderFeeds) {
        try {
          await FeedDAO.updateFeed(feed.id, { folderId: null })
        } catch (error) {
          // 继续移动其他FEED
        }
      }
      
      // 2. 删除文件夹
      await FolderDAO.deleteFolder(folder.id)
      
      // 3. 重新加载数据
      await Promise.all([
        this.loadFeeds(),
        this.loadFolders()
      ])
      
      // 触发一次UI刷新，避免未读泡泡消失
      this.uiUpdateTrigger++
      
      // 4. 静默更新未读数量
      await this.updateUnreadCountsSilently()
      
    } catch (error) {
      // 将错误信息显示在底部
      this.operationError = `删除文件夹失败: ${error}`
      
      // 3秒后自动清除错误信息
      setTimeout(() => {
        this.operationError = null
      }, 3000)
    }
  }

  // 移动文件夹到顶部
  async moveFolderToTop(folder: RSSFolderWithUnread) {
    try {
      await FolderDAO.moveFolderToTop(folder.id)
      await this.loadFolders() // 重新加载以更新UI
      this.uiUpdateTrigger++
    } catch (error) {
      this.operationError = `移动失败: ${error}`
      setTimeout(() => { this.operationError = null }, 3000)
    }
  }

  // 移动文件夹到底部
  async moveFolderToBottom(folder: RSSFolderWithUnread) {
    try {
      await FolderDAO.moveFolderToBottom(folder.id)
      await this.loadFolders() // 重新加载以更新UI
      this.uiUpdateTrigger++
    } catch (error) {
      this.operationError = `移动失败: ${error}`
      setTimeout(() => { this.operationError = null }, 3000)
    }
  }

  // 导出OPML
  async exportOpml() {
    this.operationError = null
    this.refreshProgress = '正在导出OPML文件...'

    try {
      const opmlString = await OPMLService.generateOpml()
      const context = getContext(this) as common.UIAbilityContext
      const filePath = await OPMLService.saveOpmlFile(opmlString, context)

      // 复制路径到剪贴板，方便用户粘贴
      try {
        const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, filePath)
        const systemPaste = pasteboard.getSystemPasteboard()
        await systemPaste.setData(pasteData)
      } catch (e) {
        // ignore
      }

      this.refreshProgress = `OPML导出成功！已保存至下载目录:\n${filePath}(已复制路径)`
      setTimeout(() => {
        this.refreshProgress = ''
      }, 5000)
    } catch (error) {
      this.refreshProgress = ''
      // 如果不是用户取消操作，才显示错误信息
      if (error && error.message && !error.message.includes('用户取消')) {
        this.operationError = `导出失败: ${error.message}`
        setTimeout(() => {
          this.operationError = null
        }, 3000)
      }
    }
  }

  // 添加订阅
  addSubscription() {
    this.showAddInput = true
    this.addInputType = 'subscription'
    this.addInputValue = ''
  }

  // 添加文件夹
  addFolder() {
    this.showAddInput = true
    this.addInputType = 'folder'
    this.addInputValue = ''
  }

  // 确认添加操作
  async confirmAdd() {
    if (!this.addInputValue.trim()) {
      this.cancelAdd()
      return
    }

    try {
      // 清除之前的操作错误信息
      this.operationError = null
      
      if (this.addInputType === 'subscription') {
        // 先关闭输入框，让用户看到进度信息
        const url = this.addInputValue.trim()
        this.cancelAdd()
        
        // 开始添加订阅（这会显示进度信息）
        await this.performAddSubscription(url)
      } else if (this.addInputType === 'folder') {
        await this.performAddFolder(this.addInputValue.trim())
        // 文件夹添加成功后关闭输入框
        this.cancelAdd()
      } else if (this.addInputType === 'icon') {
        await this.confirmSetIcon()
      }
      
    } catch (error) {
      // 将错误信息显示在底部，而不是替换整个列表
      this.operationError = `添加失败: ${error}`
      
      // 3秒后自动清除错误信息
      setTimeout(() => {
        this.operationError = null
      }, 3000)
    }
  }

  // 取消添加操作
  cancelAdd() {
    this.showAddInput = false
    this.addInputType = null
    this.addInputValue = ''
    this.settingIconFeedId = null
  }

  // 设置FEED图标
  setFeedIcon(feed: RSSFeedWithUnread) {
    this.showAddInput = true
    this.addInputType = 'icon'
    this.addInputValue = ''
    this.settingIconFeedId = feed.id
  }

  // 确认设置图标
  async confirmSetIcon() {
    if (!this.addInputValue.trim() || this.settingIconFeedId === null) {
      this.cancelAdd()
      return
    }

    try {
      const iconUrl = this.addInputValue.trim()
      const feedId = this.settingIconFeedId
      
      // 先关闭输入框
      this.cancelAdd()
      
      // 显示下载进度
      this.refreshProgress = '正在下载图标...'
      
      // 获取应用上下文
      const context = getContext(this) as common.UIAbilityContext
      
      // 下载图标
      const faviconPath = await FaviconDownloader.downloadAndSaveFavicon(feedId, iconUrl, context)
      
      if (faviconPath) {
        // 保存到数据库
        await FeedDAO.updateFaviconPath(feedId, faviconPath)
        
        // 立即更新本地feeds数组中的faviconPath
        const updatedFeeds = this.feeds.map(feed => {
          if (feed.id === feedId) {
            return {
              id: feed.id,
              folderId: feed.folderId,
              url: feed.url,
              title: feed.title,
              description: feed.description,
              link: feed.link,
              language: feed.language,
              lastBuildDate: feed.lastBuildDate,
              imageUrl: feed.imageUrl,
              category: feed.category,
              isActive: feed.isActive,
              sortOrder: feed.sortOrder,
              createdAt: feed.createdAt,
              updatedAt: feed.updatedAt,
              lastFetchAt: feed.lastFetchAt,
              errorCount: feed.errorCount,
              lastError: feed.lastError,
              unreadCount: feed.unreadCount,
              favicon: feed.favicon,
              faviconPath: faviconPath
            }
          }
          return feed
        })
        this.feeds = updatedFeeds
        
        // 强制触发UI更新
        this.uiUpdateTrigger++
        
        this.refreshProgress = '图标设置成功！'
        
        // 2秒后清除成功信息
        setTimeout(() => {
          this.refreshProgress = ''
        }, 2000)
      } else {
        throw new Error('图标下载失败')
      }
      
    } catch (error) {
      this.refreshProgress = ''
      this.operationError = `设置图标失败: ${error}`
      
      // 3秒后自动清除错误信息
      setTimeout(() => {
        this.operationError = null
      }, 3000)
    }
  }

  // 执行添加订阅
  async performAddSubscription(url: string) {
    // 验证URL格式
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      throw new Error('请输入有效的URL（需要以http://或https://开头）')
    }

    // 通过DAO添加新订阅源，DAO层会处理URL重复检查
    const newFeedId = await FeedDAO.addFeed({
      url: url,
      title: url, // 临时标题，后续刷新更新
      description: '',
      link: '',
      language: '',
      lastBuildDate: '',
      imageUrl: '',
      category: '',
      isActive: true,
      sortOrder: 0
    })

    // 显示刷新进度
    this.refreshProgress = `正在获取RSS源内容: ${url}`
    
    try {
      // 触发针对新FEED的刷新，获取真实的标题和文章内容
      await RSSRefreshService.refreshSingleFeed(newFeedId)
      
      this.refreshProgress = `RSS源添加完成: ${url}`
      
      // 短暂显示完成信息
      setTimeout(() => {
        this.refreshProgress = ''
      }, 2000)
      
    } catch (refreshError) {
      // 即使内容获取失败，RSS源也已经添加成功了
      this.refreshProgress = `RSS源已添加，但内容获取失败: ${refreshError}`
      
      // 短暂显示错误信息
      setTimeout(() => {
        this.refreshProgress = ''
      }, 3000)
    }
    
    // 重新加载数据以更新UI显示
    await Promise.all([
      this.loadFeeds(),
      this.loadUnreadCounts()
    ])
    
    // 静默更新未读数量，确保UI正确显示
    await this.updateUnreadCountsSilently()
  }

  // 执行添加文件夹
  async performAddFolder(name: string) {
    try {
      // DAO 内部会检查重名并抛出错误
      await FolderDAO.createFolder({ name })

      // 重新加载文件夹数据
      await this.loadFolders()

      // 触发 UI 更新
      this.uiUpdateTrigger++
    } catch (error) {
      // ArkTS limited-throw 仅允许 Error 类型
      if (error instanceof Error) {
        throw error
      } else {
        throw new Error(String(error))
      }
    }
  }

  // 删除FEED及其相关数据
  async deleteFeed(feed: RSSFeedWithUnread) {
    try {
      await FeedDataService.deleteFeed(feed.id)

      // 重新加载数据
      await Promise.all([
        this.loadFeeds(),
        this.loadUnreadCounts()
      ])

      this.updateSpecialFeedsUnreadCountsSilently()
    } catch (error) {
      this.operationError = `删除失败: ${error}`
      setTimeout(() => {
        this.operationError = null
      }, 3000)
    }
  }

    // 刷新未读数量（优化版本：只更新数量，不重新加载列表）
  async refreshUnreadCounts() {
    try {
      // 静默更新数据，不触发大范围UI重新渲染
      await this.updateUnreadCountsSilently()
      
    } catch (error) {
      // 将错误信息显示在底部而不是替换整个列表
      this.operationError = `刷新失败: ${error}`
      
      // 3秒后自动清除错误信息
      setTimeout(() => {
        this.operationError = null
      }, 3000)
    }
  }

  // 静默更新未读数量（不触发大范围UI重新渲染）
  private async updateUnreadCountsSilently() {
    try {
      // 1. 静默更新特殊标签的未读数量
      await this.loadUnreadCounts()
      
      // 2. 静默更新feeds的未读数量
      if (this.feeds.length > 0) {
        await this.updateFeedsUnreadCountsSilently()
      }
      
      // 3. 静默更新文件夹未读数量
      if (this.folders.length > 0) {
        this.updateFoldersUnreadCountsSilently()
      }
      
      // 4. 静默更新特殊标签显示
      this.updateSpecialFeedsUnreadCountsSilently()
      
    } catch (error) {
      // ArkTS limited-throw 仅允许 Error 类型
      if (error instanceof Error) {
        throw error
      } else {
        throw new Error(String(error))
      }
    }
  }

  // 静默更新feeds未读数量（不重新创建数组）
  private async updateFeedsUnreadCountsSilently(): Promise<void> {
    try {
      const feedIds = this.feeds.map(feed => feed.id)
      if (feedIds.length === 0) return
      const unreadCounts = await FeedDataService.getFeedsUnreadCounts(feedIds)

      // 强制创建新的feeds数组来触发响应式更新
      const updatedFeeds: RSSFeedWithUnread[] = []
      
      for (const feed of this.feeds) {
        const newCount = unreadCounts.get(feed.id) || 0
        
        // 总是创建新对象，确保UI能检测到变化
        const updatedFeed: RSSFeedWithUnread = {
          id: feed.id,
          folderId: feed.folderId,
          url: feed.url,
          title: feed.title,
          description: feed.description,
          link: feed.link,
          language: feed.language,
          lastBuildDate: feed.lastBuildDate,
          imageUrl: feed.imageUrl,
          category: feed.category,
          isActive: feed.isActive,
          sortOrder: feed.sortOrder,
          createdAt: feed.createdAt,
          updatedAt: feed.updatedAt,
          lastFetchAt: feed.lastFetchAt,
          errorCount: feed.errorCount,
          lastError: feed.lastError,
          unreadCount: newCount,
          favicon: $r("app.media.rss"),
          faviconPath: feed.faviconPath
        }
        updatedFeeds.push(updatedFeed)
      }
      
      // 总是更新数组，确保UI刷新
      this.feeds = updatedFeeds

    } catch (error) {
      // 静默失败
    }
  }

  // 静默更新特殊标签未读数量显示
  private updateSpecialFeedsUnreadCountsSilently(): void {
    // 如果特殊标签数组为空，先初始化
    if (this.specialFeeds.length === 0) {
      this.initializeSpecialFeeds()
    }
    
    // 强制创建全新的数组和对象来确保UI更新
    const updatedSpecialFeeds: RSSFeed[] = []
    
    for (const feed of this.specialFeeds) {
      let newUnreadCount = 0
      
      if (feed.id === "today") {
        newUnreadCount = this.todayUnreadCount
      } else if (feed.id === "favorites") {
        newUnreadCount = this.favoriteUnreadCount
      } else if (feed.id === "unread") {
        newUnreadCount = this.totalUnreadCount
      }
      
      // 总是创建新对象，确保UI能检测到变化
      const updatedFeed: RSSFeed = {
        id: feed.id,
        folderId: feed.folderId,
        title: feed.title,
        description: feed.description,
        url: feed.url,
        favicon: feed.favicon,  // 保留原有的图标，不要重置为RSS图标
        unreadCount: newUnreadCount
      }
      updatedSpecialFeeds.push(updatedFeed)
    }
    
    // 直接更新数组，不使用异步方式
    this.specialFeeds = updatedSpecialFeeds
    
    // 强制触发UI更新
    this.uiUpdateTrigger++
  }

  // 静默更新文件夹未读数量
  private updateFoldersUnreadCountsSilently(): void {
    // 强制创建新的文件夹数组
    const updatedFolders: RSSFolderWithUnread[] = []
    
    for (const folder of this.folders) {
      // 计算文件夹中所有RSS源的未读数量总和
      const folderFeeds = this.feeds.filter(feed => feed.folderId === folder.id)
      const totalUnread = folderFeeds.reduce((sum, feed) => sum + feed.unreadCount, 0)
      
      // 总是创建新对象，确保UI能检测到变化
      const updatedFolder: RSSFolderWithUnread = {
        id: folder.id,
        name: folder.name,
        description: folder.description,
        icon: folder.icon,
        color: folder.color,
        sortOrder: folder.sortOrder,
        isActive: folder.isActive,
        createdAt: folder.createdAt,
        updatedAt: folder.updatedAt,
        unreadCount: totalUnread
      }
      updatedFolders.push(updatedFolder)
    }
    
    // 总是更新数组，确保UI刷新
    this.folders = updatedFolders
    
    // 触发UI更新
    this.uiUpdateTrigger++
  }

  // 完整刷新（用于手动刷新按钮）
  async fullRefresh() {
    try {
      this.isRefreshing = true
      // 不设置全局加载状态，只显示进度信息
      this.refreshProgress = '准备刷新...'
      
      // 先加载feeds列表，获取需要刷新的FEED数量
      this.refreshProgress = '加载FEED列表...'
      await this.loadFeeds()
      await this.loadFolders()
      
      const activeFeeds = this.feeds.filter(feed => feed.isActive)
      this.totalFeedsToRefresh = activeFeeds.length
      this.currentRefreshIndex = 0
      
      if (this.totalFeedsToRefresh === 0) {
        this.refreshProgress = '没有需要刷新的FEED'
        await this.loadUnreadCounts()
        return
      }
      
      this.refreshProgress = `准备刷新 ${this.totalFeedsToRefresh} 个FEED...`
      
      // 逐个刷新FEED内容
      for (let i = 0; i < activeFeeds.length; i++) {
        const feed = activeFeeds[i]
        this.currentRefreshIndex = i + 1
        this.currentRefreshingFeed = feed.title
        this.refreshProgress = `正在刷新 (${this.currentRefreshIndex}/${this.totalFeedsToRefresh}): ${feed.title}`
        
        try {
          // 调用RSS刷新服务来更新FEED内容
          await RSSRefreshService.refreshSingleFeed(feed.id)
        } catch (feedError) {
          // 继续刷新其他FEED
        }
      }
      
      // 刷新完成，更新未读数量
      this.refreshProgress = '更新未读数量...'
      await this.loadUnreadCounts()
      
      this.refreshProgress = `刷新完成！共处理 ${this.totalFeedsToRefresh} 个FEED`
      
      // 短暂显示完成信息后清空
      setTimeout(() => {
        this.refreshProgress = ''
        this.currentRefreshingFeed = ''
        this.totalFeedsToRefresh = 0
        this.currentRefreshIndex = 0
        this.isRefreshing = false
      }, 2000)
      
      // 通知父组件数据已更新
      if (this.onRef) {
        this.onRef(this)
      }
    } catch (error) {
      // 将刷新失败的错误信息显示在底部
      this.operationError = `刷新失败: ${error}`
      this.refreshProgress = ''
      this.isRefreshing = false
      
      // 3秒后自动清除错误信息
      setTimeout(() => {
        this.operationError = null
      }, 3000)
    } finally {
      // 不需要重置isLoading，因为我们没有设置它
    }
  }

  // 转换数据库Feed到前端模型
  private dbFeedToRSSFeed(dbFeed: RSSFeedWithUnread): RSSFeed {
    return {
      id: dbFeed.id.toString(),
      folderId: dbFeed.folderId?.toString() || null,
      title: dbFeed.title,
      description: dbFeed.description,
      url: dbFeed.url,
      favicon: $r("app.media.rss"),
      unreadCount: dbFeed.unreadCount
    }
  }

  // 获取Feed图标资源
  @Builder
  getFeedIcon(feed: RSSFeedWithUnread) {
    if (feed.faviconPath && feed.faviconPath.trim() !== '') {
      // 使用自定义图标
      Image('file://' + feed.faviconPath)
        .width(20)
        .height(20)
        .margin({ right: 12 })
        .borderRadius(4)
        .alt($r("app.media.rss")) // 使用alt属性作为备用图标
    } else {
      // 使用默认RSS图标
      Image($r("app.media.rss"))
        .width(20)
        .height(20)
        .margin({ right: 12 })
        .borderRadius(4)
    }
  }

  // 未读数量泡泡组件
  @Builder
  UnreadBadge(count: number) {
    // 使用uiUpdateTrigger来强制响应式更新，确保每次触发器变化时都重新渲染
    if (count > 0) {
      Text(`${count}${this.uiUpdateTrigger >= 0 ? '' : ''}`)
        .fontSize(12)
        .fontColor('#fff')
        .backgroundColor('#007AFF')
        .borderRadius(10)
        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
    }
  }

  // 创建FEED右键菜单
  @Builder
  createFeedContextMenu(feed: RSSFeedWithUnread) {
    Menu() {
      // 刷新FEED
      MenuItem({ 
        content: "刷新"
      })
        .onClick(() => {
          this.refreshSingleFeed(feed)
        })

      // 复制FEED地址
      MenuItem({ 
        content: "复制FEED地址"
      })
        .onClick(() => {
          this.copyFeedUrl(feed)
        })

      // 移动到根目录选项（仅当FEED在文件夹中时显示）
      if (feed.folderId !== null) {
        MenuItem({
          content: "移动到根目录"
        })
          .onClick(() => {
            this.moveFeedToFolder(feed, null)
          })
      }

      // 移动到文件夹选项
      if (this.folders.length > 0) {
        ForEach(this.folders, (folder: RSSFolderDB) => {
          if (feed.folderId !== folder.id) {
            MenuItem({
              content: `移动到 ${folder.name}`
            })
              .onClick(() => {
                this.moveFeedToFolder(feed, folder.id)
              })
          }
        }, (folder: RSSFolderDB) => `move_${folder.id}`)
      }

      // 设置图标选项
      MenuItem({
        content: "设置图标"
      })
        .onClick(() => {
          this.setFeedIcon(feed)
        })

      // 分隔线（可选，如果支持的话）
      // MenuDivider()

      // 删除FEED选项
      MenuItem({
        content: "删除订阅"
      })
        .onClick(() => {
          this.deleteFeed(feed)
        })
    }
  }

  // 创建文件夹右键菜单
  @Builder
  createFolderContextMenu(folder: RSSFolderWithUnread) {
    Menu() {
      // 重命名文件夹
      MenuItem({
        content: "重命名"
      })
        .onClick(() => {
          this.startEditingFolder(folder)
        })

      // 删除文件夹
      MenuItem({
        content: "删除文件夹"
      })
        .onClick(() => {
          this.deleteFolder(folder)
        })

      // 移到最上面
      MenuItem({
        content: "移到最上面"
      })
        .onClick(() => {
          this.moveFolderToTop(folder)
        })

      // 移到最下面
      MenuItem({
        content: "移到最下面"
      })
        .onClick(() => {
          this.moveFolderToBottom(folder)
        })
    }
  }

  // 创建添加菜单
  @Builder
  createAddMenu() {
    Menu() {
      // 添加订阅
      MenuItem({
        content: "添加订阅"
      })
        .onClick(() => {
          this.addSubscription()
        })

      // 添加文件夹
      MenuItem({
        content: "添加文件夹"
      })
        .onClick(() => {
          this.addFolder()
        })
    }
  }

  // 创建通用右键菜单（用于空白区域）
  @Builder
  createGeneralContextMenu() {
    Menu() {
      // 添加订阅
      MenuItem({
        content: "添加订阅"
      })
        .onClick(() => {
          this.addSubscription()
        })

      // 添加文件夹
      MenuItem({
        content: "添加文件夹"
      })
        .onClick(() => {
          this.addFolder()
        })

      // 刷新所有
      MenuItem({
        content: "刷新所有"
      })
        .onClick(() => {
          this.fullRefresh()
        })

      // 导入OPML
      MenuItem({
        content: "导入OPML"
      })
        .onClick(() => {
          this.refreshProgress = '正在导入OPML...'
          const context = getContext(this) as common.UIAbilityContext
          OPMLService.importOpml(context).then(async () => {
            this.refreshProgress = '导入完成，正在刷新列表...'
            await Promise.all([this.loadFeeds(), this.loadFolders()])
            await this.updateUnreadCountsSilently()
            this.refreshProgress = 'OPML导入成功！'
            setTimeout(()=>{this.refreshProgress='' },3000)
          }).catch((err: Error) => {
            this.refreshProgress = ''
            this.operationError = `导入失败: ${err.message}`
            setTimeout(()=>{this.operationError=null},3000)
          })
        })

      // 导出OPML
      MenuItem({
        content: "导出OPML"
      })
        .onClick(() => {
          this.exportOpml()
        })

      // 切换自动刷新
      MenuItem({
        content: this.autoRefreshEnabled ? '已打开自动刷新' : '已关闭自动刷新'
      })
        .onClick(() => {
          this.toggleAutoRefresh()
        })

      // 切换图片缓存
      MenuItem({
        content: this.imageCacheEnabled ? '已打开缓存图片' : '已关闭缓存图片'
      })
        .onClick(() => {
          this.toggleImageCache()
        })
    }
  }

  // 切换自动刷新开关
  private async toggleAutoRefresh() {
    this.autoRefreshEnabled = !this.autoRefreshEnabled
    await PreferencesUtil.saveAutoRefreshEnabled(this.autoRefreshEnabled)

    if (this.autoRefreshEnabled) {
      RSSRefreshService.startAutoRefresh()
    } else {
      RSSRefreshService.stopAutoRefresh()
    }
  }

  // 切换图片缓存开关
  private async toggleImageCache() {
    this.imageCacheEnabled = !this.imageCacheEnabled
    await PreferencesUtil.saveImageCacheEnabled(this.imageCacheEnabled)
    console.info('RSSFeedList', `图片缓存已${this.imageCacheEnabled ? '开启' : '关闭'}`)
  }

  build() {
    Column() {
      // 顶部工具栏
      Row() {
        Text('订阅源')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#000')
          .layoutWeight(1)

        // 刷新按钮
        Image(this.isRefreshing ? $r("app.media.loading") : $r("app.media.refresh"))
          .width(20)
          .height(20)
          .fillColor('#666666')
          .margin({ right: 8 })
          .enabled(!this.isRefreshing)
          .opacity(this.isRefreshing ? 0.5 : 1.0)
          .onClick(() => {
            if (!this.isRefreshing) {
              this.fullRefresh()
            }
          })

        // 添加按钮（支持菜单选择）
        Image($r("app.media.new"))
          .width(20)
          .height(20)
          .fillColor('#666666')

          .bindContextMenu(this.createAddMenu(), ResponseType.RightClick)
          .onClick(() => {
            // 左键点击默认添加订阅，右键显示菜单
            this.addSubscription()
          })
      }
      .width('100%')
      .height(50)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#f7f7f7')
      .border({ width: { bottom: 1 }, color: '#e0e0e0' })

      // 内容区域
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .margin({ top: 40 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.error && this.error.includes('数据库')) {
        // 只有数据库相关错误才在内容区域显示
        Column() {
          Text(this.error)
            .fontSize(16)
            .fontColor(Color.Red)
            .margin({ top: 40 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          // 特殊标签组
          ForEach(this.specialFeeds, (feed: RSSFeed) => {
            ListItem() {
              Row() {
                Image(feed.favicon || $r("app.media.rss"))
                  .width(20)  // 图标尺寸比其他图标小2像素
                  .height(20)
                  .margin({ right: 12 })
                  .fillColor('#666666')

                Text(feed.title)
                  .fontSize(16)  // 与文章标题一样大
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#000')
                  .textAlign(TextAlign.Start)
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                // 直接使用状态变量而不是数组中的值，确保UI能正确响应变化
                if (feed.id === "today") {
                  this.UnreadBadge(this.todayUnreadCount)
                } else if (feed.id === "favorites") {
                  this.UnreadBadge(this.favoriteUnreadCount)
                } else if (feed.id === "unread") {
                  this.UnreadBadge(this.totalUnreadCount)
                } else {
                  this.UnreadBadge(feed.unreadCount)
                }
              }
              .width('100%')
              .height(40)  // 一行的高度（缩小间距）
              .padding({ left: 16, right: 16 })
              .backgroundColor(this.selectedFeedId === feed.id ? '#f0f7ff' : '#fff')
              .alignItems(VerticalAlign.Center)
            }
            .onClick(() => {
              this.selectedFeedId = feed.id
              if (this.onFeedClick) {
                this.onFeedClick(feed)
              }
            })
          }, (feed: RSSFeed) => `${feed.id}_${this.uiUpdateTrigger}`)

          // 分隔线（缩小间隙）
          ListItem() {
            Divider()
              .strokeWidth(4)
              .color('#f5f5f5')
          }

          // 添加输入框（条件显示）
          if (this.showAddInput) {
            ListItem() {
              Row() {
                TextInput({ 
                  text: this.addInputValue,
                  placeholder: this.addInputType === 'subscription' ? '请输入RSS源URL' : 
                              this.addInputType === 'folder' ? '请输入文件夹名称' :
                              this.addInputType === 'icon' ? '请输入图标URL' : ''
                })
                  .defaultFocus(true)
                  .fontSize(16)
                  .fontColor('#000')
                  .backgroundColor('#ffffff')
                  .border({ width: 1, color: '#007AFF' })
                  .borderRadius(6)
                  .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                  .height(32)
                  .layoutWeight(1)
                  .caretColor('#007AFF')
                  .placeholderColor('#999')
                  .placeholderFont({ size: 16, weight: FontWeight.Normal })
                  .onChange((value: string) => {
                    this.addInputValue = value
                  })
                  .onSubmit(() => {
                    this.confirmAdd()
                  })
                  .onBlur(() => {
                    // 失焦时不自动确认，让用户有机会重新聚焦
                  })

                // 确认按钮
                Button() {
                  Text('✓')
                    .fontSize(12)
                    .fontColor('#007AFF')
                }
                .type(ButtonType.Circle)
                .backgroundColor('#f0f7ff')
                .width(20)
                .height(20)
                .margin({ left: 6 })
                .onClick(() => {
                  this.confirmAdd()
                })

                // 取消按钮
                Button() {
                  Text('✕')
                    .fontSize(12)
                    .fontColor('#666')
                }
                .type(ButtonType.Circle)
                .backgroundColor('#f0f0f0')
                .width(20)
                .height(20)
                .margin({ left: 6 })
                .onClick(() => {
                  this.cancelAdd()
                })
              }
              .width('100%')
              .height(44)
              .padding({ left: 16, right: 16 })
              .backgroundColor('#f9f9f9')
              .alignItems(VerticalAlign.Center)
            }
          }

          // 文件夹组
          ForEach(this.folders, (folder: RSSFolderWithUnread) => {
            ListItem() {
              Row() {
                // 展开/收起箭头
                Image(this.expandedFolders.has(folder.id) ? $r("app.media.folder_open") : $r("app.media.folder_close"))
                  .width(20)
                  .height(20)
                  .margin({ right: 12 })
                  .fillColor('#666666')

                // 根据是否在编辑状态显示不同的组件
                if (this.editingFolderId === folder.id) {
                  // 编辑状态：显示TextInput和按钮
                  TextInput({ text: this.editingFolderName })
                    .defaultFocus(true)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#000')
                    .backgroundColor('#ffffff')
                    .border({ width: 1, color: '#007AFF' })
                    .borderRadius(6)
                    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                    .height(32)
                    .layoutWeight(1)
                    .caretColor('#007AFF')
                    .placeholderColor('#999')
                    .placeholderFont({ size: 16, weight: FontWeight.Normal })
                    .onChange((value: string) => {
                      this.editingFolderName = value
                    })
                    .onSubmit(() => {
                      this.confirmRenameFolder()
                    })
                    .onBlur(() => {
                      // 失焦时不自动确认，让用户有机会重新聚焦
                    })
                    .onFocus(() => {
                      // 输入框获得焦点
                    })

                  // 确认按钮
                  Button() {
                    Text('✓')
                      .fontSize(12)
                      .fontColor('#007AFF')
                  }
                  .type(ButtonType.Circle)
                  .backgroundColor('#f0f7ff')
                  .width(20)
                  .height(20)
                  .margin({ left: 6 })
                  .onClick(() => {
                    this.confirmRenameFolder()
                  })

                  // 取消按钮
                  Button() {
                    Text('✕')
                      .fontSize(12)
                      .fontColor('#666')
                  }
                  .type(ButtonType.Circle)
                  .backgroundColor('#f0f0f0')
                  .width(20)
                  .height(20)
                  .margin({ left: 6 })
                  .onClick(() => {
                    this.cancelRenameFolder()
                  })
                } else {
                  // 正常状态：显示文件夹名称
                  Text(folder.name)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#000')
                    .textAlign(TextAlign.Start)
                    .layoutWeight(1)
                  
                  // 显示文件夹的未读数量
                  this.UnreadBadge(folder.unreadCount)
                }
              }
              .width('100%')
              .height(40)
              .padding({ left: 16, right: 16 })
              .backgroundColor('#fff')
              .alignItems(VerticalAlign.Center)
            }
            .onClick(() => {
              // 如果不在编辑状态，才允许展开/收起
              if (this.editingFolderId !== folder.id) {
                this.toggleFolderExpanded(folder.id)
              }
            })
            .bindContextMenu(this.createFolderContextMenu(folder), ResponseType.RightClick)

            // 文件夹中的RSS源（仅在展开时显示）
            if (this.expandedFolders.has(folder.id)) {
              // 显示文件夹中的RSS源
              ForEach(this.feeds.filter(feed => feed.folderId === folder.id), (feed: RSSFeedWithUnread) => {
                ListItem() {
                  Row() {
                    // 缩进显示
                    Blank()
                      .width(20)

                    this.getFeedIcon(feed)

                    Text(feed.title)
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#000')
                      .textAlign(TextAlign.Start)
                      .layoutWeight(1)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })

                    // 显示RSS源的未读数量
                    this.UnreadBadge(feed.unreadCount)
                  }
                  .width('100%')
                  .height(40)
                  .padding({ left: 16, right: 16 })
                  .backgroundColor(this.selectedFeedId === feed.id.toString() ? '#f0f7ff' : '#fff')
                  .alignItems(VerticalAlign.Center)
                }
                .onClick(() => {
                  this.selectedFeedId = feed.id.toString()
                  if (this.onFeedClick) {
                    this.onFeedClick(this.dbFeedToRSSFeed(feed))
                  }
                })
                .bindContextMenu(this.createFeedContextMenu(feed), ResponseType.RightClick)
              }, (feed: RSSFeedWithUnread) => `${folder.id}_${feed.id}_${this.uiUpdateTrigger}`)

              // 如果文件夹为空，显示空文件夹提示
              if (this.feeds.filter(feed => feed.folderId === folder.id).length === 0) {
                ListItem() {
                  Row() {
                    // 缩进显示
                    Blank()
                      .width(20)

                    Text('空文件夹')
                      .fontSize(14)
                      .fontColor('#999')
                      .fontStyle(FontStyle.Italic)
                      .textAlign(TextAlign.Start)
                      .layoutWeight(1)
                  }
                  .width('100%')
                  .height(40)
                  .padding({ left: 16, right: 16 })
                  .backgroundColor('#fff')
                  .alignItems(VerticalAlign.Center)
                }
              }
            }
          }, (folder: RSSFolderDB) => `folder_${folder.id}_${this.uiUpdateTrigger}`)

          // RSS源组（只显示不在文件夹中的RSS源）
          ForEach(this.feeds.filter(feed => feed.folderId === null), (feed: RSSFeedWithUnread) => {
            ListItem() {
              Row() {
                this.getFeedIcon(feed)

                Text(feed.title)
                  .fontSize(16)  // 与文章标题一样大
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#000')
                  .textAlign(TextAlign.Start)
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                // 显示RSS源的未读数量
                this.UnreadBadge(feed.unreadCount)
              }
              .width('100%')
              .height(40)  // 一行的高度（缩小间距）
              .padding({ left: 16, right: 16 })
              .backgroundColor(this.selectedFeedId === feed.id.toString() ? '#f0f7ff' : '#fff')
              .alignItems(VerticalAlign.Center)
            }
            .onClick(() => {
              this.selectedFeedId = feed.id.toString()
              if (this.onFeedClick) {
                this.onFeedClick(this.dbFeedToRSSFeed(feed))
              }
            })
            .bindContextMenu(this.createFeedContextMenu(feed), ResponseType.RightClick)
          }, (feed: RSSFeedWithUnread) => `${feed.id.toString()}_${this.uiUpdateTrigger}`)

          // 如果没有RSS源，显示提示信息
          if (this.feeds.length === 0 && this.folders.length === 0) {
            ListItem() {
              Column() {
                Image($r("app.media.rss"))
                  .width(60)
                  .height(60)
                  .opacity(0.3)
                  .margin({ bottom: 12 })
                
                Text('暂无RSS源')
                  .fontSize(16)
                  .fontColor('#999')
                  
                Text('点击上方 + 按钮添加订阅')
                  .fontSize(12)
                  .fontColor('#bbb')
                  .margin({ top: 4 })
              }
              .width('100%')
              .padding({ top: 40, bottom: 40 })
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
            }
          }
        }
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('#fff')
        // 移除列表项之间的分割线
        // .divider({ strokeWidth: 0.5, color: '#f0f0f0', startMargin: 52, endMargin: 0 })
        .bindContextMenu(this.createGeneralContextMenu(), ResponseType.RightClick)
      }

              // 底部信息显示区域（刷新进度和操作错误）
        if (this.refreshProgress !== '' || this.operationError !== null) {
          Row() {
            // 刷新进度信息
            if (this.refreshProgress !== '') {
              Row() {
                // 只要有进度信息就显示加载图标（除非是完成或失败状态）
                if (!this.refreshProgress.includes('刷新完成') && !this.refreshProgress.includes('刷新失败')) {
                  LoadingProgress()
                    .width(16)
                    .height(16)
                    .color('#007AFF')
                    .margin({ right: 8 })
                }
                
                Text(this.refreshProgress)
                  .fontSize(12)
                  .fontColor('#666')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .layoutWeight(1)
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 8, bottom: 8 })
              .alignItems(VerticalAlign.Center)
            }
            
            // 操作错误信息
            if (this.operationError !== null) {
              Row() {
                Image($r("app.media.icon"))
                  .width(16)
                  .height(16)
                  .fillColor('#ff4444')
                  .margin({ right: 8 })
                
                Text(this.operationError)
                  .fontSize(12)
                  .fontColor('#ff4444')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .layoutWeight(1)
                
                // 关闭按钮
                Button() {
                  Text('✕')
                    .fontSize(10)
                    .fontColor('#ff4444')
                }
                .type(ButtonType.Circle)
                .backgroundColor('transparent')
                .width(20)
                .height(20)
                .onClick(() => {
                  this.operationError = null
                })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 8, bottom: 8 })
              .alignItems(VerticalAlign.Center)
              .backgroundColor('#fff5f5')
            }
          }
          .width('100%')
          .backgroundColor('#f7f7f7')
          .border({ width: { top: 1 }, color: '#e0e0e0' })
        }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f8f9fa')
  }
} 