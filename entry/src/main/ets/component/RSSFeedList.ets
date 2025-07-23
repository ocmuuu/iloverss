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
import { ImageCacheService } from '../service/ImageCacheService'
import { ArticleDAO } from '../model/ArticleDAO'
import { ParsedFeed } from '../utils/feed/ParsedFeed'
import { common } from '@kit.AbilityKit'
import { FeedDataService, type RSSFeedWithUnread } from '../service/FeedDataService'
import type { RSSFolderWithUnread } from '../model/FolderDAO'
import { OPMLService } from '../service/OPMLService'
import PreferencesUtil from '../utils/PreferencesUtil'
import { GlobalState } from '../model/GlobalState'
import { ImageDAO } from '../model/ImageDAO'
import { UrlHashUtil } from '../utils/UrlHashUtil'
import fs from '@ohos.file.fs'

@Component
export struct RSSFeedList {
  @State feeds: RSSFeedWithUnread[] = []
  @State folders: RSSFolderWithUnread[] = []
  @State expandedFolders: Set<number> = new Set()
  @State isLoading: boolean = false
  @State error: string | null = null
  @State operationError: string | null = null
  @State specialFeeds: RSSFeed[] = []
  @State todayUnreadCount: number = 0
  @State favoriteUnreadCount: number = 0
  @State totalUnreadCount: number = 0
  @State selectedFeedId: string | null = null
  @State uiUpdateTrigger: number = 0

  @State refreshProgress: string = ''
  @State totalFeedsToRefresh: number = 0
  @State currentRefreshIndex: number = 0
  @State currentRefreshingFeed: string = ''
  
  @State editingFolderId: number | null = null
  @State editingFolderName: string = ''
  
  @State showAddInput: boolean = false
  @State addInputType: 'subscription' | 'folder' | 'icon' | null = null
  @State addInputValue: string = ''
  
  @State settingIconFeedId: number | null = null
  
  @State autoRefreshEnabled: boolean = true
  @State imageCacheEnabled: boolean = false
  
  onRef?: (ref: RSSFeedList) => void

  @StorageLink('selectedFeedId') globalSelectedFeedId: string = ''
  @StorageLink('refreshTrigger') @Watch('onGlobalRefreshTriggered') globalRefreshTrigger: number = 0
  @StorageLink('articleReadStatusJson') @Watch('onArticleStatusChanged') articleReadStatusJson: string = '{}'
  @StorageLink('articleStarStatusJson') @Watch('onArticleStatusChanged') articleStarStatusJson: string = '{}'

  private refreshCompleteHandler: () => void = async () => {
    await this.refreshUnreadCounts()
  }

  @State isRefreshing: boolean = false

