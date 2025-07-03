import { RSSFeed, RSSArticle, mockRSSFeeds, RSSDataService } from '../model/RSSModel'
import { RSSFeedList } from '../component/RSSFeedList'
import RSSArticleList from '../component/RSSArticleList'
import RSSArticleDetail from '../component/RSSArticleDetail'
import PreferencesUtil from '../utils/PreferencesUtil'

@Entry
@Component
struct Index {
  @State selectedFeed: RSSFeed | undefined = undefined
  @State selectedArticle: RSSArticle | undefined = undefined
  @State isFirstColumnCollapsed: boolean = false // 控制第一栏折叠状态
  @State isInitialized: boolean = false // 标记是否已初始化
  @State @Watch('onRefreshTriggerChanged') refreshTrigger: number = 0 // 用于触发列表刷新
  
  // RSS源列表组件的引用，用于更新未读计数
  private rssFeelListRef: RSSFeedList | undefined = undefined
  // 文章列表组件的引用，用于刷新文章列表
  private rssArticleListRef: RSSArticleList | undefined = undefined

  // 记录列宽度的状态，支持拖拽调整
  @State firstColumnWidth: number = 250      // 第一栏宽度（默认250）
  @State secondColumnWidth: number = 310     // 第二栏宽度（默认310）

  // 处理订阅源点击的回调
  onFeedClick = (feed: RSSFeed) => {
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

  // 处理文章点击的回调
  onArticleClick = async (article: RSSArticle) => {
    this.selectedArticle = article
    // 标记文章为已读的逻辑已移动到下面的onArticleReadStatusChanged回调中
  }

  // 处理文章已读状态改变的回调
  onArticleReadStatusChanged = async () => {
    // 通知RSS源列表更新未读计数
    if (this.rssFeelListRef) {
      await this.rssFeelListRef.refreshUnreadCounts()
    } else {
      console.error('Index', 'rssFeelListRef 为空，无法刷新RSS源未读数量')
    }
  }

  // 处理折叠按钮点击的回调
  onToggleFirstColumn = () => {
    this.isFirstColumnCollapsed = !this.isFirstColumnCollapsed
    // 同步保存折叠状态（先检查是否已初始化）
    if (PreferencesUtil.isInitialized()) {
      PreferencesUtil.saveFirstColumnCollapseStateSync(this.isFirstColumnCollapsed)
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

  // 切换到上一篇文章
  onPreviousArticle = async () => {
    if (!this.rssArticleListRef) {
      console.warn('Index', '文章列表引用为空，无法切换到上一篇')
      return
    }

    const currentIndex = this.rssArticleListRef.getCurrentArticleIndex()
    if (currentIndex > 0) {
      const previousArticle = await this.rssArticleListRef.setSelectedArticleByIndex(currentIndex - 1)
      if (previousArticle) {
        this.selectedArticle = previousArticle
        console.info('Index', `切换到上一篇文章: ${previousArticle.title}`)
      }
    }
  }

  // 切换到下一篇文章
  onNextArticle = async () => {
    if (!this.rssArticleListRef) {
      console.warn('Index', '文章列表引用为空，无法切换到下一篇')
      return
    }

    const currentIndex = this.rssArticleListRef.getCurrentArticleIndex()
    const articleList = this.rssArticleListRef.getCurrentArticleList()
    if (currentIndex >= 0 && currentIndex < articleList.length - 1) {
      const nextArticle = await this.rssArticleListRef.setSelectedArticleByIndex(currentIndex + 1)
      if (nextArticle) {
        this.selectedArticle = nextArticle
        console.info('Index', `切换到下一篇文章: ${nextArticle.title}`)
      }
    }
  }

  // 计算是否可以切换到上一篇
  private canGoPrevious(): boolean {
    if (!this.rssArticleListRef) {
      return false
    }
    const currentIndex = this.rssArticleListRef.getCurrentArticleIndex()
    return currentIndex > 0
  }

  // 计算是否可以切换到下一篇
  private canGoNext(): boolean {
    if (!this.rssArticleListRef) {
      return false
    }
    const currentIndex = this.rssArticleListRef.getCurrentArticleIndex()
    const articleList = this.rssArticleListRef.getCurrentArticleList()
    return currentIndex >= 0 && currentIndex < articleList.length - 1
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

      // 恢复第一栏折叠状态
      this.isFirstColumnCollapsed = PreferencesUtil.getFirstColumnCollapseStateSync()
      
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
            onFeedClick: this.onFeedClick,
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
          onArticleClick: this.onArticleClick,
          onArticleReadStatusChanged: this.onArticleReadStatusChanged,
          onToggleFirstColumn: this.onToggleFirstColumn,
              isFirstColumnCollapsed: this.isFirstColumnCollapsed,
              onRef: this.onRSSArticleListRef
            })
          } else {
            RSSArticleList({ 
              selectedFeed: undefined,
              onArticleClick: this.onArticleClick,
              onArticleReadStatusChanged: this.onArticleReadStatusChanged,
              onToggleFirstColumn: this.onToggleFirstColumn,
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
              canGoNext: this.canGoNext(),
              onPreviousArticle: this.onPreviousArticle,
              onNextArticle: this.onNextArticle
            })
          } else {
            RSSArticleDetail({ 
              selectedArticle: undefined,
              refreshTrigger: $refreshTrigger,
              canGoPrevious: false,
              canGoNext: false,
              onPreviousArticle: this.onPreviousArticle,
              onNextArticle: this.onNextArticle
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