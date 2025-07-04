import { RSSFeed, RSSArticle, mockRSSFeeds, RSSDataService } from '../model/RSSModel'
import { RSSFeedList } from '../component/RSSFeedList'
import RSSArticleList from '../component/RSSArticleList'
import RSSArticleDetail from '../component/RSSArticleDetail'
import PreferencesUtil from '../utils/PreferencesUtil'
import { GlobalState } from '../model/GlobalState'

@Entry
@Component
struct Index {
  @State selectedFeed: RSSFeed | undefined = undefined
  @State selectedArticle: RSSArticle | undefined = undefined
  @State isInitialized: boolean = false // 标记是否已初始化
  @State @Watch('onRefreshTriggerChanged') refreshTrigger: number = 0 // 用于触发列表刷新

  // 监听全局选中的RSS源ID变化
  @StorageLink('selectedFeedId') @Watch('onGlobalFeedChanged') globalSelectedFeedId: string = ''
  // 全局状态监听
  @StorageLink('selectedArticleId') @Watch('onGlobalArticleChanged') globalSelectedArticleId: string = ''
  @StorageLink('currentArticleIndex') @Watch('onGlobalIndexChanged') globalCurrentIndex: number = -1
  @StorageLink('isFirstColumnCollapsed') isFirstColumnCollapsed: boolean = false // 控制第一栏折叠状态
  
  // RSS源列表组件的引用，用于更新未读计数
  private rssFeelListRef: RSSFeedList | undefined = undefined
  // 文章列表组件的引用，用于刷新文章列表
  private rssArticleListRef: RSSArticleList | undefined = undefined

  /**
   * 监听全局选中的RSS源变化
   */
  async onGlobalFeedChanged() {
    console.info('Index', `全局选中RSS源变化: ${this.globalSelectedFeedId}`)

    // 如果有选中的RSS源ID
    if (this.globalSelectedFeedId) {
      try {
        // 优先从数据库获取完整的RSS源数据
        const feeds = await RSSDataService.getAllFeeds()
        const targetFeed = feeds.find(feed => feed.id === this.globalSelectedFeedId)
        if (targetFeed) {
          this.selectedFeed = targetFeed
          // 同步到列表组件的高亮状态
          if (this.rssFeelListRef) {
            this.rssFeelListRef.setSelectedFeed(targetFeed.id)
          }
          // 保存到首选项
          if (PreferencesUtil.isInitialized()) {
            PreferencesUtil.saveSelectedFeedIdSync(targetFeed.id)
          }
          return
        }
      } catch (error) {
        console.error('Index', '根据ID加载RSS源失败，尝试使用mock数据:', JSON.stringify(error))
      }

      // 数据库查询失败时，先尝试降级到mock数据
      const mockFeed = mockRSSFeeds.find(feed => feed.id === this.globalSelectedFeedId)
      if (mockFeed) {
        this.selectedFeed = mockFeed
        if (this.rssFeelListRef) {
          this.rssFeelListRef.setSelectedFeed(mockFeed.id)
        }
      } else {
        // 进一步检查是否为特殊标签（今天/收藏/全部未读）
        const specialFeed = this.getSpecialFeedById(this.globalSelectedFeedId)
        if (specialFeed) {
          this.selectedFeed = specialFeed
          if (this.rssFeelListRef) {
            this.rssFeelListRef.setSelectedFeed(specialFeed.id)
          }
        }
      }
    } else {
      // 如果全局选中ID为空，清空本地状态
      this.selectedFeed = undefined
      this.selectedArticle = undefined
    }

    // 切换RSS源后，刷新文章列表
    if (this.rssArticleListRef) {
      this.rssArticleListRef.loadArticles()
    }
  }

  // 记录列宽度的状态，支持拖拽调整
  @State firstColumnWidth: number = 250      // 第一栏宽度（默认250）
  @State secondColumnWidth: number = 310     // 第二栏宽度（默认310）

  // 所有回调函数已移除，使用全局状态管理：
  // onFeedClick → GlobalState.selectFeed()
  // onArticleClick → GlobalState.selectArticle()
  // onArticleReadStatusChanged → GlobalState.updateArticleReadStatus()
  // onToggleFirstColumn → GlobalState.toggleFirstColumn()
  
  // 处理订阅源点击（现在监听全局状态变化）
  onFeedSelection = (feed: RSSFeed) => {
    this.selectedFeed = feed
    // 重置选中的文章
    this.selectedArticle = undefined
    
    // 同步RSS源列表的选中状态
    if (this.rssFeelListRef) {
      this.rssFeelListRef.setSelectedFeed(feed.id)
    }
    // 同步保存当前选中的RSS源ID（先检查是否已初始化）
    if (PreferencesUtil.isInitialized()) {
      PreferencesUtil.saveSelectedFeedIdSync(feed.id)
    }
  }

  // RSS源列表组件引用设置回调
  onRSSFeedListRef = (ref: RSSFeedList) => {
    this.rssFeelListRef = ref
    // 如果已经有选中的源，同步到列表组件
    if (this.selectedFeed) {
      ref.setSelectedFeed(this.selectedFeed.id)
    }
  }

