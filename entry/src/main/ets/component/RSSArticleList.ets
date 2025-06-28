import { RSSArticle, RSSFeed, mockRSSArticles, RSSDataService } from '../model/RSSModel'
import { DatabaseManager } from '../model/DatabaseManager'

@Component
export default struct RSSArticleList {
  @Prop @Watch('onSelectedFeedChanged') selectedFeed: RSSFeed | undefined = undefined
  @State articleList: RSSArticle[] = []
  @State selectedArticleId: string = ''
  @State showUnreadOnly: boolean = false // 是否只显示未读文章
  @State filteredArticleList: RSSArticle[] = [] // 过滤后的文章列表

  // 点击文章的回调
  onArticleClick?: (article: RSSArticle) => void
  // 折叠第一栏的回调
  onToggleFirstColumn?: () => void
  // 文章已读状态改变的回调
  onArticleReadStatusChanged?: () => void
  // 组件引用回调
  onRef?: (ref: RSSArticleList) => void
  // 第一栏是否已折叠
  @Prop isFirstColumnCollapsed: boolean = false

  aboutToAppear() {
    this.initializeArticleList()
    // 设置组件引用
    if (this.onRef) {
      this.onRef(this)
    }
  }

  onPageShow() {
    this.initializeArticleList()
  }

  // 当selectedFeed变化时触发（恢复Watch机制）
  onSelectedFeedChanged() {
    this.selectedArticleId = '' // 重置选中的文章
    this.initializeArticleList()
  }

  // 初始化文章列表
  private initializeArticleList() {
    if (this.selectedFeed != undefined) {
    this.loadArticles()
    } else {
      this.articleList = []
      this.filteredArticleList = []
    }
  }

  // 监听articleList变化，更新过滤后的列表
  onArticleListChange() {
    this.updateFilteredList()
  }

  // 监听showUnreadOnly变化，更新过滤后的列表
  onShowUnreadOnlyChange() {
    this.updateFilteredList()
  }

  // 更新过滤后的文章列表
  updateFilteredList() {
    if (this.showUnreadOnly) {
      this.filteredArticleList = this.articleList.filter(article => !article.readStatus)
    } else {
      this.filteredArticleList = [...this.articleList]
    }
  }

