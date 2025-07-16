import { RSSArticle, RSSDataService } from '../model/RSSModel'
import { ArticleDAO } from '../model/ArticleDAO'
import { FeedDAO } from '../model/FeedDAO'
import webview from '@ohos.web.webview'
import resourceManager from '@ohos.resourceManager'
import { ImageCacheService } from '../service/ImageCacheService'
import { common } from '@kit.AbilityKit'
import PreferencesUtil from '../utils/PreferencesUtil'
import { ImageDAO } from '../model/ImageDAO'
import { UrlHashUtil } from '../utils/UrlHashUtil'
import { GlobalState } from '../model/GlobalState'
import fs from '@ohos.file.fs'
import fileUri from '@ohos.file.fileuri'

// 仅声明包含 createUri 的接口，用于类型断言，避免直接依赖 common.UIAbilityContext
interface UIAbilityContextWithUri {
  createUri?: (path: string, flag?: number) => string
}

// 运行时检测 createUri 方法，避免类型声明冲突
interface ErrorCodeEvent {
  errorCode?: number
}

interface ExtendedWebErrorEvent extends ErrorCodeEvent {
  description?: string
  url?: string
  isForMainFrame?: boolean
}

interface ErrorDetails {
  code?: number
  description?: string
  url?: string
  isMain?: boolean
}

// 图片缓存预取数据结构
interface ArticleImage {
  url: string
  imageID: string
}

declare function getContext(component?: ESObject): common.UIAbilityContext

@Component
export default struct RSSArticleDetail {
  @Prop @Watch('onSelectedArticleChanged') selectedArticle: RSSArticle | undefined = undefined
  @State private webController: webview.WebviewController = new webview.WebviewController()
  @State private currentArticleId: string = ''
  @Link refreshTrigger: number
  @State private isWebViewReady: boolean = false
  @State private isLoadingArticle: boolean = false
  @State private showHelp: boolean = false

  @Prop canGoPrevious: boolean = false
  @Prop canGoNext: boolean = false

  @State private loadRetryCount: number = 0
  private readonly maxLoadRetries: number = 5
  private readonly retryDelayMs: number = 2000

  @State private pendingArticle: RSSArticle | undefined = undefined
  @State private feedTitle: string = ''

  @StorageLink('selectedArticleId') selectedArticleId: string = ''
  @StorageLink('currentArticleIndex') @Watch('onGlobalIndexChanged') currentIndex: number = -1
  @StorageLink('articleListTotal') totalArticles: number = 0
  @StorageLink('keyboardNavigationEnabled') keyboardEnabled: boolean = true
  @StorageLink('refreshTrigger') @Watch('onGlobalRefreshTriggered') globalRefreshTrigger: number = 0
  @StorageLink('showKeyboardHints') showKeyboardHints: boolean = true

  aboutToAppear() {
    this.initializeArticle()
    setTimeout(() => {
      // 可以在这里请求焦点，但通常点击组件区域后就会获得焦点
    }, 100)
  }

  onPageShow() {
    this.initializeArticle()
  }

  onGlobalIndexChanged() {
    // 这里可以通知父组件更新选中文章
    // 具体实现取决于与父组件的通信方式
  }

  onGlobalRefreshTriggered() {
    // 触发本地刷新，保持与原有机制的兼容性
    this.refreshTrigger++
  }

  onSelectedArticleChanged() {
    if (this.selectedArticle) {
      this.currentArticleId = this.selectedArticle.id
      this.loadFeedTitle()
    } else {
      this.currentArticleId = ''
      this.feedTitle = ''
    }

    if (!this.isWebViewReady) {
      this.pendingArticle = this.selectedArticle
    } else if (this.selectedArticle) {
      this.reloadWebContent()
    }
  }

  private initializeArticle() {
    if (this.selectedArticle != undefined) {
      if (this.selectedArticle.id !== this.currentArticleId) {
        this.currentArticleId = this.selectedArticle.id
        this.loadFeedTitle()
        this.reloadWebContent()
      }
    } else {
      this.currentArticleId = ''
      this.feedTitle = ''
    }
  }