  // RSS文章列表组件引用设置回调
  onRSSArticleListRef = (ref: RSSArticleList) => {
    this.rssArticleListRef = ref
  }

  // 处理refreshTrigger变化的回调
  onRefreshTriggerChanged() {
    // 刷新文章列表
    if (this.rssArticleListRef) {
      this.rssArticleListRef.loadArticles()
    }
    // 刷新RSS源列表的未读数量
    if (this.rssFeelListRef) {
      this.rssFeelListRef.refreshUnreadCounts()
    }
  }

  /**
   * 监听全局选中文章变化
   */
  onGlobalArticleChanged() {
    console.info('Index', `全局选中文章变化: ${this.globalSelectedArticleId}`)
    
    if (this.globalSelectedArticleId && this.rssArticleListRef) {
      // 从文章列表中找到对应的文章
      const articleList = this.rssArticleListRef.getCurrentArticleList()
      const article = articleList.find(a => a.id === this.globalSelectedArticleId)
      
      if (article) {
        this.selectedArticle = article
        console.info('Index', `更新本地选中文章: ${article.title}`)
      }
    } else if (!this.globalSelectedArticleId) {
      // 如果全局选中文章ID为空，清除本地选中文章
      this.selectedArticle = undefined
      console.info('Index', '清除本地选中文章')
    }
  }

  /**
   * 监听全局文章索引变化
   */
  onGlobalIndexChanged() {
    console.info('Index', `全局文章索引变化: ${this.globalCurrentIndex}`)
    // 索引变化时，文章选择逻辑由RSSArticleList处理
    // 这里只需要记录日志
  }

  // 文章切换回调已移除，现在直接使用全局状态管理：
  // onPreviousArticle → GlobalState.switchToPreviousArticle()
  // onNextArticle → GlobalState.switchToNextArticle()

  // 计算是否可以切换到上一篇（使用全局状态）
  private canGoPrevious(): boolean {
    const currentIndex = AppStorage.get<number>('currentArticleIndex') || -1
    return currentIndex > 0
  }

  // 计算是否可以切换到下一篇（使用全局状态）
  private canGoNext(): boolean {
    const currentIndex = AppStorage.get<number>('currentArticleIndex') || -1
    const totalArticles = AppStorage.get<number>('articleListTotal') || 0
    return currentIndex >= 0 && currentIndex < totalArticles - 1
  }

  // getNextArticle 方法已移除，现在使用 GlobalState.getNextArticle()

  /**
   * 根据特殊标签ID返回对应的 RSSFeed 对象
   */
  private getSpecialFeedById(id: string): RSSFeed | undefined {
    switch (id) {
      case 'today':
        return {
          id: 'today',
          folderId: null,
          title: '今天',
          description: '今日文章',
          url: '',
          favicon: $r('app.media.today'),
          unreadCount: 0
        }
      case 'favorites':
        return {
          id: 'favorites',
          folderId: null,
          title: '收藏',
          description: '收藏的文章',
          url: '',
          favicon: $r('app.media.star'),
          unreadCount: 0
        }
      case 'unread':
        return {
          id: 'unread',
          folderId: null,
          title: '全部未读',
          description: '所有未读文章',
          url: '',
          favicon: $r('app.media.unread'),
          unreadCount: 0
        }
      default:
        return undefined
    }
  }

  // 组件即将出现时的生命周期
  async aboutToAppear() {
    try {
    // 获取应用上下文并初始化首选项
    const context = getContext(this) as Context
    
    // 尝试使用同步方法初始化（如果失败则使用异步方法）
    let initialized = PreferencesUtil.initSync(context)
    if (!initialized) {
      initialized = await PreferencesUtil.init(context)
    }
    
    if (initialized) {
      // 恢复状态
      await this.restoreStates()
    } else {
      console.error('Index', '首选项初始化失败，将使用默认状态')
    }

      // 标记初始化完成
      this.isInitialized = true

    // RSS源列表会在其自己的aboutToAppear中自动加载数据
    } catch (error) {
      console.error('Index', '初始化过程中发生错误:', JSON.stringify(error))
      this.isInitialized = true // 即使出错也标记为已初始化，避免UI阻塞
    }
  }