  // 当选中的订阅源改变时重新加载文章
  public async loadArticles() {
    if (this.selectedFeed) {
      try {
        
        let articles: RSSArticle[] = []
        
        // 判断是否为特殊选项
        if (this.isSpecialOption(this.selectedFeed.id)) {
          articles = await this.loadSpecialOptionArticles(this.selectedFeed.id)
        } else {
          // 普通RSS源
          articles = await RSSDataService.getArticlesByFeedId(this.selectedFeed.id)
          if (articles.length === 0) {
            articles = mockRSSArticles.filter(article => article.feedId === this.selectedFeed?.id)
          }
        }
        
        
        this.articleList = articles
        this.updateFilteredList()
        
        // 强制触发UI更新
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

  // 判断是否为特殊选项
  private isSpecialOption(feedId: string): boolean {
    return ['today', 'favorites', 'unread'].includes(feedId)
  }

  // 加载特殊选项的文章
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

  /**
   * 移除HTML标签，保留纯文本
   */
  private stripHtmlTags(html: string): string {
    if (!html) {
      return ''
    }
    // 移除所有HTML标签
    return html.replace(/<[^>]*>/g, '')
      .replace(/&nbsp;/g, ' ')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&amp;/g, '&')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'")
      .trim()
  }

  // 获取未读文章数量
  getUnreadCount(): number {
    return this.articleList.filter(article => !article.readStatus).length
  }

  // 移除了getSubtitleText方法，因为不再需要显示副标题

  // 标记全部已读
  async markAllAsRead() {
    if (!this.selectedFeed) {
      return
    }

    try {
      
      // 如果是特殊选项，需要逐个标记文章
      if (this.isSpecialOption(this.selectedFeed.id)) {
        // 逐个标记当前显示的文章为已读
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
        // 普通RSS源，调用批量标记已读API
      const updatedCount = await RSSDataService.markAllAsReadByFeedId(this.selectedFeed.id)
      
      // 更新本地状态
      this.articleList.forEach(article => {
        article.readStatus = true
      })
      }
      
      this.articleList = [...this.articleList] // 触发重新渲染
      this.updateFilteredList()
      
      // 通知父组件更新RSS源的未读数量
      if (this.onArticleReadStatusChanged) {
        this.onArticleReadStatusChanged()
      }
      
    } catch (error) {
      console.error('RSSArticleList', '批量标记已读失败:', JSON.stringify(error))
    }
  }

  // 切换筛选状态
  toggleUnreadFilter() {
    this.showUnreadOnly = !this.showUnreadOnly
    this.updateFilteredList()
  }

  // 切换文章已读状态
  async toggleArticleReadStatus(article: RSSArticle) {
    try {
      const newReadStatus = !article.readStatus
      
      // 立即更新本地状态
      article.readStatus = newReadStatus
      this.articleList = [...this.articleList]
      this.updateFilteredList()
      
      // 异步保存到数据库
      const success = await RSSDataService.markArticleAsRead(article.id, newReadStatus)
      
      if (success) {
        // 通知父组件更新RSS源的未读数量
        if (this.onArticleReadStatusChanged) {
          await this.onArticleReadStatusChanged()
        }
      } else {
        // 如果数据库更新失败，回滚本地状态
        article.readStatus = !newReadStatus
        this.articleList = [...this.articleList]
        this.updateFilteredList()
      }
    } catch (error) {
      console.error('RSSArticleList', '切换文章已读状态失败:', JSON.stringify(error))
      // 回滚本地状态
      article.readStatus = !article.readStatus
      this.articleList = [...this.articleList]
      this.updateFilteredList()
    }
  }

  // 切换文章收藏状态
  async toggleArticleStarStatus(article: RSSArticle) {
    try {
      const newStarredStatus = !article.starredStatus
      
      // 立即更新本地状态
      article.starredStatus = newStarredStatus
      this.articleList = [...this.articleList]
      this.updateFilteredList()
      
      // 异步保存到数据库
      const success = await RSSDataService.toggleArticleStar(article.id, !newStarredStatus)
      
      if (success) {
        // 如果需要更新未读计数（例如收藏列表）
        if (this.onArticleReadStatusChanged) {
          await this.onArticleReadStatusChanged()
        }
      } else {
        // 如果数据库更新失败，回滚本地状态
        article.starredStatus = !newStarredStatus
        this.articleList = [...this.articleList]
        this.updateFilteredList()
      }
    } catch (error) {
      console.error('RSSArticleList', '切换文章收藏状态失败:', JSON.stringify(error))
      // 回滚本地状态
      article.starredStatus = !article.starredStatus
      this.articleList = [...this.articleList]
      this.updateFilteredList()
    }
  }

  // 创建文章右键菜单
  @Builder
  createArticleContextMenu(article: RSSArticle) {
    Menu() {
      // 已读/未读切换
      MenuItem({
        content: article.readStatus ? "标记为未读" : "标记为已读"
      })
        .onClick(() => {
          this.toggleArticleReadStatus(article)
        })

      // 收藏/取消收藏切换
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
        // 标题栏
        Row() {
          // 折叠/展开按钮
          Image(this.isFirstColumnCollapsed ? $r("app.media.show") : $r("app.media.hide"))
            .width(20)
            .height(20)
            .margin({ right: 12 })
            .onClick(() => {
              if (this.onToggleFirstColumn) {
                this.onToggleFirstColumn()
              }
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
          
          // 操作按钮组
          Row() {
            // 筛选未读按钮
            Image(this.showUnreadOnly ? $r("app.media.filter_selected") : $r("app.media.filter_unselected"))
              .width(20)
              .height(20)
              .fillColor('#666666')

              .onClick(() => {
                this.toggleUnreadFilter()
              })
              .margin({ right: 8 })

            // 标记全部已读按钮
            Image($r("app.media.mark_all"))
              .width(20)
              .height(20)
              .fillColor(this.getUnreadCount() > 0 ? "#666666" : "#cccccc")
              .enabled(this.getUnreadCount() > 0) // 只有存在未读文章时才启用
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

        // 文章列表
        List() {
          ForEach(this.filteredArticleList, (article: RSSArticle, index: number) => {
            ListItem() {
              this.ArticleItemView(article)
            }
            .bindContextMenu(this.createArticleContextMenu(article), ResponseType.RightClick)
            .onClick(async () => {
              
              this.selectedArticleId = article.id
              
              // 如果文章未读，标记为已读
              const wasUnread = !article.readStatus
              
              if (wasUnread) {
                
                // 立即更新本地状态以提供即时反馈
                article.readStatus = true
                // 强制刷新列表显示
                this.articleList = [...this.articleList]
                this.updateFilteredList()
                
                // 异步保存到数据库
                try {
                  
                  const success = await RSSDataService.markArticleAsRead(article.id)
                  
                  if (success) {
                    
                    // 验证数据库中的状态是否真的更新了
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
                    
                    // 确保数据库操作完全提交后再通知父组件
                    // 添加短暂延迟确保数据库事务提交
                    await new Promise<void>(resolve => setTimeout(resolve, 100))
                    
                    // 通知父组件更新RSS源的未读数量
                    if (this.onArticleReadStatusChanged) {
                      await this.onArticleReadStatusChanged()
                    } else {
                      console.error('RSSArticleList', 'onArticleReadStatusChanged回调为空')
                    }
                  } else {
                    // 如果数据库更新失败，回滚本地状态
                    console.error('RSSArticleList', '数据库标记已读失败，回滚本地状态')
                    article.readStatus = false
                    this.articleList = [...this.articleList]
                    this.updateFilteredList()
                  }
                } catch (error) {
                  console.error('RSSArticleList', '标记文章已读失败:', JSON.stringify(error))
                  // 回滚本地状态
                  article.readStatus = false
                  this.articleList = [...this.articleList]
                  this.updateFilteredList()
                }
              }
              
              // 总是调用父组件的点击回调，用于显示文章详情
              if (this.onArticleClick) {
                this.onArticleClick(article)
              }
            })
          })
        }
        .width("100%")
        .layoutWeight(1)
        .backgroundColor("#ffffff")
        .divider({ strokeWidth: 0.5, color: '#f0f0f0', startMargin: 16, endMargin: 0 })
      } else {
        // 空状态 - 显示折叠按钮
        Column() {
          // 空状态时的标题栏（只有折叠按钮）
          Row() {
            // 折叠/展开按钮
            Image(this.isFirstColumnCollapsed ? $r("app.media.show") : $r("app.media.hide"))
              .width(20)
              .height(20)
              .margin({ right: 12 })

              .onClick(() => {
                if (this.onToggleFirstColumn) {
                  this.onToggleFirstColumn()
                }
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

          // 空状态内容
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
        // 文章标题
        Text(article.title)
          .fontSize(16)
          .fontWeight(article.readStatus ? FontWeight.Normal : FontWeight.Medium)
          .fontColor(article.readStatus ? "#666666" : "#000000")
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width("100%")
          .textAlign(TextAlign.Start)
          .lineHeight(22)
        
        // 文章摘要
        Text(this.stripHtmlTags(article.summary).substring(0, 50))
          .fontSize(14)
          .fontColor(article.readStatus ? "#999999" : "#888888")
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width("100%")
          .textAlign(TextAlign.Start)
          .margin({ top: 6 })
          .lineHeight(20)
        
        // 文章信息（发布日期和状态标识）
        Row() {
          Text(article.publishDate)
            .fontSize(12)
            .fontColor(article.readStatus ? "#aaaaaa" : "#999999")
            
          Blank()
          
          // 收藏标识
          if (article.starredStatus) {
            Image($r("app.media.star"))
              .width(12)
              .height(12)
              .fillColor("#ffb300")
              .margin({ right: 6 })
          }
          
          // 未读标识
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

  /**
   * 获取当前选中文章在列表中的索引
   */
  getCurrentArticleIndex(): number {
    if (!this.selectedArticleId) {
      return -1
    }
    return this.filteredArticleList.findIndex(article => article.id === this.selectedArticleId)
  }

  /**
   * 获取当前的文章列表
   */
  getCurrentArticleList(): RSSArticle[] {
    return this.filteredArticleList
  }

  /**
   * 设置选中的文章
   */
  async setSelectedArticle(articleId: string): Promise<RSSArticle | undefined> {
    this.selectedArticleId = articleId
    const article = this.filteredArticleList.find(article => article.id === articleId)
    
    if (article) {
      // 如果文章未读，标记为已读（与点击文章列表项的逻辑一致）
      const wasUnread = !article.readStatus
      
      if (wasUnread) {
        // 立即更新本地状态以提供即时反馈
        article.readStatus = true
        // 强制刷新列表显示
        this.articleList = [...this.articleList]
        this.updateFilteredList()
        
        // 异步保存到数据库
        try {
          const success = await RSSDataService.markArticleAsRead(article.id)
          
          if (success) {
            // 确保数据库操作完全提交后再通知父组件
            await new Promise<void>(resolve => setTimeout(resolve, 100))
            
            // 通知父组件更新RSS源的未读数量
            if (this.onArticleReadStatusChanged) {
              await this.onArticleReadStatusChanged()
            }
          } else {
            // 如果数据库更新失败，回滚本地状态
            console.error('RSSArticleList', '数据库标记已读失败，回滚本地状态')
            article.readStatus = false
            this.articleList = [...this.articleList]
            this.updateFilteredList()
          }
        } catch (error) {
          console.error('RSSArticleList', '标记文章已读失败:', JSON.stringify(error))
          // 回滚本地状态
          article.readStatus = false
          this.articleList = [...this.articleList]
          this.updateFilteredList()
        }
      }
      
      // 调用父组件的点击回调，用于显示文章详情
      if (this.onArticleClick) {
        this.onArticleClick(article)
      }
    }
    
    return article
  }

  /**
   * 根据索引设置选中的文章
   */
  async setSelectedArticleByIndex(index: number): Promise<RSSArticle | undefined> {
    if (index >= 0 && index < this.filteredArticleList.length) {
      const article = this.filteredArticleList[index]
      this.selectedArticleId = article.id
      
      // 如果文章未读，标记为已读（与点击文章列表项的逻辑一致）
      const wasUnread = !article.readStatus
      
      if (wasUnread) {
        // 立即更新本地状态以提供即时反馈
        article.readStatus = true
        // 强制刷新列表显示
        this.articleList = [...this.articleList]
        this.updateFilteredList()
        
        // 异步保存到数据库
        try {
          const success = await RSSDataService.markArticleAsRead(article.id)
          
          if (success) {
            // 确保数据库操作完全提交后再通知父组件
            await new Promise<void>(resolve => setTimeout(resolve, 100))
            
            // 通知父组件更新RSS源的未读数量
            if (this.onArticleReadStatusChanged) {
              await this.onArticleReadStatusChanged()
            }
          } else {
            // 如果数据库更新失败，回滚本地状态
            console.error('RSSArticleList', '数据库标记已读失败，回滚本地状态')
            article.readStatus = false
            this.articleList = [...this.articleList]
            this.updateFilteredList()
          }
        } catch (error) {
          console.error('RSSArticleList', '标记文章已读失败:', JSON.stringify(error))
          // 回滚本地状态
          article.readStatus = false
          this.articleList = [...this.articleList]
          this.updateFilteredList()
        }
      }
      
      // 调用父组件的点击回调，用于显示文章详情
      if (this.onArticleClick) {
        this.onArticleClick(article)
      }
      
      return article
    }
    return undefined
  }
} 