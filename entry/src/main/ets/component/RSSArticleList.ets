import { RSSArticle, RSSFeed, mockRSSArticles, RSSDataService } from '../model/RSSModel'
import { DatabaseManager } from '../model/DatabaseManager'
import { GlobalState } from '../model/GlobalState'

@Component
export default struct RSSArticleList {
  @Prop @Watch('onSelectedFeedChanged') selectedFeed: RSSFeed | undefined = undefined
  @State articleList: RSSArticle[] = []
  @State selectedArticleId: string = ''
  @State showUnreadOnly: boolean = false
  @State filteredArticleList: RSSArticle[] = []
  @State retainedReadArticleIds: string[] = []

  onRef?: (ref: RSSArticleList) => void
  @Prop isFirstColumnCollapsed: boolean = false

  @StorageLink('selectedFeedId') globalSelectedFeedId: string = ''
  @StorageLink('selectedArticleId') globalSelectedArticleId: string = ''
  @StorageLink('currentArticleIndex') @Watch('onGlobalIndexChanged') globalCurrentIndex: number = -1
  @StorageLink('articleListTotal') globalArticleTotal: number = 0
  @StorageLink('refreshTrigger') @Watch('onGlobalRefreshTriggered') globalRefreshTrigger: number = 0

  aboutToAppear() {
    this.initializeArticleList()
    if (this.onRef) {
      this.onRef(this)
    }
  }

  onPageShow() {
    this.initializeArticleList()
  }

  onGlobalIndexChanged() {
    if (this.globalCurrentIndex >= 0 && this.globalCurrentIndex < this.filteredArticleList.length) {
      const targetArticle = this.filteredArticleList[this.globalCurrentIndex]
      if (targetArticle) {
        this.selectArticleByGlobalIndex(this.globalCurrentIndex)
      }
    }
  }

  // 同步当前 articleList 与全局状态中的已读/收藏信息
  private syncArticleStatuses() {
    this.articleList.forEach(article => {
      const latestRead = GlobalState.getArticleReadStatus(article.id)
      const latestStar = GlobalState.getArticleStarStatus(article.id)

      // 避免因状态写入延迟将已读回退为未读：
      // 若本地已标记为已读，则保持已读；否则以全局状态为准
      article.readStatus = article.readStatus || latestRead

      // 收藏状态可以直接覆盖（不会影响阅读流畅性）
      article.starredStatus = latestStar
    })
  }

  onGlobalRefreshTriggered() {
    const isSpecialUnread = this.selectedFeed && this.selectedFeed.id === 'unread'
    const usingUnreadFilter = this.showUnreadOnly

    if (isSpecialUnread || usingUnreadFilter) {
      // 仅同步状态并刷新过滤结果，避免自动刷新导致当前选中文章丢失
      this.syncArticleStatuses()
      this.updateFilteredList()
      return
    }

    // 默认行为：重新加载文章列表
    this.loadArticles()
  }

  onSelectedFeedChanged() {
    // 切换到新的 Feed（或特殊列表）时，重置“仅显示未读”过滤
    this.showUnreadOnly = false
    this.retainedReadArticleIds = []
    this.selectedArticleId = ''
    this.initializeArticleList()
  }

  private initializeArticleList() {
    if (this.selectedFeed != undefined) {
      this.loadArticles()
    } else {
      this.articleList = []
      this.filteredArticleList = []
    }
  }

  onArticleListChange() {
    this.updateFilteredList()
  }

  onShowUnreadOnlyChange() {
    this.updateFilteredList()
  }

  updateFilteredList() {
    if (this.showUnreadOnly) {
      // 仅显示未读，但需要确保当前选中的文章（即便已读）仍保留在列表中，避免选中状态丢失
      let unreadList: RSSArticle[] = this.articleList.filter(article => !article.readStatus)

      // 确保当前选中（已读）文章保留
      if (this.selectedArticleId) {
        const selected = this.articleList.find(article => article.id === this.selectedArticleId)
        if (selected && selected.readStatus && !unreadList.some(a => a.id === selected.id)) {
          unreadList = [selected, ...unreadList]
        }
      }

      // 将 retainedReadArticleIds 中的文章按顺序插入到列表顶部（若尚未存在）
      for (const retainedId of this.retainedReadArticleIds) {
        if (!unreadList.some(a => a.id === retainedId)) {
          const retainedArticle = this.articleList.find(a => a.id === retainedId)
          if (retainedArticle) {
            unreadList = [retainedArticle, ...unreadList]
          }
        }
      }

      this.filteredArticleList = unreadList
    } else {
      this.filteredArticleList = [...this.articleList]
    }
    
    this.syncToGlobalState()
  }