  private async loadFeedTitle() {
    if (!this.selectedArticle) {
      this.feedTitle = ''
      return
    }

    try {
      // 先检查是否为特殊选项（今天、收藏、全部未读）
      const feedId = this.selectedArticle.feedId
      if (feedId === 'today' || feedId === 'favorites' || feedId === 'unread') {
        this.feedTitle = ''
        return
      }

      // 直接从数据库查询单个FEED
      const feedIdNum = parseInt(feedId)
      if (isNaN(feedIdNum)) {
        this.feedTitle = ''
        return
      }

      const dbFeed = await FeedDAO.getFeedById(feedIdNum)
      if (dbFeed) {
        this.feedTitle = dbFeed.title || ''
      } else {
        this.feedTitle = ''
      }
    } catch (error) {
      console.error('RSSArticleDetail', '加载FEED标题失败:', error)
      this.feedTitle = ''
    }
  }

  private async reloadWebContent() {
    if (!this.selectedArticle) {
      return
    }
    if (!this.isWebViewReady) {
      this.pendingArticle = this.selectedArticle
      return
    }
    try {
      this.isLoadingArticle = true
      // 最多显示加载蒙版 3 秒，超时自动隐藏
      setTimeout(() => {
        if (this.isLoadingArticle) {
          this.isLoadingArticle = false
        }
      }, 3000)
      this.showHelp = false
      
      const baseHtml = this.generateOptimizedArticleHTML(this.selectedArticle)

      // 替换已缓存图片为 content URI
      const finalHtml = await this.replaceCachedImages(baseHtml)

      const dataUrl = 'data:text/html;charset=utf-8,' + encodeURIComponent(finalHtml)
      this.webController.loadUrl(dataUrl)
      
      this.prefetchImages(baseHtml)
      
    } catch (error) {
      console.error('RSSArticleDetail', '重新加载Web内容失败:', JSON.stringify(error))
      this.isLoadingArticle = false
    }
  }


  private handleKeyboardEvent(event: KeyEvent): boolean {
    if (!this.keyboardEnabled || !this.selectedArticle) {
      return false
    }

    if (event.type === KeyType.Down) {
      if (event.keyCode === 2063) { // M键
        this.toggleReadStatus()
        return true
      }
      
      if (event.keyCode === 2067) { // S键
        this.toggleStar()
        return true
      }
      
      if (event.keyCode === 2049 || event.keyCode === 2022) { // J键或右箭头
        GlobalState.switchToNextArticle()
        return true
      }
      
      if (event.keyCode === 2048 || event.keyCode === 2021) { // K键或左箭头
        GlobalState.switchToPreviousArticle()
        return true
      }
    }
    
    return false
  }

  private async toggleReadStatus() {
    if (!this.selectedArticle) return
    
    try {
      const success = await GlobalState.updateArticleReadStatus(this.selectedArticle.id, !this.selectedArticle.readStatus)
      
      if (success) {
        this.selectedArticle.readStatus = !this.selectedArticle.readStatus
        this.refreshTrigger++
      }
    } catch (error) {
      console.error('RSSArticleDetail', '切换已读状态失败:', error)
    }
  }

  private async toggleStar() {
    if (!this.selectedArticle) return
    
    try {
      const success = await GlobalState.updateArticleStarStatus(this.selectedArticle.id, this.selectedArticle.starredStatus)
      
      if (success) {
        this.selectedArticle.starredStatus = !this.selectedArticle.starredStatus
        this.refreshTrigger++
      }
    } catch (error) {
      console.error('RSSArticleDetail', '切换收藏状态失败:', error)
    }
  }

  private generateOptimizedArticleHTML(article: RSSArticle): string {
    const feedInfo = this.feedTitle ? ` | ${this.feedTitle}` : ''
    return `<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body { font-family: system-ui; margin: 16px; line-height: 1.6; color: #333; }
        h1 { font-size: 24px; margin: 0 0 16px 0; }
        .meta { color: #666; font-size: 14px; margin-bottom: 16px; }
        .content { font-size: 16px; }
        img { max-width: 100%; height: auto; margin: 8px 0; }
        a { color: #007AFF; }
        pre { background: #f5f5f5; padding: 12px; border-radius: 4px; overflow-x: auto; }
    </style>
</head>
<body>
    <h1>${article.title}</h1>
    <div class="meta">${article.publishDate} | ${article.author || '未知作者'}${feedInfo}</div>
    <div class="content">${article.content || article.summary || '无内容'}</div>
</body>
</html>`
  }

