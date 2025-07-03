import { RSSArticle, RSSDataService } from '../model/RSSModel'
import webview from '@ohos.web.webview'
import resourceManager from '@ohos.resourceManager'
import { ImageCacheService } from '../service/ImageCacheService'
import { common } from '@kit.AbilityKit'
import PreferencesUtil from '../utils/PreferencesUtil'

// 兼容可能存在 destroy() 方法的 WebViewController
interface WebviewDestroyable {
  destroy?: () => void
}

// 用于类型断言以安全访问 errorCode 属性，避免使用内联对象类型
interface ErrorCodeEvent {
  errorCode?: number
}

// 扩展的 WebView 错误事件
interface ExtendedWebErrorEvent extends ErrorCodeEvent {
  description?: string
  url?: string
  isForMainFrame?: boolean
}

// 供日志使用的错误详情
interface ErrorDetails {
  code?: number
  description?: string
  url?: string
  isMain?: boolean
}

// 声明全局 getContext 函数
declare function getContext(component?: object): common.UIAbilityContext

@Component
export default struct RSSArticleDetail {
  @Prop @Watch('onSelectedArticleChanged') selectedArticle: RSSArticle | undefined = undefined
  @State private webController: webview.WebviewController = new webview.WebviewController()
  @State private currentArticleId: string = '' // 用于跟踪当前显示的文章ID
  @Link refreshTrigger: number // 用于通知父组件刷新文章列表
  @State private isWebViewReady: boolean = false // WebView是否已准备就绪
  @State private isLoadingArticle: boolean = false // 文章是否正在加载，用于显示占位层
  // 已移除 loadedArticleIds、memoryMonitor 以及定时回收相关属性

  // 新增：文章切换相关属性
  @Prop canGoPrevious: boolean = false // 是否可以切换到上一篇
  @Prop canGoNext: boolean = false // 是否可以切换到下一篇
  onPreviousArticle?: () => void // 切换到上一篇的回调
  onNextArticle?: () => void // 切换到下一篇的回调

  // 新增：加载失败重试控制
  @State private loadRetryCount: number = 0 // 当前重试次数
  private readonly maxLoadRetries: number = 5 // 最大重试次数
  private readonly retryDelayMs: number = 2000 // 首次重试延时 (ms)，后续按倍数递增

  // 待加载文章（仅在首次 WebView 未就绪时使用）
  @State private pendingArticle: RSSArticle | undefined = undefined

  /**
   * 组件即将出现时的生命周期
   */
  aboutToAppear() {
    this.initializeArticle()
  }

  onPageShow() {
    this.initializeArticle()
  }

  /**
   * 当selectedArticle变化时触发（恢复Watch机制）
   */
  onSelectedArticleChanged() {
    console.info('RSSArticleDetail', `onSelectedArticleChanged ==> 收到选中文章变化, id: ${this.selectedArticle?.id}`)

    // 直接加载/切换文章内容（不再销毁 WebView）

    // 更新当前文章ID
    if (this.selectedArticle) {
      this.currentArticleId = this.selectedArticle.id
      console.info('RSSArticleDetail', `onSelectedArticleChanged ==> 设置 currentArticleId: ${this.currentArticleId}`)
    } else {
      this.currentArticleId = ''
      console.info('RSSArticleDetail', 'onSelectedArticleChanged ==> 未选中文章')
    }

    // 如果 WebView 尚未 ready，缓存待加载文章；否则直接加载
    if (!this.isWebViewReady) {
      this.pendingArticle = this.selectedArticle
    } else if (this.selectedArticle) {
      this.reloadWebContent()
    }
  }

  /**
   * 初始化文章显示
   */
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

  /**
   * 重新加载Web内容
   */
  private reloadWebContent() {
    console.info('RSSArticleDetail', `reloadWebContent ==> 开始加载文章, id: ${this.selectedArticle?.id}, WebView ready: ${this.isWebViewReady}`)
    if (!this.selectedArticle) {
      return
    }
    // WebView 尚未 ready —— 先缓存
    if (!this.isWebViewReady) {
      this.pendingArticle = this.selectedArticle
      return
    }
    try {
      // 开始加载，显示占位层
      this.isLoadingArticle = true
      
      // 重置重试计数
      this.loadRetryCount = 0
      
      const htmlContent = this.generateOptimizedArticleHTML(this.selectedArticle)
      const dataUrl = 'data:text/html;charset=utf-8,' + encodeURIComponent(htmlContent)
      this.webController.loadUrl(dataUrl)
      
      // 异步预抓图片并在缓存完成后替换 src
      this.prefetchImages(htmlContent)
      
      console.info('RSSArticleDetail', '重新加载 Web 内容完成')
    } catch (error) {
      console.error('RSSArticleDetail', '重新加载Web内容失败:', JSON.stringify(error))
      // 若加载失败，立即隐藏加载层
      this.isLoadingArticle = false
    }
  }