  /**
   * 恢复保存的状态（使用同步方法提高性能）
   */
  private async restoreStates() {
    try {
      // 检查PreferencesUtil是否已初始化
      if (!PreferencesUtil.isInitialized()) {
        console.warn('Index', 'PreferencesUtil未初始化，跳过状态恢复')
        return
      }

      // 恢复第一栏折叠状态并同步到全局状态
      const savedCollapseState = PreferencesUtil.getFirstColumnCollapseStateSync()
      GlobalState.setFirstColumnCollapsed(savedCollapseState)
      
      // 恢复选中的RSS源
      const savedFeedId = PreferencesUtil.getSelectedFeedIdSync()
      if (savedFeedId) {
        // 首先尝试从数据库获取RSS源
        try {
          const feeds = await RSSDataService.getAllFeeds()
          const savedFeed = feeds.find(feed => feed.id === savedFeedId)
          if (savedFeed) {
            this.selectedFeed = savedFeed
            // 同步RSS源列表的选中状态
            if (this.rssFeelListRef) {
              this.rssFeelListRef.setSelectedFeed(savedFeed.id)
            }
          }
        } catch (error) {
          // 降级到mock数据
          const savedFeed = mockRSSFeeds.find(feed => feed.id === savedFeedId)
          if (savedFeed) {
            this.selectedFeed = savedFeed
            // 同步RSS源列表的选中状态
            if (this.rssFeelListRef) {
              this.rssFeelListRef.setSelectedFeed(savedFeed.id)
            }
          }
        }
      }
      
      // 恢复列宽度（带边界检查）
      const savedFirstWidth = PreferencesUtil.getFirstColumnWidthSync()
      const savedSecondWidth = PreferencesUtil.getSecondColumnWidthSync()
      if (savedFirstWidth >= 200 && savedFirstWidth <= 300) {
        this.firstColumnWidth = savedFirstWidth
      }
      if (savedSecondWidth >= 250 && savedSecondWidth <= 400) {
        this.secondColumnWidth = savedSecondWidth
      }
      
      console.info('Index', `状态恢复完成 - 折叠状态: ${this.isFirstColumnCollapsed}, 选中RSS源: ${this.selectedFeed ? this.selectedFeed.title : '无'}`)
    } catch (error) {
      console.error('Index', '状态恢复失败:', JSON.stringify(error))
    }
  }

  build() {
    if (!this.isInitialized) {
      // 显示加载页面，避免在初始化前创建状态管理问题
      Column() {
        Text('正在初始化...')
          .fontSize(16)
          .fontColor("#666666")
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor("#f5f5f5")
    } else {
    Row() {
      // 第一栏：RSS订阅源列表（支持折叠）
      if (!this.isFirstColumnCollapsed) {
        Column() {
          RSSFeedList({ 
            onRef: this.onRSSFeedListRef 
          })
        }
        .width(this.firstColumnWidth)
        .height("100%")
        .backgroundColor("#f8f9fa")
        .transition(TransitionEffect.translate({ x: -this.firstColumnWidth }).animation({ duration: 300, curve: Curve.EaseInOut }))

        // 分割线
        Divider()
          .vertical(true)
          .color("#e0e0e0")
          .strokeWidth(3) // 分割线宽度
          .gesture(
            PanGesture({ direction: PanDirection.Horizontal, fingers: 1 })
              .onActionUpdate((event: GestureEvent) => {
                let newFirstWidth = this.firstColumnWidth + event.offsetX
                newFirstWidth = Math.max(200, Math.min(300, newFirstWidth)) // 范围200-300
                this.firstColumnWidth = newFirstWidth
              })
              .onActionEnd(() => {
                PreferencesUtil.saveFirstColumnWidthSync(this.firstColumnWidth)
              })
          )
      }

      // 第二栏：文章列表
      Column() {
          if (this.selectedFeed != undefined) {
        RSSArticleList({ 
          selectedFeed: this.selectedFeed,
              isFirstColumnCollapsed: this.isFirstColumnCollapsed,
              onRef: this.onRSSArticleListRef
            })
          } else {
            RSSArticleList({ 
              selectedFeed: undefined,
              isFirstColumnCollapsed: this.isFirstColumnCollapsed,
              onRef: this.onRSSArticleListRef
        })
          }
      }
      .width(this.secondColumnWidth)
      .height("100%")
      .backgroundColor("#ffffff")

      // 分割线
      Divider()
        .vertical(true)
        .color("#e0e0e0")
        .strokeWidth(3)
        .gesture(
          PanGesture({ direction: PanDirection.Horizontal, fingers: 1 })
            .onActionUpdate((event: GestureEvent) => {
              let newSecondWidth = this.secondColumnWidth + event.offsetX
              newSecondWidth = Math.max(250, Math.min(400, newSecondWidth)) // 范围250-400
              this.secondColumnWidth = newSecondWidth
            })
            .onActionEnd(() => {
              PreferencesUtil.saveSecondColumnWidthSync(this.secondColumnWidth)
            })
        )

      // 第三栏：文章详情
      Column() {
          if (this.selectedArticle != undefined) {
            RSSArticleDetail({ 
              selectedArticle: this.selectedArticle,
              refreshTrigger: $refreshTrigger,
              canGoPrevious: this.canGoPrevious(),
              canGoNext: this.canGoNext()
            })
          } else {
            RSSArticleDetail({ 
              selectedArticle: undefined,
              refreshTrigger: $refreshTrigger,
              canGoPrevious: false,
              canGoNext: false
            })
          }
      }
      .layoutWeight(1)
      .height("100%")
      .backgroundColor("#ffffff")
    }
    .width('100%')
    .height('100%')
    .backgroundColor("#e5e5e5")
    }
  }
}