  private async prefetchImages(htmlContent: string) {
    try {
      // 仅当用户开启“图片缓存”功能时才主动下载下一篇文章的图片
      let imageCacheEnabled: boolean = false
      try {
        imageCacheEnabled = await PreferencesUtil.getImageCacheEnabled()
      } catch (_) {
        imageCacheEnabled = false
      }
      if (!imageCacheEnabled) {
        return
      }

      const context = getContext(this) as common.UIAbilityContext
      if (!context) {
        return
      }

      const nextArticle = GlobalState.getNextArticle()
      if (!nextArticle) {
        return
      }

      let nextArticleImages: ArticleImage[] = []
      try {
        const imgs = await ImageDAO.getImagesByArticleID(nextArticle.id)
        nextArticleImages = imgs
          .filter(img => !img.localPath)
          .map((img): ArticleImage => ({ url: img.url, imageID: img.imageID }))
      } catch (_) {}

      if (nextArticleImages.length === 0) {
        return
      }

      setTimeout(async () => {
        for (const img of nextArticleImages) {
          try {
            await ImageCacheService.ensureImageCached(img.url, nextArticle.id, context, false)
          } catch (_) {
            /* ignore */
          }
        }
      }, 500)

    } catch (error) {
      // 预缓存下一篇文章图片失败
    }
  }

  /**
   * 将HTML中的远程图片URL替换为已缓存的本地content URI
   */
  private async replaceCachedImages(html: string): Promise<string> {
    if (!this.selectedArticle) {
      return html
    }

    let newHtml: string = html

    try {
      const imgRecords = await ImageDAO.getImagesByArticleID(this.selectedArticle.id)
      for (const record of imgRecords) {
        if (!record.localPath) {
          continue
        }

        // 确认文件存在
        try {
          const stat = await fs.stat(record.localPath)
          if (!stat.isFile()) {
            continue
          }
        } catch (_) {
          continue
        }

        // 使用 AbilityContext.createUri 生成 content:// URI，避免 WebView 拒绝加载 file:// 资源
        let contentUri: string | undefined = undefined
        try {
          const ctx = getContext(this) as UIAbilityContextWithUri
          console.error('contentUri', 'contentUri:', record.localPath)
          if (!ctx || !ctx.createUri) {
            continue
          }
          contentUri = ctx.createUri(record.localPath, 0)
        } catch (_) {
          // 生成失败，跳过替换
          continue
        }

        // 使用 split-join 替换，避免正则转义复杂性
        if (contentUri) {
          newHtml = newHtml.split(record.url).join(contentUri)
        }
      }
    } catch (_) {
      // 忽略替换错误，返回原HTML
    }

    return newHtml
  }

  private openOriginalArticle() {
    if (!this.selectedArticle || !this.selectedArticle.link) {
      return
    }
    
    try {
      const url = this.selectedArticle.link
      this.webController.loadUrl(url)
      
      setTimeout(() => {
        if (this.selectedArticle) {
          this.reloadWebContent()
        }
      }, 10000)
      
    } catch (error) {
      console.error('RSSArticleDetail', '打开原文失败:', error)
    }
  }

  private async openHelpDocument() {
    try {
      if (!this.isWebViewReady) {
        setTimeout(() => {
          if (this.isWebViewReady) {
            this.openHelpDocument()
          }
        }, 1000)
        return
      }
      
      this.showHelp = true
      const helpUrl = 'resource://rawfile/docs/about/index.html'
      this.webController.loadUrl(helpUrl)
      this.currentArticleId = 'help_document'
      
    } catch (error) {
      console.error('RSSArticleDetail', '打开帮助文档失败:', error)
    }
  }

  // generateFallbackHTML 方法已移除，简化 HTML 回退功能取消。

