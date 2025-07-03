/**
 * 解析器数据包装类
 * 封装RSS/Atom/JSON Feed的原始数据和相关方法
 */

// 基础选项接口
export interface ParserOptions {
  baseURL?: string
  strictMode?: boolean
  encoding?: string
  timeout?: number
  userAgent?: string
}

// 扩展选项接口 
export interface ExtendedParserOptions extends ParserOptions {
  customFields?: string[]
  maxSize?: number
}

// RSS/Atom/JSON数据来源
export interface DataSource {
  data: string    // 原始数据
  url: string     // 来源URL
}

/**
 * 解析器数据包装类
 * 提供统一的数据访问接口
 */
export class ParserData implements DataSource {
  public data: string
  public url: string
  private options: ParserOptions

  constructor(data: string, url: string, options: ParserOptions = {}) {
    this.data = data
    this.url = url
    this.options = {
      baseURL: options.baseURL,
      strictMode: options.strictMode,
      encoding: options.encoding,
      timeout: options.timeout,
      userAgent: options.userAgent
    }
  }

  /**
   * 获取基础URL
   */
  getBaseURL(): string {
    return this.options.baseURL || this.extractBaseURL(this.url)
  }

  /**
   * 解析绝对URL
   */
  resolveURL(relativeURL: string): string {
    if (!relativeURL) return ''
    
    // 如果已经是绝对URL，直接返回
    if (relativeURL.startsWith('http://') || relativeURL.startsWith('https://')) {
      return relativeURL
    }
    
    const baseURL = this.getBaseURL()
    if (!baseURL) return relativeURL
    
    try {
      return this.joinURLs(baseURL, relativeURL)
    } catch (error) {
      return relativeURL
    }
  }

  /**
   * 获取数据大小
   */
  getDataSize(): number {
    return this.data ? this.data.length : 0
  }

  /**
   * 验证数据是否有效
   */
  isValid(): boolean {
    return !!(this.data && this.data.trim().length > 0 && this.url)
  }

  /**
   * 获取数据编码
   */
  getEncoding(): string {
    // 尝试从数据中检测编码
    const match = this.data.match(/encoding=["']([^"']+)["']/i)
    return match ? match[1] : 'utf-8'
  }

  /**
   * 获取内容类型
   */
  getContentType(): string {
    // 基于数据内容判断类型
    const trimmedData = this.data.trim()
    
    if (trimmedData.startsWith('{')) {
      return 'application/json'
    } else if (trimmedData.startsWith('<')) {
      return 'application/xml'
    }
    
    return 'text/plain'
  }

  /**
   * 从URL提取基础URL
   */
  private extractBaseURL(url: string): string {
    if (!url) return ''
    
    try {
      const parts = url.split('/')
      if (parts.length < 3) return url
      
      return `${parts[0]}//${parts[2]}`
    } catch (error) {
      return url
    }
  }

  /**
   * 连接URL路径
   */
  private joinURLs(baseURL: string, relativePath: string): string {
    if (!baseURL || !relativePath) return relativePath || baseURL || ''
    
    // 移除baseURL末尾的斜杠
    const cleanBase = baseURL.replace(/\/$/, '')
    
    // 移除relativePath开头的斜杠
    const cleanRelative = relativePath.replace(/^\//, '')
    
    return `${cleanBase}/${cleanRelative}`
  }

  /**
   * 创建ParserData实例的静态方法
   */
  static create(data: string, url: string, options?: ParserOptions): ParserData {
    return new ParserData(data, url, options)
  }

  /**
   * 从对象创建ParserData实例
   */
  static fromObject(source: DataSource, options?: ParserOptions): ParserData {
    return new ParserData(source.data, source.url, options)
  }
}

/**
 * 解析器数据工具类
 */
export class ParserDataUtils {
  /**
   * 验证数据格式
   */
  static validateFormat(data: string, expectedFormat: 'xml' | 'json'): boolean {
    if (!data || data.trim().length === 0) return false
    
    const trimmed = data.trim()
    
    switch (expectedFormat) {
      case 'xml':
        return trimmed.startsWith('<') && trimmed.includes('>')
      case 'json':
        return (trimmed.startsWith('{') && trimmed.endsWith('}')) ||
               (trimmed.startsWith('[') && trimmed.endsWith(']'))
      default:
        return false
    }
  }

  /**
   * 清理数据
   */
  static cleanData(data: string): string {
    if (!data) return ''
    
    return data
      .replace(/^\uFEFF/, '') // 移除BOM
      .replace(/\r\n/g, '\n') // 标准化换行符
      .trim()
  }

  /**
   * 检查数据是否为Feed格式
   */
  static isFeedData(data: string): boolean {
    if (!data) return false
    
    const trimmed = data.trim().toLowerCase()
    
    // XML格式检查
    if (trimmed.startsWith('<')) {
      return trimmed.includes('<rss') || 
             trimmed.includes('<feed') || 
             trimmed.includes('<atom')
    }
    
    // JSON格式检查
    if (trimmed.startsWith('{')) {
      return trimmed.includes('"version"') && 
             (trimmed.includes('"items"') || trimmed.includes('"entry"'))
    }
    
    return false
  }

  /**
   * 获取数据摘要
   */
  static getDataSummary(data: string, maxLength: number = 100): string {
    if (!data) return ''
    
    const cleaned = data.replace(/\s+/g, ' ').trim()
    return cleaned.length > maxLength 
      ? cleaned.substring(0, maxLength) + '...'
      : cleaned
  }
}

export default ParserData 