  private syncToGlobalState() {
    GlobalState.setArticleListTotal(this.filteredArticleList.length)
    GlobalState.setCurrentArticleList(this.filteredArticleList)
    
    const currentIndex = this.getCurrentArticleIndex()
    if (currentIndex === -1 && this.selectedArticleId) {
      // 在以下情况下，文章可能因为过滤而暂时不在列表中，但仍需保持详情页内容：
      // 1. 当前 RSS 源为 “全部未读” (id === 'unread')
      // 2. 已对当前源开启了 “仅显示未读”(showUnreadOnly === true)
      const isSpecialUnreadList = this.selectedFeed && this.selectedFeed.id === 'unread'

      // 若同时满足 not isSpecialUnreadList 且未启用未读过滤，则重置选中状态
      if (!isSpecialUnreadList && !this.showUnreadOnly) {
        AppStorage.set('currentArticleIndex', -1)
        AppStorage.set('selectedArticleId', '')
      }
      // 否则保持现有 selectedArticleId 和详情页状态不变
    } else if (currentIndex >= 0) {
      AppStorage.set('currentArticleIndex', currentIndex)
      AppStorage.set('selectedArticleId', this.selectedArticleId)
    }
  }

  private async selectArticleByGlobalIndex(index: number) {
    if (index < 0 || index >= this.filteredArticleList.length) {
      return
    }
    
    const article = this.filteredArticleList[index]
    if (!article) return
    
    this.selectedArticleId = article.id
    
    const wasUnread = !article.readStatus
    if (wasUnread) {
      article.readStatus = true
      this.articleList = [...this.articleList]
      this.updateFilteredList()

      // 将其加入保留列表，避免后续切换选中后被过滤掉
      if (!this.retainedReadArticleIds.includes(article.id)) {
        this.retainedReadArticleIds.unshift(article.id)
        // 限制大小，最多保留 20 条，避免列表无限增长
        if (this.retainedReadArticleIds.length > 20) {
          this.retainedReadArticleIds.pop()
        }
      }
      
      try {
        const success = await GlobalState.updateArticleReadStatus(article.id, true)
        if (!success) {
          article.readStatus = false
          this.articleList = [...this.articleList]
          this.updateFilteredList()
        }
      } catch (error) {
        console.error('RSSArticleList', '标记文章已读失败:', error)
        article.readStatus = false
        this.articleList = [...this.articleList]
        this.updateFilteredList()
      }
    }
    
    GlobalState.selectArticle(article.id, this.filteredArticleList.indexOf(article))
  }

  public async loadArticles() {
    if (this.selectedFeed) {
      try {
        let articles: RSSArticle[] = []
        
        if (this.isSpecialOption(this.selectedFeed.id)) {
          articles = await this.loadSpecialOptionArticles(this.selectedFeed.id)
        } else {
          articles = await RSSDataService.getArticlesByFeedId(this.selectedFeed.id)
          if (articles.length === 0) {
            articles = mockRSSArticles.filter(article => article.feedId === this.selectedFeed?.id)
          }
        }
        
        this.articleList = articles
        this.updateFilteredList()
        this.articleList = [...this.articleList]
        
      } catch (error) {
        console.error('RSSArticleList', '加载文章失败:', JSON.stringify(error))
        this.articleList = []
        this.updateFilteredList()
      }
    } else {
      this.articleList = []
      this.filteredArticleList = []
    }
  }

  private isSpecialOption(feedId: string): boolean {
    return ['today', 'favorites', 'unread'].includes(feedId)
  }

  private async loadSpecialOptionArticles(optionId: string): Promise<RSSArticle[]> {
    try {
      switch (optionId) {
        case 'today':
          return await RSSDataService.getTodayArticles()
        case 'favorites':
          return await RSSDataService.getFavoriteArticles()
        case 'unread':
          return await RSSDataService.getUnreadArticles()
        default:
          return []
      }
    } catch (error) {
      console.error('RSSArticleList', `加载特殊选项 ${optionId} 失败:`, JSON.stringify(error))
      return []
    }
  }

