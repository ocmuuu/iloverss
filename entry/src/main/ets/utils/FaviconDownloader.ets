import http from '@ohos.net.http'
import fs from '@ohos.file.fs'
import { BusinessError } from '@kit.BasicServicesKit'
import { common } from '@kit.AbilityKit'

/**
 * Favicon下载器工具类
 */
export class FaviconDownloader {
  private static readonly TIMEOUT = 10000 // 10秒超时
  private static readonly MAX_FILE_SIZE = 1024 * 1024 // 1MB最大文件大小
  
  /**
   * 从网站URL生成favicon URL
   * @param websiteUrl 网站URL
   * @returns favicon URL数组（按优先级排序）
   */
  static generateFaviconUrls(websiteUrl: string): string[] {
    // 使用正则简单提取协议和主机名，避免使用 Node.js 的 URL 对象
    const match: RegExpMatchArray | null = websiteUrl.match(/^(https?:\/\/[^\/]+)/i)
    if (!match) {
      console.error('FaviconDownloader', '无效的网站URL:', websiteUrl)
      return []
    }

    const baseUrl: string = match[1]

    return [
      `${baseUrl}/favicon.ico`,
      `${baseUrl}/favicon.png`,
      `${baseUrl}/apple-touch-icon.png`,
      `${baseUrl}/apple-touch-icon-precomposed.png`
    ]
  }
  
  /**
   * 下载favicon并保存到本地
   * @param feedId RSS源ID
   * @param iconUrl 图标URL（可以是直接的图片URL或网站URL）
   * @param context 应用上下文
   * @returns 本地图标路径或null
   */
  static async downloadAndSaveFavicon(
    feedId: number,
    iconUrl: string,
    context: common.UIAbilityContext
  ): Promise<string | null> {
    // 检查是否是直接的图片URL
    const isDirectImageUrl = /\.(ico|png|jpg|jpeg|gif|svg|webp)$/i.test(iconUrl)
    
    let urlsToTry: string[]
    
    if (isDirectImageUrl) {
      // 如果是直接的图片URL，直接使用
      urlsToTry = [iconUrl]
      console.info('FaviconDownloader', `检测到直接图片URL: ${iconUrl}`)
    } else {
      // 如果是网站URL，生成常见的favicon URL
      urlsToTry = FaviconDownloader.generateFaviconUrls(iconUrl)
      console.info('FaviconDownloader', `检测到网站URL，生成favicon URL列表: ${iconUrl}`)
    }
    
    for (const url of urlsToTry) {
      try {
        console.info('FaviconDownloader', `尝试下载图标: ${url}`)
        
        // 下载图标数据
        const imageData = await FaviconDownloader.downloadFavicon(url)
        if (!imageData) {
          continue
        }
        
        // 保存到本地
        const localPath = await FaviconDownloader.saveToLocal(feedId, imageData, context)
        if (localPath) {
          console.info('FaviconDownloader', `图标保存成功: ${localPath}`)
          return localPath
        }
      } catch (error) {
        console.warn('FaviconDownloader', `下载图标失败 ${url}:`, JSON.stringify(error))
        continue
      }
    }
    
    console.warn('FaviconDownloader', `所有图标下载尝试失败: ${iconUrl}`)
    return null
  }
  
  /**
   * 下载favicon数据
   * @param faviconUrl favicon URL
   * @returns 图像数据或null
   */
  private static async downloadFavicon(faviconUrl: string): Promise<ArrayBuffer | null> {
    return new Promise((resolve, reject) => {
      const httpRequest: http.HttpRequest = http.createHttp()
      
      httpRequest.request(faviconUrl, {
        method: http.RequestMethod.GET,
        connectTimeout: FaviconDownloader.TIMEOUT,
        readTimeout: FaviconDownloader.TIMEOUT,
        header: {
          'User-Agent': 'Mozilla/5.0 (compatible; RSS Reader)',
          'Accept': 'image/*,*/*;q=0.8'
        }
      }, (error: BusinessError, data: http.HttpResponse) => {
        httpRequest.destroy()
        
        if (error) {
          reject(error)
          return
        }
        
        if (data.responseCode === http.ResponseCode.OK) {
          const result = data.result as ArrayBuffer
          
          // 检查文件大小
          if (result.byteLength > FaviconDownloader.MAX_FILE_SIZE) {
            reject(new Error(`文件过大: ${result.byteLength} bytes`))
            return
          }
          
          // 简单验证是否为图像数据
          if (FaviconDownloader.isValidImageData(result)) {
            resolve(result)
          } else {
            reject(new Error('不是有效的图像数据'))
          }
        } else {
          reject(new Error(`HTTP错误: ${data.responseCode}`))
        }
      })
    })
  }
  