  async aboutToAppear() {
    RSSRefreshService.registerRefreshCompleteCallback(this.refreshCompleteHandler)

    this.initializeSpecialFeeds()
    
    try {
      this.autoRefreshEnabled = await PreferencesUtil.getAutoRefreshEnabled()
    } catch(_) {
      this.autoRefreshEnabled = true
    }

    try {
      this.imageCacheEnabled = await PreferencesUtil.getImageCacheEnabled()
    } catch(_) {
      this.imageCacheEnabled = false
    }
    
    let retryCount = 0
    const maxRetries = 30
    let dbReady = false
    
    while (retryCount < maxRetries) {
      if (DatabaseManager.isInitializedSync()) {
        const store = DatabaseManager.getStore()
        if (store) {
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
    
    this.isLoading = true
    
    try {
      await Promise.all([
        this.loadFeeds(),
        this.loadFolders(),
        this.loadUnreadCounts()
      ])
      
      if (this.onRef) {
        this.onRef(this)
      }

      await this.updateUnreadCountsSilently()

    } catch (error) {
      this.error = '数据加载失败'
    } finally {
      this.isLoading = false
    }
  }

  aboutToDisappear() {
    RSSRefreshService.unregisterRefreshCompleteCallback(this.refreshCompleteHandler)
  }

  onGlobalRefreshTriggered() {
    setTimeout(() => {
      this.refreshUnreadCounts()
    }, 100)
  }

  onArticleStatusChanged() {
    setTimeout(() => {
      this.refreshUnreadCounts()
    }, 200)
  }

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

  private async loadUnreadCounts() {
    try {
      const counts = await FeedDataService.loadUnreadCounts()
      this.todayUnreadCount = counts.today
      this.favoriteUnreadCount = counts.favorites
      this.totalUnreadCount = counts.total

      this.updateSpecialFeedsUnreadCountsSilently()
    } catch (error) {
      this.todayUnreadCount = 0
      this.favoriteUnreadCount = 0
      this.totalUnreadCount = 0

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
      this.folders = []
    }
  }

  /**
   * 为指定订阅源缓存其文章中的图片
   */
  private async cacheImagesForFeed(feed: RSSFeedWithUnread) {
    try {
      const context = getContext(this) as common.UIAbilityContext
      if (!context) {
        return
      }

      this.refreshProgress = `正在缓存图片 (0/0)`

      // 获取文章列表（只获取 ID，后面再查询全文）
      const articles = await RSSDataService.getArticlesByFeedId(String(feed.id))
      const total = articles.length
      let finished = 0

      for (const article of articles) {
        try {
          // 直接读取 images 表
          const pendingImages = (await ImageDAO.getImagesByArticleID(article.id))
            .filter(img => !img.localPath)

          for (const img of pendingImages) {
            try {
              await ImageCacheService.ensureImageCached(img.url, article.id, context, true)
            } catch (_) {}
          }
        } catch (_) {}

        finished++
        this.refreshProgress = `正在缓存图片 (${finished}/${total})`
      }

      this.refreshProgress = `图片缓存完成 (${total})`
      setTimeout(()=>{this.refreshProgress='' }, 3000)
    } catch (error) {
      this.refreshProgress = `缓存图片失败: ${error instanceof Error ? error.message : String(error)}`
      setTimeout(()=>{this.refreshProgress='' }, 5000)
    }
  }

  /**
   * 选择下一条订阅源（供键盘快捷键使用）
   */
  selectNextFeed() {
    const allFeeds = [...this.specialFeeds, ...this.feeds]
    if (allFeeds.length === 0) {
      return
    }

    const currentIndex = allFeeds.findIndex(feed => String(feed.id) === String(this.selectedFeedId))
    const nextIndex = (currentIndex + 1) % allFeeds.length
    const nextFeed = allFeeds[nextIndex]
    if (nextFeed) {
      const nextId = String(nextFeed.id)
      this.setSelectedFeed(nextId)
      AppStorage.set('selectedFeedId', nextId)
    }
  }

  /**
   * 选择上一条订阅源（供键盘快捷键使用）
   */
  selectPreviousFeed() {
    const allFeeds = [...this.specialFeeds, ...this.feeds]
    if (allFeeds.length === 0) {
      return
    }

    const currentIndex = allFeeds.findIndex(feed => String(feed.id) === String(this.selectedFeedId))
    const prevIndex = (currentIndex - 1 + allFeeds.length) % allFeeds.length
    const prevFeed = allFeeds[prevIndex]
    if (prevFeed) {
      const prevId = String(prevFeed.id)
      this.setSelectedFeed(prevId)
      AppStorage.set('selectedFeedId', prevId)
    }
  }

  setSelectedFeed(feedId: string | null) {
    this.selectedFeedId = feedId
  }

  toggleFolderExpanded(folderId: number) {
    const newExpandedFolders = new Set(this.expandedFolders)
    if (newExpandedFolders.has(folderId)) {
      newExpandedFolders.delete(folderId)
    } else {
      newExpandedFolders.add(folderId)
    }
    this.expandedFolders = newExpandedFolders
  }

  async copyFeedUrl(feed: RSSFeedWithUnread) {
    try {
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, feed.url)
      const systemPasteboard = pasteboard.getSystemPasteboard()
      await systemPasteboard.setData(pasteData)
    } catch (error) {
      // 复制失败
    }
  }

  async moveFeedToFolder(feed: RSSFeedWithUnread, folderId: number | null) {
    try {
      await FeedDAO.updateFeed(feed.id, { folderId: folderId })
      
      await Promise.all([
        this.loadFeeds(),
        this.loadFolders()
      ])
      
      await this.updateUnreadCountsSilently()
      
    } catch (error) {
      this.operationError = `移动失败: ${error}`
      
      setTimeout(() => {
        this.operationError = null
      }, 3000)
    }
  }

  async refreshSingleFeed(feed: RSSFeedWithUnread) {
    try {
      this.operationError = null
      
      this.refreshProgress = `正在刷新: ${feed.title}`
      
      await RSSRefreshService.refreshSingleFeed(feed.id)
      
      await this.loadUnreadCounts()
      
      await this.updateUnreadCountsSilently()
      
      this.refreshProgress = `刷新完成: ${feed.title}`
      
      setTimeout(() => {
        this.refreshProgress = ''
      }, 2000)
      
    } catch (error) {
      this.refreshProgress = ''
      this.operationError = `刷新失败: ${error}`
      
      setTimeout(() => {
        this.operationError = null
      }, 3000)
    }
  }

  startEditingFolder(folder: RSSFolderWithUnread) {
    this.editingFolderId = folder.id
    this.editingFolderName = folder.name
  }

  async confirmRenameFolder() {
    if (this.editingFolderId === null || this.editingFolderName.trim() === '') {
      this.cancelRenameFolder()
      return
    }

    try {
      const newName = this.editingFolderName.trim()
      const editingId = this.editingFolderId
      
      const existingFolder = this.folders.find(f => f.name === newName && f.id !== editingId)
      if (existingFolder) {
        this.operationError = '文件夹名称已存在'
        setTimeout(() => {
          this.operationError = null
        }, 3000)
        return
      }

      this.editingFolderId = null
      this.editingFolderName = ''

      const updatedFolders: RSSFolderWithUnread[] = []
      for (const folder of this.folders) {
        if (folder.id === editingId) {
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
      
      this.uiUpdateTrigger++

      await FolderDAO.updateFolder(editingId, { name: newName })
      
    } catch (error) {
      this.operationError = `重命名失败: ${error}`
      
      setTimeout(() => {
        this.operationError = null
      }, 3000)
      
      await this.loadFolders()
    }
  }

  cancelRenameFolder() {
    this.editingFolderId = null
    this.editingFolderName = ''
  }

  async deleteFolder(folder: RSSFolderWithUnread) {
    try {
      const folderFeeds = this.feeds.filter(feed => feed.folderId === folder.id)
      
      for (const feed of folderFeeds) {
        try {
          await FeedDAO.updateFeed(feed.id, { folderId: null })
        } catch (error) {
          // 继续移动其他FEED
        }
      }
      
      await FolderDAO.deleteFolder(folder.id)
      
      await Promise.all([
        this.loadFeeds(),
        this.loadFolders()
      ])
      
      this.uiUpdateTrigger++
      
      await this.updateUnreadCountsSilently()
      
    } catch (error) {
      this.operationError = `删除文件夹失败: ${error}`
      
      setTimeout(() => {
        this.operationError = null
      }, 3000)
    }
  }

  async moveFolderToTop(folder: RSSFolderWithUnread) {
    try {
      await FolderDAO.moveFolderToTop(folder.id)
      await this.loadFolders()
      this.uiUpdateTrigger++
    } catch (error) {
      this.operationError = `移动失败: ${error}`
      setTimeout(() => { this.operationError = null }, 3000)
    }
  }

  async moveFolderToBottom(folder: RSSFolderWithUnread) {
    try {
      await FolderDAO.moveFolderToBottom(folder.id)
      await this.loadFolders()
      this.uiUpdateTrigger++
    } catch (error) {
      this.operationError = `移动失败: ${error}`
      setTimeout(() => { this.operationError = null }, 3000)
    }
  }

  async exportOpml() {
    this.operationError = null
    this.refreshProgress = '正在生成OPML文件...'

    try {
      const opmlString = await OPMLService.generateOpml()
      const context = getContext(this) as common.UIAbilityContext
      
      this.refreshProgress = '请选择保存位置...'
      const filePath = await OPMLService.saveOpmlFileWithPicker(opmlString, context)

      try {
        const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, filePath)
        const systemPaste = pasteboard.getSystemPasteboard()
        await systemPaste.setData(pasteData)
      } catch (e) {
        // ignore
      }

      this.refreshProgress = `OPML导出成功！已保存至:\n${filePath}(已复制路径)`
      setTimeout(() => {
        this.refreshProgress = ''
      }, 5000)
    } catch (error) {
      this.refreshProgress = ''
      if (error && error.message && !error.message.includes('用户取消')) {
        this.operationError = `导出失败: ${error.message}`
        setTimeout(() => {
          this.operationError = null
        }, 3000)
      }
    }
  }

  addSubscription() {
    this.showAddInput = true
    this.addInputType = 'subscription'
    this.addInputValue = ''
  }

  addFolder() {
    this.showAddInput = true
    this.addInputType = 'folder'
    this.addInputValue = ''
  }

  async confirmAdd() {
    if (!this.addInputValue.trim()) {
      this.cancelAdd()
      return
    }

    try {
      this.operationError = null
      
      if (this.addInputType === 'subscription') {
        const url = this.addInputValue.trim()
        this.cancelAdd()
        
        await this.performAddSubscription(url)
      } else if (this.addInputType === 'folder') {
        await this.performAddFolder(this.addInputValue.trim())
        this.cancelAdd()
      } else if (this.addInputType === 'icon') {
        await this.confirmSetIcon()
      }
      
    } catch (error) {
      this.operationError = `添加失败: ${error}`
      
      setTimeout(() => {
        this.operationError = null
      }, 3000)
    }
  }

  cancelAdd() {
    this.showAddInput = false
    this.addInputType = null
    this.addInputValue = ''
    this.settingIconFeedId = null
  }

  setFeedIcon(feed: RSSFeedWithUnread) {
    this.showAddInput = true
    this.addInputType = 'icon'
    this.addInputValue = ''
    this.settingIconFeedId = feed.id
  }

  async confirmSetIcon() {
    if (!this.addInputValue.trim() || this.settingIconFeedId === null) {
      this.cancelAdd()
      return
    }

    try {
      const iconUrl = this.addInputValue.trim()
      const feedId = this.settingIconFeedId
      
      this.cancelAdd()
      
      this.refreshProgress = '正在下载图标...'
      
      const context = getContext(this) as common.UIAbilityContext
      
      const faviconPath = await FaviconDownloader.downloadAndSaveFavicon(feedId, iconUrl, context)
      
      if (faviconPath) {
        await FeedDAO.updateFaviconPath(feedId, faviconPath)
        
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
        
        this.uiUpdateTrigger++
        
        this.refreshProgress = '图标设置成功！'
        
        setTimeout(() => {
          this.refreshProgress = ''
        }, 2000)
      } else {
        throw new Error('图标下载失败')
      }
      
    } catch (error) {
      this.refreshProgress = ''
      this.operationError = `设置图标失败: ${error}`
      
      setTimeout(() => {
        this.operationError = null
      }, 3000)
    }
  }

  async performAddSubscription(url: string) {
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      throw new Error('请输入有效的URL（需要以http://或https://开头）')
    }

    const newFeedId = await FeedDAO.addFeed({
      url: url,
      title: url,
      description: '',
      link: '',
      language: '',
      lastBuildDate: '',
      imageUrl: '',
      category: '',
      isActive: true,
      sortOrder: 0
    })

    this.refreshProgress = `正在获取RSS源内容: ${url}`
    
    try {
      await RSSRefreshService.refreshSingleFeed(newFeedId)
      
      this.refreshProgress = `RSS源添加完成: ${url}`
      
      setTimeout(() => {
        this.refreshProgress = ''
      }, 2000)
      
    } catch (refreshError) {
      this.refreshProgress = `RSS源已添加，但内容获取失败: ${refreshError}`
      
      setTimeout(() => {
        this.refreshProgress = ''
      }, 3000)
    }
    
    await Promise.all([
      this.loadFeeds(),
      this.loadUnreadCounts()
    ])
    
    await this.updateUnreadCountsSilently()
  }

  async performAddFolder(name: string) {
    try {
      await FolderDAO.createFolder({ name })

      await this.loadFolders()

      this.uiUpdateTrigger++
    } catch (error) {
      if (error instanceof Error) {
        throw error
      } else {
        throw new Error(String(error))
      }
    }
  }

  async deleteFeed(feed: RSSFeedWithUnread) {
    try {
      await FeedDataService.deleteFeed(feed.id)

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

  async refreshUnreadCounts() {
    try {
      await this.updateUnreadCountsSilently()
      
    } catch (error) {
      this.operationError = `刷新失败: ${error}`
      
      setTimeout(() => {
        this.operationError = null
      }, 3000)
    }
  }

  private async updateUnreadCountsSilently() {
    try {
      await this.loadUnreadCounts()
      
      if (this.feeds.length > 0) {
        await this.updateFeedsUnreadCountsSilently()
      }
      
      if (this.folders.length > 0) {
        this.updateFoldersUnreadCountsSilently()
      }
      
      this.updateSpecialFeedsUnreadCountsSilently()
      
    } catch (error) {
      if (error instanceof Error) {
        throw error
      } else {
        throw new Error(String(error))
      }
    }
  }

  private async updateFeedsUnreadCountsSilently(): Promise<void> {
    try {
      const feedIds = this.feeds.map(feed => feed.id)
      if (feedIds.length === 0) return
      const unreadCounts = await FeedDataService.getFeedsUnreadCounts(feedIds)

      const updatedFeeds: RSSFeedWithUnread[] = []
      
      for (const feed of this.feeds) {
        const newCount = unreadCounts.get(feed.id) || 0
        
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
      
      this.feeds = updatedFeeds

    } catch (error) {
      // 静默失败
    }
  }

  private updateSpecialFeedsUnreadCountsSilently(): void {
    if (this.specialFeeds.length === 0) {
      this.initializeSpecialFeeds()
    }
    
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
      
      const updatedFeed: RSSFeed = {
        id: feed.id,
        folderId: feed.folderId,
        title: feed.title,
        description: feed.description,
        url: feed.url,
        favicon: feed.favicon,
        unreadCount: newUnreadCount
      }
      updatedSpecialFeeds.push(updatedFeed)
    }
    
    this.specialFeeds = updatedSpecialFeeds
    
    this.uiUpdateTrigger++
  }

  private updateFoldersUnreadCountsSilently(): void {
    const updatedFolders: RSSFolderWithUnread[] = []
    
    for (const folder of this.folders) {
      const folderFeeds = this.feeds.filter(feed => feed.folderId === folder.id)
      const totalUnread = folderFeeds.reduce((sum, feed) => sum + feed.unreadCount, 0)
      
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
    
    this.folders = updatedFolders
    
    this.uiUpdateTrigger++
  }

  async fullRefresh() {
    try {
      this.isRefreshing = true
      this.refreshProgress = '准备刷新...'
      
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
      
      for (let i = 0; i < activeFeeds.length; i++) {
        const feed = activeFeeds[i]
        this.currentRefreshIndex = i + 1
        this.currentRefreshingFeed = feed.title
        this.refreshProgress = `正在刷新 (${this.currentRefreshIndex}/${this.totalFeedsToRefresh}): ${feed.title}`
        
        try {
          await RSSRefreshService.refreshSingleFeed(feed.id)
        } catch (feedError) {
          // 继续刷新其他FEED
        }
      }
      
      this.refreshProgress = '更新未读数量...'
      await this.loadUnreadCounts()
      
      this.refreshProgress = `刷新完成！共处理 ${this.totalFeedsToRefresh} 个FEED`
      
      setTimeout(() => {
        this.refreshProgress = ''
        this.currentRefreshingFeed = ''
        this.totalFeedsToRefresh = 0
        this.currentRefreshIndex = 0
        this.isRefreshing = false
      }, 2000)
      
      if (this.onRef) {
        this.onRef(this)
      }
    } catch (error) {
      this.operationError = `刷新失败: ${error}`
      this.refreshProgress = ''
      this.isRefreshing = false
      
      setTimeout(() => {
        this.operationError = null
      }, 3000)
    } finally {
      // 不需要重置isLoading，因为我们没有设置它
    }
  }

  @Builder
  getFeedIcon(feed: RSSFeedWithUnread) {
    if (feed.faviconPath && feed.faviconPath.trim() !== '') {
      Image('file://' + feed.faviconPath)
        .width(20)
        .height(20)
        .margin({ right: 12 })
        .borderRadius(4)
        .alt($r("app.media.rss"))
    } else {
      Image($r("app.media.rss"))
        .width(20)
        .height(20)
        .margin({ right: 12 })
        .borderRadius(4)
    }
  }

  @Builder
  UnreadBadge(count: number) {
    if (count > 0) {
      Text(`${count}${this.uiUpdateTrigger >= 0 ? '' : ''}`)
        .fontSize(12)
        .fontColor('#fff')
        .backgroundColor('#5C9DFF') // 更加淡雅的蓝色
        .borderRadius(10)
        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
    }
  }

  // 创建FEED右键菜单
  @Builder
  createFeedContextMenu(feed: RSSFeedWithUnread) {
    Menu() {
      MenuItem({ 
        content: "刷新"
      })
        .onClick(() => {
          this.refreshSingleFeed(feed)
        })

      MenuItem({ 
        content: "缓存图片"
      })
        .onClick(() => {
          this.cacheImagesForFeed(feed)
        })

      MenuItem({ 
        content: "复制FEED地址"
      })
        .onClick(() => {
          this.copyFeedUrl(feed)
        })

      if (feed.folderId !== null) {
        MenuItem({
          content: "移动到根目录"
        })
          .onClick(() => {
            this.moveFeedToFolder(feed, null)
          })
      }

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

      MenuItem({
        content: "设置图标"
      })
        .onClick(() => {
          this.setFeedIcon(feed)
        })

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
      MenuItem({
        content: "重命名"
      })
        .onClick(() => {
          this.startEditingFolder(folder)
        })

      MenuItem({
        content: "删除文件夹"
      })
        .onClick(() => {
          this.deleteFolder(folder)
        })

      MenuItem({
        content: "移到最上面"
      })
        .onClick(() => {
          this.moveFolderToTop(folder)
        })

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
      MenuItem({
        content: "添加订阅"
      })
        .onClick(() => {
          this.addSubscription()
        })

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
      MenuItem({
        content: "添加订阅"
      })
        .onClick(() => {
          this.addSubscription()
        })

      MenuItem({
        content: "添加文件夹"
      })
        .onClick(() => {
          this.addFolder()
        })

      MenuItem({
        content: "刷新所有"
      })
        .onClick(() => {
          this.fullRefresh()
        })

      MenuItem({
        content: "导入OPML"
      })
        .onClick(() => {
          this.refreshProgress = '请选择要导入的OPML文件...'
          const context = getContext(this) as common.UIAbilityContext
          OPMLService.importOpmlWithPicker(context).then(async () => {
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

      MenuItem({
        content: "导出OPML"
      })
        .onClick(() => {
          this.exportOpml()
        })

      MenuItem({
        content: this.autoRefreshEnabled ? '已打开自动刷新' : '已关闭自动刷新'
      })
        .onClick(() => {
          this.toggleAutoRefresh()
        })

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
  }

  build() {
    Column() {
      Row() {
        Text('订阅源')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#000')
          .layoutWeight(1)

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

        Image($r("app.media.new"))
          .width(20)
          .height(20)
          .fillColor('#666666')

          .bindContextMenu(this.createAddMenu(), ResponseType.RightClick)
          .onClick(() => {
            this.addSubscription()
          })
      }
      .width('100%')
      .height(50)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#f7f7f7')
      .border({ width: { bottom: 1 }, color: '#e0e0e0' })

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .margin({ top: 40 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.error && this.error.includes('数据库')) {
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
          ForEach(this.specialFeeds, (feed: RSSFeed) => {
            ListItem() {
              Row() {
                Image(feed.favicon || $r("app.media.rss"))
                  .width(20)
                  .height(20)
                  .margin({ right: 12 })
                  .fillColor('#666666')

                Text(feed.title)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#000')
                  .textAlign(TextAlign.Start)
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

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
              .height(40)
              .padding({ left: 16, right: 16 })
              .backgroundColor(this.selectedFeedId === feed.id ? '#f0f7ff' : '#fff')
              .alignItems(VerticalAlign.Center)
            }
            .onClick(() => {
              this.selectedFeedId = feed.id
              AppStorage.set('selectedFeedId', feed.id)
            })
          }, (feed: RSSFeed) => `${feed.id}_${this.uiUpdateTrigger}`)

          ListItem() {
            Divider()
              .strokeWidth(4)
              .color('#f5f5f5')
          }

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

          ForEach(this.folders, (folder: RSSFolderWithUnread) => {
            ListItem() {
              Row() {
                Image(this.expandedFolders.has(folder.id) ? $r("app.media.folder_open") : $r("app.media.folder_close"))
                  .width(20)
                  .height(20)
                  .margin({ right: 12 })
                  .fillColor('#666666')

                if (this.editingFolderId === folder.id) {
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
                  Text(folder.name)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#000')
                    .textAlign(TextAlign.Start)
                    .layoutWeight(1)
                  
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
              if (this.editingFolderId !== folder.id) {
                this.toggleFolderExpanded(folder.id)
              }
            })
            .bindContextMenu(this.createFolderContextMenu(folder), ResponseType.RightClick)

            if (this.expandedFolders.has(folder.id)) {
              ForEach(this.feeds.filter(feed => feed.folderId === folder.id), (feed: RSSFeedWithUnread) => {
                ListItem() {
                  Row() {
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
                  AppStorage.set('selectedFeedId', feed.id.toString())
                })
                .bindContextMenu(this.createFeedContextMenu(feed), ResponseType.RightClick)
              }, (feed: RSSFeedWithUnread) => `${folder.id}_${feed.id}_${this.uiUpdateTrigger}`)

              if (this.feeds.filter(feed => feed.folderId === folder.id).length === 0) {
                ListItem() {
                  Row() {
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

          ForEach(this.feeds.filter(feed => feed.folderId === null), (feed: RSSFeedWithUnread) => {
            ListItem() {
              Row() {
                this.getFeedIcon(feed)

                Text(feed.title)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#000')
                  .textAlign(TextAlign.Start)
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

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
              AppStorage.set('selectedFeedId', feed.id.toString())
            })
            .bindContextMenu(this.createFeedContextMenu(feed), ResponseType.RightClick)
          }, (feed: RSSFeedWithUnread) => `${feed.id.toString()}_${this.uiUpdateTrigger}`)

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
        .bindContextMenu(this.createGeneralContextMenu(), ResponseType.RightClick)
      }

        if (this.refreshProgress !== '' || this.operationError !== null) {
          Row() {
            if (this.refreshProgress !== '') {
              Row() {
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