  private stripHtmlTags(html: string): string {
    if (!html) {
      return ''
    }
    return html.replace(/<[^>]*>/g, '')
      .replace(/&nbsp;/g, ' ')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&amp;/g, '&')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'")
      .trim()
  }

  getUnreadCount(): number {
    return this.articleList.filter(article => !article.readStatus).length
  }

  async markAllAsRead() {
    if (!this.selectedFeed) {
      return
    }

    try {
      if (this.isSpecialOption(this.selectedFeed.id)) {
        for (const article of this.articleList) {
          if (!article.readStatus) {
            try {
              await RSSDataService.markArticleAsRead(article.id)
              article.readStatus = true
            } catch (error) {
              console.error('RSSArticleList', `标记文章${article.id}已读失败`)
            }
          }
        }
      } else {
        const updatedCount = await RSSDataService.markAllAsReadByFeedId(this.selectedFeed.id)
        
        this.articleList.forEach(article => {
          article.readStatus = true
        })
      }
      
      this.articleList = [...this.articleList]
      this.updateFilteredList()
      
      // 触发全局刷新以更新RSSFeedList的未读数量
      GlobalState.triggerRefresh()
      
    } catch (error) {
      console.error('RSSArticleList', '批量标记已读失败:', JSON.stringify(error))
    }
  }

  toggleUnreadFilter() {
    this.showUnreadOnly = !this.showUnreadOnly
    if (!this.showUnreadOnly) {
      // 关闭过滤后，清空保留列表
      this.retainedReadArticleIds = []
    }
    this.updateFilteredList()
  }

  async toggleArticleReadStatus(article: RSSArticle) {
    try {
      const newReadStatus = !article.readStatus
      
      article.readStatus = newReadStatus
      this.articleList = [...this.articleList]
      this.updateFilteredList()
      
      const success = await GlobalState.updateArticleReadStatus(article.id, newReadStatus)
      
      if (success) {
        // ... existing code ...
      } else {
        article.readStatus = !newReadStatus
        this.articleList = [...this.articleList]
        this.updateFilteredList()
      }
    } catch (error) {
      console.error('RSSArticleList', '切换文章已读状态失败:', JSON.stringify(error))
      article.readStatus = !article.readStatus
      this.articleList = [...this.articleList]
      this.updateFilteredList()
    }
  }

  async toggleArticleStarStatus(article: RSSArticle) {
    try {
      const currentStarredStatus = article.starredStatus
      
      article.starredStatus = !currentStarredStatus
      this.articleList = [...this.articleList]
      this.updateFilteredList()
      
      const success = await GlobalState.updateArticleStarStatus(article.id, currentStarredStatus)
      
      if (success) {
        // ... existing code ...
      } else {
        article.starredStatus = currentStarredStatus
        this.articleList = [...this.articleList]
        this.updateFilteredList()
      }
    } catch (error) {
      console.error('RSSArticleList', '切换文章收藏状态失败:', JSON.stringify(error))
      article.starredStatus = !article.starredStatus
      this.articleList = [...this.articleList]
      this.updateFilteredList()
    }
  }

  @Builder
  createArticleContextMenu(article: RSSArticle) {
    Menu() {
      MenuItem({
        content: article.readStatus ? "标记为未读" : "标记为已读"
      })
        .onClick(() => {
          this.toggleArticleReadStatus(article)
        })

      MenuItem({
        content: article.starredStatus ? "取消收藏" : "添加收藏"
      })
        .onClick(() => {
          this.toggleArticleStarStatus(article)
        })
    }
  }

  build() {
    Column() {
      if (this.selectedFeed) {
        Row() {
          Image(this.isFirstColumnCollapsed ? $r("app.media.show") : $r("app.media.hide"))
            .width(20)
            .height(20)
            .margin({ right: 12 })
            .onClick(() => {
              GlobalState.toggleFirstColumn()
            })
          
          Text(this.selectedFeed.title)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor("#000000")
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .textAlign(TextAlign.Start)
            .layoutWeight(1)
            .margin({ right: 12 })
          
          Row() {
            Image(this.showUnreadOnly ? $r("app.media.filter_selected") : $r("app.media.filter_unselected"))
              .width(20)
              .height(20)
              .fillColor('#666666')
              .onClick(() => {
                this.toggleUnreadFilter()
              })
              .margin({ right: 8 })

            Image($r("app.media.mark_all"))
              .width(20)
              .height(20)
              .fillColor(this.getUnreadCount() > 0 ? "#666666" : "#cccccc")
              .enabled(this.getUnreadCount() > 0)
              .opacity(this.getUnreadCount() > 0 ? 1.0 : 0.5)
              .onClick(() => {
                this.markAllAsRead()
              })
          }
        }
        .width("100%")
        .height(50)
        .padding({ left: 16, right: 16 })
        .backgroundColor("#f7f7f7")
        .border({ width: { bottom: 1 }, color: "#e0e0e0" })

        List() {
          ForEach(this.filteredArticleList, (article: RSSArticle, index: number) => {
            ListItem() {
              this.ArticleItemView(article)
            }
            .bindContextMenu(this.createArticleContextMenu(article), ResponseType.RightClick)
            .onClick(async () => {
              this.selectedArticleId = article.id
              
              const articleIndex = this.filteredArticleList.findIndex(a => a.id === article.id)
              GlobalState.setSelectedArticle(article.id, articleIndex)
              
              const wasUnread = !article.readStatus
              
              if (wasUnread) {
                article.readStatus = true
                this.articleList = [...this.articleList]
                this.updateFilteredList()

                if (!this.retainedReadArticleIds.includes(article.id)) {
                  this.retainedReadArticleIds.unshift(article.id)
                  if (this.retainedReadArticleIds.length > 20) {
                    this.retainedReadArticleIds.pop()
                  }
                }
                
                try {
                  const success = await RSSDataService.markArticleAsRead(article.id)
                  
                  if (success) {
                    try {
                      const store = DatabaseManager.getStore()
                      if (store) {
                        const checkSql = 'SELECT read FROM statuses WHERE articleID = ?'
                        const checkResult = await store.querySql(checkSql, [article.id])
                        if (checkResult.rowCount > 0) {
                          checkResult.goToFirstRow()
                          const isRead = checkResult.getLong(0) === 1
                          checkResult.close()
                        } else {
                          console.error('RSSArticleList', `验证失败 - 数据库中找不到文章 ${article.id} 的状态记录`)
                        }
                      }
                    } catch (verifyError) {
                      console.error('RSSArticleList', '验证数据库状态失败:', verifyError)
                    }
                    
                    await new Promise<void>(resolve => setTimeout(resolve, 100))
                    
                    // 删除不存在的回调调用
                    
                  } else {
                    console.error('RSSArticleList', '数据库标记已读失败，回滚本地状态')
                    article.readStatus = false
                    this.articleList = [...this.articleList]
                    this.updateFilteredList()
                  }
                } catch (error) {
                  console.error('RSSArticleList', '标记文章已读失败:', JSON.stringify(error))
                  article.readStatus = false
                  this.articleList = [...this.articleList]
                  this.updateFilteredList()
                }
              }
              
              GlobalState.selectArticle(article.id, this.filteredArticleList.findIndex(a => a.id === article.id))
            })
          })
        }
        .width("100%")
        .layoutWeight(1)
        .backgroundColor("#ffffff")
        .divider({ strokeWidth: 0.5, color: '#f0f0f0', startMargin: 16, endMargin: 0 })
      } else {
        Column() {
          Row() {
            Image(this.isFirstColumnCollapsed ? $r("app.media.show") : $r("app.media.hide"))
              .width(20)
              .height(20)
              .margin({ right: 12 })
              .onClick(() => {
                GlobalState.toggleFirstColumn()
              })
            
            Text(this.isFirstColumnCollapsed ? "专注模式" : "文章列表")
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor("#000000")
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            
            Blank()
          }
          .width("100%")
          .height(50)
          .padding({ left: 16, right: 16 })
          .backgroundColor("#f7f7f7")
          .border({ width: { bottom: 1 }, color: "#e0e0e0" })

          Column() {
            Image($r("app.media.rss"))
              .width(80)
              .height(80)
              .opacity(0.3)
              .margin({ bottom: 16 })
            
            Text("选择一个订阅源查看文章")
              .fontSize(16)
              .fontColor("#999999")
          }
          .width("100%")
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor("#ffffff")
        }
        .width("100%")
        .height("100%")
        .backgroundColor("#f5f5f5")
      }
    }
    .width("100%")
    .height("100%")
    .backgroundColor("#f5f5f5")
  }

  @Builder
  ArticleItemView(article: RSSArticle) {
    Row() {
      Column() {
        Text(article.title)
          .fontSize(16)
          .fontWeight(article.readStatus ? FontWeight.Normal : FontWeight.Medium)
          .fontColor(article.readStatus ? "#666666" : "#000000")
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width("100%")
          .textAlign(TextAlign.Start)
          .lineHeight(22)
        
        Text(this.stripHtmlTags(article.summary).substring(0, 50))
          .fontSize(14)
          .fontColor(article.readStatus ? "#999999" : "#888888")
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width("100%")
          .textAlign(TextAlign.Start)
          .margin({ top: 6 })
          .lineHeight(20)
        
        Row() {
          Text(article.publishDate)
            .fontSize(12)
            .fontColor(article.readStatus ? "#aaaaaa" : "#999999")
            
          Blank()
          
          if (article.starredStatus) {
            Image($r("app.media.star"))
              .width(12)
              .height(12)
              .fillColor("#ffb300")
              .margin({ right: 6 })
          }
          
          if (!article.readStatus) {
            Circle({ width: 8, height: 8 })
              .fill("#ff4444")
          }
        }
        .width("100%")
        .margin({ top: 8 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width("100%")
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(this.selectedArticleId === article.id ? "#e3f2fd" : 
      (article.readStatus ? "#f8f8f8" : "#ffffff"))
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Top)
  }

  getCurrentArticleIndex(): number {
    if (!this.selectedArticleId) {
      return -1
    }
    return this.filteredArticleList.findIndex(article => article.id === this.selectedArticleId)
  }

  getCurrentArticleList(): RSSArticle[] {
    return this.filteredArticleList
  }
} 