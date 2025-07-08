import http from '@ohos.net.http'
import fs from '@ohos.file.fs'
import { common } from '@kit.AbilityKit'
import PreferencesUtil from '../utils/PreferencesUtil'

/**
 * 图片缓存服务 - 参考 FaviconDownloader 简化实现
 */
export class ImageCacheService {
  private static readonly TIMEOUT = 8000 // 8秒超时
  private static readonly MAX_FILE_SIZE = 20 * 1024 * 1024 // 20MB最大文件大小（支持大型GIF动画）

  /** 生成简易 hash 文件名 */
  private static hash(url: string): string {
    let hash = 0
    for (let i = 0; i < url.length; i++) {
      hash = (hash << 5) - hash + url.charCodeAt(i)
      hash |= 0 // 32 位
    }
    return Math.abs(hash).toString()
  }

  private static normalize(url: string): string {
    const idx = url.indexOf('?')
    return idx >= 0 ? url.substring(0, idx) : url
  }

  /**
   * 下载并缓存图片
   * @param url 图片URL
   * @param articleId 文章ID
   * @param context 应用上下文
   * @returns 本地文件路径或null
   */
  static async downloadAndCache(
    url: string,
    articleId: string,
    context: common.UIAbilityContext,
    force: boolean = false // true 时忽略首选项，始终尝试缓存
  ): Promise<string | null> {
    try {
      // 创建缓存目录
      const cacheDir = `${context.cacheDir}/rss_images/${ImageCacheService.hash(articleId)}`
      if (!await ImageCacheService.ensureDirectoryExists(cacheDir)) {
        throw new Error('无法创建缓存目录')
      }

      // 检查磁盘空间（简单诊断）
      try {
        const testFile = `${cacheDir}/.space_test`
        const testData = new ArrayBuffer(1024) // 1KB测试数据
        const file = await fs.open(testFile, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY)
        await fs.write(file.fd, testData)
        await fs.close(file.fd)
        await fs.unlink(testFile) // 删除测试文件
        // console.info('ImageCacheService', '磁盘空间检查通过')
      } catch (spaceError) {
        console.error('ImageCacheService', '磁盘空间检查失败:', spaceError)
        throw new Error('磁盘空间不足或写入权限异常')
      }

      // 生成文件名
      const normalizedUrl = ImageCacheService.normalize(url)
      const fileName = ImageCacheService.hash(normalizedUrl)
      const filePath = `${cacheDir}/${fileName}`

      // 检查文件是否已存在
      try {
        const stat = await fs.stat(filePath)
        if (stat.isFile()) {
          // console.info('ImageCacheService', `✅ 缓存命中 - URL: ${url}`)
          // console.info('ImageCacheService', `✅ 缓存文件: ${filePath} (大小: ${stat.size} bytes)`)
          return filePath
        }
      } catch (_) { /* 文件不存在，继续下载 */ }

      // console.info('ImageCacheService', `🔄 开始下载图片 - URL: ${url}`)
      // console.info('ImageCacheService', `🔄 目标路径: ${filePath}`)

      // 下载图片
      const imageData = await ImageCacheService.downloadImage(url)
      if (!imageData) {
        console.error('ImageCacheService', `❌ 下载失败 - URL: ${url}`)
        return null
      }

      // 保存到本地（添加重试机制）
      let savedSuccessfully = false
      let retryCount = 0
      const maxRetries = 3

      while (!savedSuccessfully && retryCount < maxRetries) {
        try {
          // console.info('ImageCacheService', `💾 尝试保存文件 (第${retryCount + 1}次) - 路径: ${filePath}`)
          
          const file = await fs.open(filePath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY)
          await fs.write(file.fd, imageData)
          await fs.close(file.fd)
          
          // 验证文件保存
          const savedStat = await fs.stat(filePath)
          if (savedStat.size === imageData.byteLength) {
            // console.info('ImageCacheService', `✅ 图片下载并缓存完成 - URL: ${url}`)
            // console.info('ImageCacheService', `✅ 缓存文件: ${filePath} (大小: ${savedStat.size} bytes)`)
            savedSuccessfully = true
            return filePath
          } else {
            throw new Error(`文件大小不匹配: 期望 ${imageData.byteLength} bytes, 实际 ${savedStat.size} bytes`)
          }
        } catch (saveError) {
          retryCount++
          console.warn('ImageCacheService', `💾 保存失败 (第${retryCount}次): ${saveError}`)
          
          if (retryCount < maxRetries) {
            // 清理可能存在的不完整文件
            try {
              await fs.unlink(filePath)
            } catch (_) { /* 忽略删除失败 */ }
            
            // 等待一段时间后重试
            await new Promise<void>(resolve => setTimeout(resolve, 500 * retryCount))
          } else {
            throw new Error(saveError instanceof Error ? saveError.message : String(saveError))
          }
        }
      }

      throw new Error('文件保存失败，已达到最大重试次数')
    } catch (error) {
      // 改进错误信息显示
      let errorMessage = 'Unknown error'
      if (error instanceof Error) {
        errorMessage = error.message
      } else if (typeof error === 'string') {
        errorMessage = error
      } else {
        errorMessage = JSON.stringify(error)
      }
      console.error('ImageCacheService', `❌ 缓存图片失败 - URL: ${url}, 错误: ${errorMessage}`)
      return null
    }
  }