  /**
   * 切换文章已读状态
   */
  private async toggleReadStatus() {
    if (!this.selectedArticle) return
    
    try {
      const newReadStatus = !this.selectedArticle.readStatus
      const success = await RSSDataService.markArticleAsRead(this.selectedArticle.id, newReadStatus)
      if (success) {
        const statusText = newReadStatus ? '已读' : '未读'
        console.info('RSSArticleDetail', `文章 ${this.selectedArticle.title} 已标记为${statusText}`)
        // 更新本地状态
        this.selectedArticle.readStatus = newReadStatus
        // 触发父组件刷新
        this.refreshTrigger++
      }
    } catch (error) {
      console.error('RSSArticleDetail', '切换已读状态失败:', error)
    }
  }

  /**
   * 切换收藏状态
   */
  private async toggleStar() {
    if (!this.selectedArticle) return
    
    try {
      const success = await RSSDataService.toggleArticleStar(
        this.selectedArticle.id, 
        this.selectedArticle.starredStatus
      )
      if (success) {
        const newStatus = !this.selectedArticle.starredStatus
        console.info('RSSArticleDetail', `文章 ${this.selectedArticle.title} 收藏状态变更为: ${newStatus}`)
        // 更新本地状态
        this.selectedArticle.starredStatus = newStatus
        // 触发父组件刷新
        this.refreshTrigger++
      }
    } catch (error) {
      console.error('RSSArticleDetail', '切换收藏状态失败:', error)
    }
  }

  /**
   * 生成优化的文章HTML内容（减少内存占用）
   */
  private generateOptimizedArticleHTML(article: RSSArticle): string {
    // 限制内容长度，避免过长的文章占用过多内存
    const maxContentLength = 10 * 1024 * 1024 // 10MB限制，适合几乎所有文章
    const content = article.content || article.summary || '暂无内容'
    const truncatedContent = content.length > maxContentLength
      ? `${content.substring(0, maxContentLength)}...<div style="padding:15px;background:#f0f8ff;border-left:4px solid #007AFF;margin:20px 0;border-radius:4px;"><p><strong>📄 内容过长已截断</strong></p><p style="margin:5px 0;color:#666;font-size:14px;">文章内容超过10MB，已自动截断以优化性能。</p><p style="margin:5px 0;"><a href="${this.escapeHtml(article.link)}" target="_blank" style="color:#007AFF;text-decoration:none;">👆 点击这里阅读完整原文</a></p></div>`
      : content
    
    return this.generateCompactHTML(article.title, article.author, article.publishDate, truncatedContent, article.link)
  }