  /**
   * 简单验证是否为图像数据
   * @param data 数据缓冲区
   * @returns 是否为有效图像
   */
  private static isValidImageData(data: ArrayBuffer): boolean {
    if (data.byteLength < 8) {
      return false
    }
    
    const view = new Uint8Array(data, 0, 8)
    
    // 检查常见图像格式的文件头
    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (view[0] === 0x89 && view[1] === 0x50 && view[2] === 0x4E && view[3] === 0x47) {
      return true
    }
    
    // JPEG: FF D8 FF
    if (view[0] === 0xFF && view[1] === 0xD8 && view[2] === 0xFF) {
      return true
    }
    
    // ICO: 00 00 01 00
    if (view[0] === 0x00 && view[1] === 0x00 && view[2] === 0x01 && view[3] === 0x00) {
      return true
    }
    
    // GIF: 47 49 46 38
    if (view[0] === 0x47 && view[1] === 0x49 && view[2] === 0x46 && view[3] === 0x38) {
      return true
    }
    
    return false
  }
  
  /**
   * 保存图标到本地文件
   * @param feedId RSS源ID
   * @param imageData 图像数据
   * @param context 应用上下文
   * @returns 本地文件路径或null
   */
  private static async saveToLocal(
    feedId: number,
    imageData: ArrayBuffer,
    context: common.UIAbilityContext
  ): Promise<string | null> {
    try {
      // 创建图标目录
      const iconDir: string = `${context.filesDir}/favicons`
      if (!await FaviconDownloader.ensureDirectoryExists(iconDir)) {
        throw new Error('无法创建图标目录')
      }
      
      // 生成文件名
      const fileName = `favicon_${feedId}.ico`
      const filePath = `${iconDir}/${fileName}`
      
      // 写入文件
      const file = await fs.open(filePath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY)
      await fs.write(file.fd, imageData)
      await fs.close(file.fd)
      
      console.info('FaviconDownloader', `图标保存完成: ${filePath}`)
      return filePath
    } catch (error) {
      console.error('FaviconDownloader', '保存图标失败:', JSON.stringify(error))
      return null
    }
  }
  
  /**
   * 确保目录存在
   * @param dirPath 目录路径
   * @returns 是否成功
   */
  private static async ensureDirectoryExists(dirPath: string): Promise<boolean> {
    try {
      const stat = await fs.stat(dirPath)
      return stat.isDirectory()
    } catch (error) {
      try {
        await fs.mkdir(dirPath, true)
        return true
      } catch (mkdirError) {
        console.error('FaviconDownloader', '创建目录失败:', JSON.stringify(mkdirError))
        return false
      }
    }
  }
  
  /**
   * 删除本地favicon文件
   * @param feedId RSS源ID
   * @param context 应用上下文
   */
  static async deleteFavicon(feedId: number, context: common.UIAbilityContext): Promise<void> {
    try {
      const filePath = `${context.filesDir}/favicons/favicon_${feedId}.ico`
      await fs.unlink(filePath)
      console.info('FaviconDownloader', `删除图标: ${filePath}`)
    } catch (error) {
      console.warn('FaviconDownloader', '删除图标失败:', JSON.stringify(error))
    }
  }
  
  /**
   * 获取本地favicon路径
   * @param feedId RSS源ID
   * @param context 应用上下文
   * @returns 本地路径或null
   */
  static async getLocalFaviconPath(
    feedId: number,
    context: common.UIAbilityContext
  ): Promise<string | null> {
    try {
      const filePath = `${context.filesDir}/favicons/favicon_${feedId}.ico`
      const stat = await fs.stat(filePath)
      return stat.isFile() ? filePath : null
    } catch (error) {
      return null
    }
  }
  
  /**
   * 清理过期的favicon文件
   * @param context 应用上下文
   * @param maxAgeMs 最大保留时间（毫秒）
   */
  static async cleanupOldFavicons(
    context: common.UIAbilityContext,
    maxAgeMs: number = 30 * 24 * 60 * 60 * 1000 // 默认30天
  ): Promise<void> {
    try {
      const iconDir: string = `${context.filesDir}/favicons`
      const files: Array<string> = await fs.listFile(iconDir) as Array<string>
      const now = Date.now()
      
      for (const fileName of files) {
        try {
          const filePath = `${iconDir}/${fileName}`
          const stat = await fs.stat(filePath)
          const fileAge = now - stat.mtime
          
          if (fileAge > maxAgeMs) {
            await fs.unlink(filePath)
            console.info('FaviconDownloader', `清理过期图标: ${fileName}`)
          }
        } catch (error) {
          console.warn('FaviconDownloader', `清理文件失败 ${fileName}:`, JSON.stringify(error))
        }
      }
    } catch (error) {
      console.warn('FaviconDownloader', '清理过期图标失败:', JSON.stringify(error))
    }
  }
} 