  /**
   * 下载图片数据
   */
  private static async downloadImage(url: string): Promise<ArrayBuffer | null> {
    return new Promise((resolve, reject) => {
      const httpRequest = http.createHttp()

      // console.info('ImageCacheService', `📡 发起HTTP请求 - URL: ${url}`)

      httpRequest.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: ImageCacheService.TIMEOUT,
        readTimeout: ImageCacheService.TIMEOUT,
        header: {
          'User-Agent': 'Mozilla/5.0 (compatible; RSS Reader)',
          'Accept': 'image/*,*/*;q=0.8'
        }
      }, (error, data) => {
        httpRequest.destroy()

        if (error) {
          console.error('ImageCacheService', `❌ HTTP请求错误 - URL: ${url}, 错误码: ${error.code}, 消息: ${error.message}`)
          reject(error)
          return
        }

        if (data.responseCode === 200 && data.result) {
          const result = data.result as ArrayBuffer
          const sizeInMB = (result.byteLength / (1024 * 1024)).toFixed(2)
          const format = ImageCacheService.detectImageFormat(result)

          // console.info('ImageCacheService', `📥 下载成功 - 数据大小: ${result.byteLength} bytes (${sizeInMB}MB), 格式: ${format}`)
          // console.info('ImageCacheService', `📊 HTTP响应 - 状态码: ${data.responseCode}, Content-Type: ${data.header['content-type'] || 'unknown'}`)

          // 检查文件大小
          if (result.byteLength > ImageCacheService.MAX_FILE_SIZE) {
            const maxSizeInMB = (ImageCacheService.MAX_FILE_SIZE / (1024 * 1024)).toFixed(2)
            console.error('ImageCacheService', `❌ 文件过大 - ${sizeInMB}MB > ${maxSizeInMB}MB`)
            reject(new Error(`图片文件过大: ${sizeInMB}MB，超过限制 ${maxSizeInMB}MB`))
            return
          }

          resolve(result)
        } else {
          console.error('ImageCacheService', `❌ HTTP请求失败 - 状态码: ${data.responseCode}`)
          reject(new Error(`HTTP错误: ${data.responseCode}`))
        }
      })
    })
  }

  /**
   * 检测图片格式
   */
  private static detectImageFormat(data: ArrayBuffer): string {
    if (data.byteLength < 8) {
      return 'unknown'
    }

    const view = new Uint8Array(data, 0, 8)

    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (view[0] === 0x89 && view[1] === 0x50 && view[2] === 0x4E && view[3] === 0x47) {
      return 'PNG'
    }

    // JPEG: FF D8 FF
    if (view[0] === 0xFF && view[1] === 0xD8 && view[2] === 0xFF) {
      return 'JPEG'
    }

    // GIF: 47 49 46 38 (GIF8)
    if (view[0] === 0x47 && view[1] === 0x49 && view[2] === 0x46 && view[3] === 0x38) {
      return 'GIF'
    }

    // WebP: RIFF...WEBP
    if (view[0] === 0x52 && view[1] === 0x49 && view[2] === 0x46 && view[3] === 0x46 &&
        data.byteLength >= 12) {
      const webpView = new Uint8Array(data, 8, 4)
      if (webpView[0] === 0x57 && webpView[1] === 0x45 && webpView[2] === 0x42 && webpView[3] === 0x50) {
        return 'WebP'
      }
    }

    return 'unknown'
  }

  /**
   * 确保目录存在
   */
  private static async ensureDirectoryExists(dirPath: string): Promise<boolean> {
    try {
      const stat = await fs.stat(dirPath)
      return stat.isDirectory()
    } catch (_) {
      try {
        await fs.mkdir(dirPath, true)
        return true
      } catch (mkdirError) {
        console.error('ImageCacheService', '创建目录失败:', mkdirError)
        return false
      }
    }
  }

  /**
   * 清理过期缓存图片
   */
  static async cleanupOldImages(
    context: common.UIAbilityContext,
    maxAgeMs: number = 30 * 24 * 60 * 60 * 1000
  ): Promise<void> {
    try {
      const cacheDir = `${context.cacheDir}/rss_images`
      await ImageCacheService.traverseAndCleanup(cacheDir, maxAgeMs)
    } catch (error) {
      console.warn('ImageCacheService', '清理过期图片失败:', error)
    }
  }

  /**
   * 递归遍历并清理过期文件
   */
  private static async traverseAndCleanup(dir: string, maxAgeMs: number): Promise<void> {
    try {
      const files = await fs.listFile(dir) as Array<string>
      const now = Date.now()

      for (const fileName of files) {
        try {
          const filePath = `${dir}/${fileName}`
          const stat = await fs.stat(filePath)

          if (stat.isDirectory()) {
            // 递归清理子目录
            await ImageCacheService.traverseAndCleanup(filePath, maxAgeMs)
            
            // 检查目录是否为空，如果为空则删除
            try {
              const subFiles = await fs.listFile(filePath) as Array<string>
              if (subFiles.length === 0) {
                await fs.rmdir(filePath)
                // console.info('ImageCacheService', `清理空目录: ${fileName}`)
              }
            } catch (_) { /* 忽略删除目录失败 */ }
          } else if (stat.isFile()) {
            // 检查文件是否过期
            // OpenHarmony 文件时间可能以秒为单位，需要转换为毫秒
            const fileMtimeMs = stat.mtime > 1000000000000 ? stat.mtime : stat.mtime * 1000
            const fileAge = now - fileMtimeMs
            const fileAgeHours = Math.round(fileAge / (1000 * 60 * 60))
            const maxAgeHours = Math.round(maxAgeMs / (1000 * 60 * 60))
            
            if (fileAge > maxAgeMs) {
              await fs.unlink(filePath)
              // console.info('ImageCacheService', `清理过期图片: ${fileName} (年龄: ${fileAgeHours}小时 > 限制: ${maxAgeHours}小时)`)
            } else {
              // console.info('ImageCacheService', `保留图片: ${fileName} (年龄: ${fileAgeHours}小时 <= 限制: ${maxAgeHours}小时)`)
            }
          }
        } catch (error) {
          console.warn('ImageCacheService', `清理文件失败 ${fileName}:`, error)
        }
      }
    } catch (_) {
      // 目录不存在或访问失败，忽略
    }
  }

  /**
   * 获取单例实例（为了兼容现有调用）
   */
  static getInstance(): ImageCacheService {
    return new ImageCacheService()
  }

  /**
   * 实例方法（为了兼容现有调用）
   */
  async downloadAndCache(url: string, articleId?: string): Promise<string | undefined> {
    // 这个方法需要 context，但实例方法无法获取，直接返回 undefined
    console.warn('ImageCacheService', '请使用静态方法 ImageCacheService.downloadAndCache(url, articleId, context)')
    return undefined
  }

  async cleanupOldImages(): Promise<void> {
    console.warn('ImageCacheService', '请使用静态方法 ImageCacheService.cleanupOldImages(context)')
  }

  /**
   * 检查指定 URL 是否已缓存，返回本地路径，不做任何下载
   */
  static async getCachedPath(url: string, articleId: string, context: common.UIAbilityContext): Promise<string | null> {
    try {
      const cacheDir = `${context.cacheDir}/rss_images/${ImageCacheService.hash(articleId)}`
      const normalizedUrl = ImageCacheService.normalize(url)
      const fileName = ImageCacheService.hash(normalizedUrl)
      const filePath = `${cacheDir}/${fileName}`
      const stat = await fs.stat(filePath)
      if (stat.isFile()) {
        return filePath
      }
      return null
    } catch (_) {
      return null
    }
  }
} 