  /**
   * 简单的 HTML 转义，避免特殊字符破坏属性字符串
   */
  private escapeHtml(text: string | undefined): string {
    if (!text) {
      return ''
    }
    return text
      .replace(/&/g, '&amp;')
      .replace(/"/g, '&quot;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/'/g, '&#39;')
  }

  /**
   * 生成紧凑的HTML模板（原版本，用于完整显示）
   */
  private generateArticleHTML(article: RSSArticle): string {
    const htmlTemplate = `
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${article.title}</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'PingFang SC', 'Hiragino Sans GB', 'Microsoft YaHei', sans-serif;
            line-height: 1.6;
            color: #333;
            margin: 0;
            padding: 20px;
            background-color: #ffffff;
        }
        .article-header {
            border-bottom: 1px solid #eee;
            padding-bottom: 20px;
            margin-bottom: 20px;
        }
        .article-title {
            font-size: 24px;
            font-weight: 600;
            color: #1a1a1a;
            margin: 0 0 15px 0;
            line-height: 1.3;
        }
        .article-meta {
            font-size: 14px;
            color: #666;
            display: flex;
            align-items: center;
            gap: 12px;
        }
        .article-meta .separator {
            color: #ccc;
        }
        .article-content {
            font-size: 16px;
            line-height: 1.8;
            color: #333;
        }
        .article-content img {
            max-width: 100%;
            height: auto;
            border-radius: 8px;
            margin: 15px 0;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }
        .article-content p {
            margin: 15px 0;
        }
        .article-content h1, .article-content h2, .article-content h3 {
            margin: 25px 0 15px 0;
            color: #1a1a1a;
        }
        .article-content h1 { font-size: 22px; }
        .article-content h2 { font-size: 20px; }
        .article-content h3 { font-size: 18px; }
        .article-content a {
            color: #007AFF;
            text-decoration: none;
        }
        .article-content a:hover {
            text-decoration: underline;
        }
        .article-content blockquote {
            border-left: 4px solid #007AFF;
            margin: 20px 0;
            padding: 10px 20px;
            background-color: #f8f9fa;
            border-radius: 0 4px 4px 0;
        }
        .article-content code {
            background-color: #f1f3f4;
            padding: 2px 6px;
            border-radius: 3px;
            font-family: 'SF Mono', Monaco, 'Cascadia Code', 'Roboto Mono', Consolas, 'Courier New', monospace;
            font-size: 14px;
        }
        .article-content pre {
            background-color: #f8f9fa;
            padding: 15px;
            border-radius: 6px;
            overflow-x: auto;
            margin: 15px 0;
        }
        .article-content pre code {
            background: none;
            padding: 0;
        }
        .article-content ul, .article-content ol {
            margin: 15px 0;
            padding-left: 25px;
        }
        .article-content li {
            margin: 8px 0;
        }
        .article-footer {
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid #eee;
            text-align: center;
        }
        .read-original {
            display: inline-block;
            padding: 10px 20px;
            background-color: #007AFF;
            color: white;
            text-decoration: none;
            border-radius: 6px;
            font-size: 14px;
        }
        .read-original:hover {
            background-color: #0056CC;
            text-decoration: none;
        }
        @media (max-width: 768px) {
            body {
                padding: 15px;
            }
            .article-title {
                font-size: 20px;
            }
            .article-content {
                font-size: 15px;
            }
        }
    </style>
</head>
<body>
    <div class="article-header">
        <h1 class="article-title">${article.title}</h1>
        <div class="article-meta">
            <span>${article.author || '未知作者'}</span>
            <span class="separator">•</span>
            <span>${article.publishDate}</span>
        </div>
    </div>
    <div class="article-content">
        ${article.content || article.summary || '暂无内容'}
    </div>
    <div class="article-footer">
        <a href="${article.link}" class="read-original" target="_blank">阅读原文</a>
    </div>
</body>
</html>`
    return htmlTemplate
  }

  /**
   * 生成紧凑的HTML模板（减少内存占用）
   */
  private generateCompactHTML(title: string, author: string, publishDate: string, content: string, link: string): string {
    return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${title}</title>
    <style>
        body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI','PingFang SC',sans-serif;line-height:1.6;color:#333;margin:0;padding:20px;background:#fff}
        .header{border-bottom:1px solid #eee;padding-bottom:20px;margin-bottom:20px}
        .title{font-size:24px;font-weight:600;color:#1a1a1a;margin:0 0 15px 0;line-height:1.3}
        .meta{font-size:14px;color:#666;display:flex;align-items:center;gap:12px}
        .content{font-size:16px;line-height:1.8}
        .content img{max-width:100%;height:auto;border-radius:8px;margin:15px 0}
        .content p{margin:15px 0}
        .content h1,.content h2,.content h3{margin:25px 0 15px 0;color:#1a1a1a}
        .content a{color:#007AFF;text-decoration:none}
        .footer{margin-top:40px;padding-top:20px;border-top:1px solid #eee;text-align:center}
        .read-original{display:inline-block;padding:10px 20px;background:#007AFF;color:white;text-decoration:none;border-radius:6px;font-size:14px}
        @media (max-width:768px){body{padding:15px}.title{font-size:20px}.content{font-size:15px}}
    </style>
</head>
<body>
    <div class="header">
        <h1 class="title">${title}</h1>
        <div class="meta">
            <span>${author || '未知作者'}</span>
            <span>•</span>
            <span>${publishDate}</span>
        </div>
    </div>
    <div class="content">${content}</div>
    <div class="footer">
        <a href="${link}" class="read-original" target="_blank">阅读原文</a>
    </div>
</body>
</html>`
  }

  /**
   * 打开原文链接
   */
  private openOriginalArticle() {
    if (!this.selectedArticle || !this.selectedArticle.link) {
      console.warn('RSSArticleDetail', '文章链接不存在，无法打开原文')
      return
    }
    
    try {
      const url = this.selectedArticle.link
      console.info('RSSArticleDetail', `打开原文链接: ${url}`)
      
      // 暂时加载外部链接
      this.webController.loadUrl(url)
      
      // 10秒后自动恢复到文章内容（延长超时）
      setTimeout(() => {
        if (this.selectedArticle) {
          console.info('RSSArticleDetail', '恢复文章内容显示')
          this.reloadWebContent()
        }
      }, 10000)
      
      console.info('RSSArticleDetail', '原文链接已打开，10秒后自动恢复')
      
    } catch (error) {
      console.error('RSSArticleDetail', '打开原文失败:', error)
    }
  }

  /**
   * 打开帮助文档
   */
  private async openHelpDocument() {
    try {
      console.info('RSSArticleDetail', '打开帮助文档开始')
      
      // 确保WebView已准备就绪
      if (!this.isWebViewReady) {
        console.warn('RSSArticleDetail', 'WebView未准备就绪，等待控制器附加')
        // 等待一段时间后重试
        setTimeout(() => {
          if (this.isWebViewReady) {
            this.openHelpDocument()
          } else {
            console.error('RSSArticleDetail', 'WebView控制器附加超时')
          }
        }, 1000)
        return
      }
      
      // 直接使用rawfile协议加载帮助文档
      const helpUrl = 'resource://rawfile/docs/help/index.html'
      
      console.info('RSSArticleDetail', `开始加载帮助文档: ${helpUrl}`)
      
      // 在WebView中加载帮助文档
      this.webController.loadUrl(helpUrl)
      
      // 清除当前文章ID，表示不再显示文章内容
      this.currentArticleId = 'help_document'
      
      console.info('RSSArticleDetail', '帮助文档加载命令已发送')
      
    } catch (error) {
      console.error('RSSArticleDetail', '打开帮助文档失败:', error)
    }
  }

  /**
   * 返回到文章显示
   */
  private returnToArticle() {
    try {
      console.info('RSSArticleDetail', '从帮助文档返回到文章')
      
      if (this.selectedArticle && this.isWebViewReady) {
        // 重新加载当前文章
        this.reloadWebContent()
        console.info('RSSArticleDetail', '已返回到文章显示')
      } else {
        // 没有选中文章，清除当前ID以显示空状态
        this.currentArticleId = ''
        console.info('RSSArticleDetail', '没有选中文章，显示空状态')
      }
      
    } catch (error) {
      console.error('RSSArticleDetail', '返回文章失败:', error)
    }
  }

  /**
   * 回收（销毁并重新创建）WebView
   */
  private recycleWebView() {
    try {
      // 直接销毁并重新创建 WebViewController（不再加载 about:blank，避免失联异常）
      const destroyableController = this.webController as WebviewDestroyable
      if (typeof destroyableController.destroy === 'function') {
        // 若 API 支持 destroy 则优先调用
        destroyableController.destroy()
      }

      this.webController = new webview.WebviewController()
      // 新创建的 controller 尚未 attach 到 Web 组件
      this.isWebViewReady = false

      console.info('RSSArticleDetail', 'WebView 已回收并重新创建')

      // 等待 onControllerAttached 里加载
    } catch (error) {
      console.error('RSSArticleDetail', '回收 WebView 失败:', error)
    }
  }

  /**
   * 生成极简版本HTML：仅保留纯文本，去除图片等重资源，供最终兜底显示
   */
  private generateFallbackHTML(article: RSSArticle): string {
    // 提取纯文本并截断至 50KB
    const source = article.content || article.summary || ''
    const textOnly = source.replace(/<[^>]+>/g, '').substring(0, 50 * 1024)
    const escaped = this.escapeHtml(textOnly)

    return `<!DOCTYPE html><html lang="zh-CN"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>${this.escapeHtml(article.title)}</title><style>body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI','PingFang SC',sans-serif;padding:16px;line-height:1.6;color:#333}</style></head><body><h2>${this.escapeHtml(article.title)}</h2><pre style="white-space:pre-wrap;word-break:break-all;font-size:14px">${escaped}</pre><p style="margin-top:24px"><a href="${this.escapeHtml(article.link)}" target="_blank" style="color:#007AFF;text-decoration:none">阅读原文</a></p></body></html>`
  }

  /**
   * 预抓取文章中的图片并在下载完成后替换为本地路径
   */
  private async prefetchImages(html: string) {
    // 检查图片缓存是否启用
    let imageCacheEnabled = false
    try {
      imageCacheEnabled = await PreferencesUtil.getImageCacheEnabled()
    } catch (error) {
      console.warn('RSSArticleDetail', '获取图片缓存设置失败，默认关闭:', error)
      return
    }

    if (!imageCacheEnabled) {
      console.info('RSSArticleDetail', '图片缓存已关闭，跳过图片预抓取')
      return
    }

    console.info('RSSArticleDetail', '图片缓存已开启，开始预抓取图片')

    const imgRegex = /<img[^>]+src=["']([^"']+)["']/gi
    let match: RegExpExecArray | null
    
    // 获取应用上下文
    let context: common.UIAbilityContext
    try {
      context = getContext(this) as common.UIAbilityContext
    } catch (error) {
      console.error('RSSArticleDetail', '无法获取应用上下文，跳过图片缓存:', error)
      return
    }

    while ((match = imgRegex.exec(html)) !== null) {
      const url = match[1]
      // 跳过 data: url
      if (url.startsWith('data:')) {
        continue
      }
      try {
        const local = await ImageCacheService.downloadAndCache(url, this.selectedArticle?.id || 'unknown', context)
        if (local) {
          const escapedUrl = url.replace(/['"\\]/g, '\\$&')
          const escapedLocal = local.replace(/['"\\]/g, '\\$&')
          this.webController.runJavaScript(
            `document.querySelectorAll('img[src="${escapedUrl}"]').forEach(el=>{el.src='${escapedLocal}';})`
          )
          console.info('RSSArticleDetail', `已使用本地缓存图片替换: ${url} -> ${local}`)
        }
      } catch (e) {
        console.error('RSSArticleDetail', '预抓图片失败:', e)
      }
    }
  }

  build() {
    Column() {
      // 操作按钮栏（始终显示，没有选中文章时禁用）
      Row() {
        Blank()
        
        Row() {
          // 上一篇按钮
          Image($r("app.media.up"))
            .width(20)
            .height(20)
            .margin({ right: 12 })
            .opacity(this.canGoPrevious ? 1.0 : 0.3)
            .onClick(() => {
              if (this.canGoPrevious && this.onPreviousArticle) {
                this.onPreviousArticle()
              }
            })
          
          // 下一篇按钮
          Image($r("app.media.down"))
            .width(20)
            .height(20)
            .margin({ right: 12 })
            .opacity(this.canGoNext ? 1.0 : 0.3)
            .onClick(() => {
              if (this.canGoNext && this.onNextArticle) {
                this.onNextArticle()
              }
            })
          
          // 标记为已读/未读按钮
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
          
          // 收藏/取消收藏按钮
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
          
          // 阅读原文按钮
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
          
          // 帮助文档按钮（始终可用）
          Image($r("app.media.information"))
            .width(20)
            .height(20)
            .opacity(1.0)
            .onClick(() => {
              console.info('RSSArticleDetail', '帮助按钮被点击')
              this.openHelpDocument()
            })
        }
      }
      .width("100%")
      .height(50)
      .padding({ left: 16, right: 16 })
      .backgroundColor("#f7f7f7")
      .border({ width: { bottom: 1 }, color: "#e0e0e0" })

      // 内容区域 - 使用Stack布局，WebView始终存在
      Stack() {
        // Web组件始终存在，用于显示文章内容或帮助文档
        Web({ 
          src: '',
          controller: this.webController 
        })
        .width("100%")
        .height("100%")
        .backgroundColor('#ffffff') // 避免加载过程中出现黑底
        .onControllerAttached(() => {
          console.info('RSSArticleDetail', 'WebView控制器已附加')
          this.isWebViewReady = true
          const articleToLoad = this.pendingArticle ?? this.selectedArticle
          this.pendingArticle = undefined
          console.info('RSSArticleDetail', `onControllerAttached ==> 待加载文章: ${articleToLoad?.id}`)
          if (articleToLoad) {
            this.selectedArticle = articleToLoad   // 同步状态
            this.reloadWebContent()
          }
        })
        .onPageEnd(() => {
          console.info('RSSArticleDetail', '页面加载完成')
          // 隐藏加载层并重置重试计数
          this.isLoadingArticle = false
          this.loadRetryCount = 0
          // 如果当前正在显示帮助文档，不要自动切换到文章
          if (this.currentArticleId === 'help_document') {
            console.info('RSSArticleDetail', '当前显示帮助文档，保持不变')
            return
          }
          // 如果当前有选中文章但还没有加载内容，立即加载
          if (this.selectedArticle && this.currentArticleId !== this.selectedArticle.id) {
            console.info('RSSArticleDetail', '检测到新文章，立即加载内容')
            this.reloadWebContent()
          }
          // 更新当前文章ID
          if (this.selectedArticle) {
            this.currentArticleId = this.selectedArticle.id
          }
        })
        .onErrorReceive((event) => {
          const extEvent = event as ExtendedWebErrorEvent
          const errorDetails: ErrorDetails = {
            code: extEvent.errorCode,
            description: extEvent.description,
            url: extEvent.url,
            isMain: extEvent.isForMainFrame
          }
          console.error('RSSArticleDetail', '文章内容加载失败:', JSON.stringify(errorDetails))
          this.isLoadingArticle = false

          // 详细字段日志
          console.info('RSSArticleDetail', `OnErrorReceiveEvent description: ${extEvent.description || 'N/A'}, url: ${extEvent.url || 'N/A'}, isMain: ${extEvent.isForMainFrame}`)

          // 若检测到 WebView 状态异常（如崩溃、渲染进程丢失等），尝试自动回收并重新加载
          const errorCode = extEvent.errorCode ?? -1
          // OpenHarmony 目前 errorCode == -1 时多为未知错误，直接自愈处理
          console.warn('RSSArticleDetail', `检测到 WebView 错误码: ${errorCode}，启动自愈流程`)
          try {
            if (this.loadRetryCount < this.maxLoadRetries) {
              this.loadRetryCount++
              const delay = this.retryDelayMs * this.loadRetryCount
              console.warn('RSSArticleDetail', `将在 ${delay}ms 后尝试第 ${this.loadRetryCount} 次重试`)

              // 回收并等待
              this.recycleWebView()

              setTimeout(() => {
                if (this.selectedArticle) {
                  console.info('RSSArticleDetail', '重试加载文章内容')
                  this.reloadWebContent()
                }
              }, delay)
            } else {
              console.error('RSSArticleDetail', '已达到最大重试次数，停止自动重试，尝试加载简化版本')

              if (this.selectedArticle) {
                const fallbackHtml = this.generateFallbackHTML(this.selectedArticle)
                try {
                  this.webController.loadUrl('data:text/html;charset=utf-8,' + encodeURIComponent(fallbackHtml))
                  this.isLoadingArticle = false
                  console.info('RSSArticleDetail', '已加载简化版本文章内容')
                } catch (fallbackErr) {
                  console.error('RSSArticleDetail', '加载简化版本仍失败:', fallbackErr)
                }
              }
            }
          } catch (e) {
            console.error('RSSArticleDetail', '自愈流程失败:', e)
          }
        })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .imageAccess(true)
        .mixedMode(MixedMode.All)
        .zoomAccess(true)
        .overviewModeAccess(true)
        .databaseAccess(true)
        
        // 空状态提示（只在没有选中文章且没有加载帮助文档时显示）
        if (!this.selectedArticle && this.currentArticleId !== 'help_document') {
          Column() {
            Image($r("app.media.rss"))
              .width(80)
              .height(80)
              .opacity(0.3)
              .margin({ bottom: 16 })
            
            Text("选择一篇文章开始阅读")
              .fontSize(16)
              .fontColor("#999999")
              
            Text("从左侧文章列表中选择感兴趣的内容")
              .fontSize(14)
              .fontColor("#cccccc")
              .margin({ top: 8 })
          }
          .width("100%")
          .height("100%")
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor("#ffffff")
        }
        
        // 加载中的半透明遮罩层
        if (this.isLoadingArticle) {
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
          .backgroundColor('rgba(255,255,255,0.6)')
        }
      }
      .layoutWeight(1)
    }
    .width("100%")
    .height("100%")
    .backgroundColor("#f5f5f5")
  }
} 