  build() {
    Column() {
      Row() {
        Blank()
        
        Row() {
          Image($r("app.media.up"))
            .width(20)
            .height(20)
            .margin({ right: 12 })
            .opacity(this.canGoPrevious ? 1.0 : 0.3)
            .onClick(() => {
              if (this.canGoPrevious) {
                GlobalState.switchToPreviousArticle()
              }
            })
          
          Image($r("app.media.down"))
            .width(20)
            .height(20)
            .margin({ right: 12 })
            .opacity(this.canGoNext ? 1.0 : 0.3)
            .onClick(() => {
              if (this.canGoNext) {
                GlobalState.switchToNextArticle()
              }
            })
          
          Image(this.selectedArticle?.readStatus ? $r("app.media.read") : $r("app.media.unread"))
            .width(20)
            .height(20)
            .margin({ right: 12 })
            .opacity(this.selectedArticle ? 1.0 : 0.3)
            .onClick(() => {
              if (this.selectedArticle) {
                this.toggleReadStatus()
              }
            })
          
          Image(this.selectedArticle?.starredStatus ? $r("app.media.star") : $r("app.media.unstar"))
            .width(20)
            .height(20)
            .margin({ right: 12 })
            .opacity(this.selectedArticle ? 1.0 : 0.3)
            .onClick(() => {
              if (this.selectedArticle) {
                this.toggleStar()
              }
            })
          
          Image($r("app.media.internet"))
            .width(20)
            .height(20)
            .margin({ right: 12 })
            .opacity(this.selectedArticle ? 1.0 : 0.3)
            .onClick(() => {
              if (this.selectedArticle) {
                this.openOriginalArticle()
              }
            })
          
          Image($r("app.media.information"))
            .width(20)
            .height(20)
            .opacity(1.0)
            .onClick(() => {
              this.openHelpDocument()
            })
        }
      }
      .width("100%")
      .height(50)
      .padding({ left: 16, right: 16 })
      .backgroundColor("#f7f7f7")
      .border({ width: { bottom: 1 }, color: "#e0e0e0" })

      Stack() {
        Web({ 
          src: '',
          controller: this.webController 
        })
        .focusable(false)
        .width("100%")
        .height("100%")
        .backgroundColor('#ffffff')
        .onControllerAttached(() => {
          this.isWebViewReady = true
          const articleToLoad = this.pendingArticle ?? this.selectedArticle
          this.pendingArticle = undefined
          if (articleToLoad) {
            this.selectedArticle = articleToLoad
            this.reloadWebContent()
          }
        })
        .onPageEnd(() => {
          this.isLoadingArticle = false
          // 不在 onPageEnd 重置 loadRetryCount，避免主框架加载错误导致无限重试循环
          if (this.currentArticleId === 'help_document') {
            return
          }
          if (this.selectedArticle && this.currentArticleId !== this.selectedArticle.id) {
            this.reloadWebContent()
          }
          if (this.selectedArticle) {
            this.currentArticleId = this.selectedArticle.id
          }
        })
        .onErrorReceive((event: ESObject) => {
          const extEvent = event as ExtendedWebErrorEvent
          // 仅当确认是主框架失败 (isForMainFrame === true) 且 errorCode != -1 时才重试；
          // 否则认为是子资源或非致命错误，忽略以避免重复刷新。
          if (extEvent.isForMainFrame !== true) {
            return
          }
          const errorDetails: ErrorDetails = {
            code: extEvent.errorCode,
            description: extEvent.description,
            url: extEvent.url,
            isMain: extEvent.isForMainFrame
          }
          
          this.isLoadingArticle = false
          
          const errorCode = extEvent.errorCode ?? -1
          
          if (errorCode === -3 || errorCode === -1) {
            return
          }
          
          console.error('RSSArticleDetail', `文章内容加载失败: 错误码=${errorCode}, 描述=${extEvent.description || 'N/A'}, URL=${extEvent.url || 'N/A'}, 主框架=${extEvent.isForMainFrame}`)
          
          // 不再自动重试，也不降级简化 HTML，仅记录错误。
          return
        })

        if (this.selectedArticle && this.isLoadingArticle) {
          Column() {
            LoadingProgress()
              .width(40)
              .height(40)
              .color('#007AFF')
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor('rgba(255, 255, 255, 0.8)')
        }

        if (!this.selectedArticle && !this.showHelp) {
          Column() {
            Image($r("app.media.rss"))
              .width(60)
              .height(60)
              .opacity(0.3)
              .margin({ bottom: 12 })
            
            Text('选择一篇文章查看详情')
              .fontSize(16)
              .fontColor('#999999')
              
            Text('或点击上方帮助按钮查看使用说明')
              .fontSize(12)
              .fontColor('#bbb')
              .margin({ top: 4 })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        }
      }
      .layoutWeight(1)
    }
    .width("100%")
    .height("100%")
    .backgroundColor("#f5f5f5")
    .focusable(true)
    .onKeyEvent((event: KeyEvent): boolean => {
      return this.handleKeyboardEvent(event)
    })
  }
} 