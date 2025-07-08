import { RSSArticle, RSSDataService } from '../model/RSSModel'
import { ArticleDAO } from '../model/ArticleDAO'
import webview from '@ohos.web.webview'
import resourceManager from '@ohos.resourceManager'
import { ImageCacheService } from '../service/ImageCacheService'
import { common } from '@kit.AbilityKit'
import PreferencesUtil from '../utils/PreferencesUtil'
import { GlobalState } from '../model/GlobalState'
import fs from '@ohos.file.fs'

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
    } else {
      this.currentArticleId = ''
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
        this.reloadWebContent()
      }
    } else {
      this.currentArticleId = ''
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
      // 将已缓存图片替换为受信任 ability:// URI
      const dataUrl = 'data:text/html;charset=utf-8,' + encodeURIComponent(baseHtml)
      this.webController.loadUrl(dataUrl)
      
      this.prefetchImages(baseHtml)
      
    } catch (error) {
      console.error('RSSArticleDetail', '重新加载Web内容失败:', JSON.stringify(error))
      this.isLoadingArticle = false
    }
  }

  /**
   * 仅检查 <img> 是否已有本地缓存并输出日志；
   * 如未命中且用户开启缓存，则后台下载（不阻塞）。
   */
  private async checkImagesCache(html: string, articleId: string): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext
      if (!context) {
        return
      }

      let imageCacheEnabled: boolean = false
      try {
        imageCacheEnabled = await PreferencesUtil.getImageCacheEnabled()
      } catch (_) {
        imageCacheEnabled = false
      }

      const imgRegex = /<img[^>]+src=["']([^"']+)["'][^>]*>/gi
      let match: RegExpExecArray | null

      while ((match = imgRegex.exec(html)) !== null) {
        const url = match[1]
        if (url.startsWith('data:')) {
          continue
        }

        try {
          const cachedPath = await ImageCacheService.getCachedPath(url, articleId, context)
          if (cachedPath) {
            // console.info('ImageCacheService', `✅ 已使用缓存文件 - URL: ${url}`)
          } else if (imageCacheEnabled) {
            // 后台下载，不阻塞页面加载
            ImageCacheService.downloadAndCache(url, articleId, context).catch(() => {})
          }
        } catch {
          // 忽略单个图片错误
        }
      }
    } catch (_) {
      // 忽略错误，避免影响页面加载
    }
  }

  /**
   * 将已缓存图片替换为 data:image/...;base64,xxxx
   */
  private async replaceImagesWithBase64Cached(html: string, articleId: string): Promise<string> {
    try {
      const context = getContext(this) as common.UIAbilityContext
      if (!context) {
        return html
      }

      let imageCacheEnabled: boolean = false
      try {
        imageCacheEnabled = await PreferencesUtil.getImageCacheEnabled()
      } catch (_) {
        imageCacheEnabled = false
      }

      const imgRegex = /<img[^>]+src=["']([^"']+)["'][^>]*>/gi
      let resultHtml = html
      let match: RegExpExecArray | null

      const asyncTasks: Promise<void>[] = []

      while ((match = imgRegex.exec(html)) !== null) {
        const url = match[1]
        if (url.startsWith('data:')) {
          continue
        }

        try {
          const cachedPath = await ImageCacheService.getCachedPath(url, articleId, context)
          if (cachedPath) {
            const base64 = await this.readFileToBase64(cachedPath)
            if (base64) {
              const mime = this.detectMimeFromExtension(url)
              const dataUri = `data:${mime};base64,${base64}`
              resultHtml = resultHtml.replace(url, dataUri)
              // console.info('ImageCacheService', `🖼️ 使用 Base64 缓存 - URL: ${url}`)
            }
          } else if (imageCacheEnabled) {
            asyncTasks.push((async () => { await ImageCacheService.downloadAndCache(url, articleId, context); })())
          }
        } catch {
          // 忽略单个图片错误
        }
      }

      if (asyncTasks.length > 0) {
        Promise.all(asyncTasks).then(() => {})
      }

      return resultHtml
    } catch {
      return html
    }
  }

  /** 把文件读取为 Base64 字符串 */
  private async readFileToBase64(filePath: string): Promise<string | null> {
    try {
      const file = await fs.open(filePath, fs.OpenMode.READ_ONLY)
      const stat = await fs.stat(filePath)
      const buffer = new ArrayBuffer(stat.size)
      await fs.read(file.fd, buffer)
      await fs.close(file.fd)
      return this.arrayBufferToBase64(buffer)
    } catch {
      return null
    }
  }

  private arrayBufferToBase64(buffer: ArrayBuffer): string {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/='
    const bytes = new Uint8Array(buffer)
    let result = ''
    let i = 0
    for (; i + 2 < bytes.length; i += 3) {
      const triple = (bytes[i] << 16) | (bytes[i + 1] << 8) | bytes[i + 2]
      result += chars.charAt((triple >> 18) & 0x3f)
      result += chars.charAt((triple >> 12) & 0x3f)
      result += chars.charAt((triple >> 6) & 0x3f)
      result += chars.charAt(triple & 0x3f)
    }
    if (i < bytes.length) {
      const byte1 = bytes[i]
      const byte2 = i + 1 < bytes.length ? bytes[i + 1] : 0
      const pad = i + 1 < bytes.length ? 1 : 2
      const triple = (byte1 << 16) | (byte2 << 8)
      result += chars.charAt((triple >> 18) & 0x3f)
      result += chars.charAt((triple >> 12) & 0x3f)
      result += pad === 2 ? '=' : chars.charAt((triple >> 6) & 0x3f)
      result += '='
    }
    return result
  }

  private detectMimeFromExtension(url: string): string {
    const lower = url.toLowerCase()
    if (lower.endsWith('.png')) return 'image/png'
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg'
    if (lower.endsWith('.gif')) return 'image/gif'
    if (lower.endsWith('.webp')) return 'image/webp'
    if (lower.endsWith('.bmp')) return 'image/bmp'
    return 'image/*'
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
    <div class="meta">${article.publishDate} | ${article.author || '未知作者'}</div>
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

      const nextArticleImages: string[] = []
      try {
        const fullArticle = await ArticleDAO.getArticleByID(nextArticle.id)
        
        if (fullArticle && (fullArticle.contentText || fullArticle.summary)) {
          const nextArticleContent = fullArticle.contentText || fullArticle.summary || ''
          const imgRegex = /<img[^>]+src=["']([^"']+)["']/gi
          let match: RegExpExecArray | null

          while ((match = imgRegex.exec(nextArticleContent)) !== null) {
            const url = match[1]
            if (url.startsWith('data:')) {
              continue
            }
            nextArticleImages.push(url)
          }
        }
      } catch (error) {
        return
      }

      if (nextArticleImages.length === 0) {
        return
      }

      setTimeout(async () => {
        for (const url of nextArticleImages) {
          try {
            await ImageCacheService.downloadAndCache(url, nextArticle.id, context)
          } catch (e) {
            // 下一篇文章图片预缓存失败
          }
        }
      }, 500)

    } catch (error) {
      // 预缓存下一篇文章图片失败
    }
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
            .opacity(GlobalState.canGoPrevious() ? 1.0 : 0.3)
            .onClick(() => {
              GlobalState.switchToPreviousArticle()
            })
          
          Image($r("app.media.down"))
            .width(20)
            .height(20)
            .margin({ right: 12 })
            .opacity(GlobalState.canGoNext() ? 1.0 : 0.3)
            .onClick(() => {
              GlobalState.switchToNextArticle()
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