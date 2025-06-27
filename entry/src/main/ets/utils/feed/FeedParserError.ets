/**
 * 解析器错误类型枚举
 */
export enum FeedParserErrorType {
  // 通用错误
  INVALID_DATA = 'INVALID_DATA',
  NETWORK_ERROR = 'NETWORK_ERROR',
  TIMEOUT_ERROR = 'TIMEOUT_ERROR',
  PARSE_ERROR = 'PARSE_ERROR',
  
  // XML相关错误
  XML_PARSE_ERROR = 'XML_PARSE_ERROR',
  XML_INVALID_STRUCTURE = 'XML_INVALID_STRUCTURE',
  
  // JSON相关错误
  JSON_PARSE_ERROR = 'JSON_PARSE_ERROR',
  JSON_FEED_VERSION_NOT_FOUND = 'JSON_FEED_VERSION_NOT_FOUND',
  JSON_FEED_ITEMS_NOT_FOUND = 'JSON_FEED_ITEMS_NOT_FOUND',
  JSON_FEED_TITLE_NOT_FOUND = 'JSON_FEED_TITLE_NOT_FOUND',
  INVALID_JSON = 'INVALID_JSON',
  
  // RSS相关错误
  RSS_CHANNEL_NOT_FOUND = 'RSS_CHANNEL_NOT_FOUND',
  RSS_ITEMS_NOT_FOUND = 'RSS_ITEMS_NOT_FOUND',
  RSS_INVALID_VERSION = 'RSS_INVALID_VERSION',
  
  // Atom相关错误
  ATOM_FEED_NOT_FOUND = 'ATOM_FEED_NOT_FOUND',
  ATOM_ENTRIES_NOT_FOUND = 'ATOM_ENTRIES_NOT_FOUND',
  ATOM_INVALID_NAMESPACE = 'ATOM_INVALID_NAMESPACE',
  
  // 类型检测错误
  NOT_A_FEED = 'NOT_A_FEED',
  UNSUPPORTED_FORMAT = 'UNSUPPORTED_FORMAT',
  AMBIGUOUS_FORMAT = 'AMBIGUOUS_FORMAT',
  
  // 新增错误类型
  InvalidURL = 'INVALID_URL',
  ContentTooShort = 'CONTENT_TOO_SHORT',
  MissingRequiredElement = 'MISSING_REQUIRED_ELEMENT',
  InvalidDateFormat = 'INVALID_DATE_FORMAT',
  EncodingError = 'ENCODING_ERROR',
  XMLSyntaxError = 'XML_SYNTAX_ERROR',
  JSONSyntaxError = 'JSON_SYNTAX_ERROR',
  SecurityError = 'SECURITY_ERROR',
  Unknown = 'UNKNOWN'
}

/**
 * 错误详情接口
 */
export interface ErrorDetails {
  code: string
  message: string
  url?: string
  lineNumber?: number
  columnNumber?: number
  additionalInfo?: Record<string, string>
  timestamp?: string
}

/**
 * 错误JSON序列化接口
 */
export interface ErrorJSON {
  name: string
  type: FeedParserErrorType
  code: FeedParserErrorType
  message: string
  stack: string
  timestamp: string
  url?: string
  lineNumber?: number
  columnNumber?: number
  additionalInfo?: Record<string, string>
  originalError?: string
}

/**
 * Feed解析器错误类
 */
export class FeedParserError extends Error {
  public readonly errorType: FeedParserErrorType
  public readonly details: ErrorDetails
  public readonly timestamp: Date
  public readonly url?: string
  public readonly lineNumber?: number
  public readonly columnNumber?: number
  public readonly additionalInfo?: Record<string, string>
  public readonly originalError?: Error

  constructor(
    errorType: FeedParserErrorType,
    message: string,
    url?: string,
    lineNumber?: number,
    columnNumber?: number,
    additionalInfo?: Record<string, string>,
    originalError?: Error
  ) {
    super(message)
    this.name = 'FeedParserError'
    this.errorType = errorType
    this.url = url
    this.lineNumber = lineNumber
    this.columnNumber = columnNumber
    this.additionalInfo = additionalInfo
    this.originalError = originalError
    this.timestamp = new Date()
    
    // 构建错误详情
    this.details = {
      code: errorType,
      message: message,
      url: url,
      lineNumber: lineNumber,
      columnNumber: columnNumber,
      additionalInfo: additionalInfo
    }
  }

  /**
   * 获取错误的用户友好描述
   */
  getUserFriendlyMessage(): string {
    return FeedParserErrorMessages.getUserMessage(this.errorType)
  }

  /**
   * 获取错误的技术描述
   */
  getTechnicalMessage(): string {
    return `${this.errorType}: ${this.message}`
  }

  /**
   * 获取完整的错误信息
   */
  getFullErrorInfo(): ErrorDetails {
    const result: ErrorDetails = {
      code: this.details.code,
      message: this.details.message
    }
    
    if (this.details.url) result.url = this.details.url
    if (this.details.lineNumber) result.lineNumber = this.details.lineNumber
    if (this.details.columnNumber) result.columnNumber = this.details.columnNumber
    if (this.details.additionalInfo) result.additionalInfo = this.details.additionalInfo
    
    return result
  }

  /**
   * 转换为字符串
   */
  toString(): string {
    let result = `${this.name}: ${this.message} (${this.errorType})`
    if (this.url) {
      result += ` (URL: ${this.url})`
    }
    return result
  }

  /**
   * 获取错误堆栈信息
   */
  getStackTrace(): string {
    return this.stack || 'No stack trace available'
  }

  /**
   * 创建错误详情对象
   */
  getDetails(): ErrorDetails {
    const details: ErrorDetails = {
      code: this.errorType,
      message: this.message
    }
    
    if (this.url) details.url = this.url
    if (this.lineNumber !== undefined) details.lineNumber = this.lineNumber
    if (this.columnNumber !== undefined) details.columnNumber = this.columnNumber
    if (this.additionalInfo) details.additionalInfo = this.additionalInfo
    
    return details
  }

  /**
   * 转换为用户友好的错误信息
   */
  toUserFriendlyMessage(): string {
    switch (this.errorType) {
      case FeedParserErrorType.UNSUPPORTED_FORMAT:
        return '不支持的Feed格式'
      case FeedParserErrorType.PARSE_ERROR:
        return 'Feed解析失败'
      case FeedParserErrorType.InvalidURL:
        return '无效的URL地址'
      case FeedParserErrorType.NETWORK_ERROR:
        return '网络连接错误'
      case FeedParserErrorType.ContentTooShort:
        return 'Feed内容太短'
      case FeedParserErrorType.MissingRequiredElement:
        return 'Feed缺少必需元素'
      case FeedParserErrorType.InvalidDateFormat:
        return '日期格式无效'
      case FeedParserErrorType.EncodingError:
        return '字符编码错误'
      case FeedParserErrorType.XMLSyntaxError:
        return 'XML语法错误'
      case FeedParserErrorType.JSONSyntaxError:
        return 'JSON语法错误'
      case FeedParserErrorType.SecurityError:
        return '安全限制错误'
      default:
        return '未知错误'
    }
  }

  /**
   * 获取完整的错误报告
   */
  getFullReport(): string {
    const lines: string[] = []
    
    lines.push(`错误类型: ${this.errorType}`)
    lines.push(`错误代码: ${this.errorType}`)
    lines.push(`错误信息: ${this.message}`)
    lines.push(`用户友好信息: ${this.toUserFriendlyMessage()}`)
    
    if (this.url) {
      lines.push(`URL: ${this.url}`)
    }
    
    if (this.lineNumber !== undefined) {
      lines.push(`行号: ${this.lineNumber}`)
    }
    
    if (this.columnNumber !== undefined) {
      lines.push(`列号: ${this.columnNumber}`)
    }
    
    if (this.additionalInfo) {
      lines.push('附加信息:')
      const entries = Object.entries(this.additionalInfo)
      for (let i = 0; i < entries.length; i++) {
        const key = entries[i][0]
        const value = entries[i][1]
        lines.push(`  ${key}: ${value}`)
      }
    }
    
    if (this.originalError) {
      lines.push(`原始错误: ${this.originalError.message}`)
    }
    
    return lines.join('\n')
  }

  /**
   * 检查是否为致命错误
   */
  isFatal(): boolean {
    const fatalTypes = [
      FeedParserErrorType.INVALID_DATA,
      FeedParserErrorType.UNSUPPORTED_FORMAT,
      FeedParserErrorType.NOT_A_FEED,
      FeedParserErrorType.SecurityError,
      FeedParserErrorType.EncodingError
    ]
    return fatalTypes.includes(this.errorType)
  }

  /**
   * 检查是否可重试
   */
  isRetryable(): boolean {
    const retryableTypes = [
      FeedParserErrorType.NETWORK_ERROR,
      FeedParserErrorType.TIMEOUT_ERROR,
      FeedParserErrorType.Unknown
    ]
    return retryableTypes.includes(this.errorType)
  }

  /**
   * 转换为JSON格式
   */
  toJSON(): ErrorJSON {
    const obj: ErrorJSON = {
      name: this.name,
      type: this.errorType,
      code: this.errorType,
      message: this.message,
      stack: this.stack || '',
      timestamp: this.timestamp.toISOString()
    }
    
    if (this.url) obj.url = this.url
    if (this.lineNumber !== undefined) obj.lineNumber = this.lineNumber
    if (this.columnNumber !== undefined) obj.columnNumber = this.columnNumber
    if (this.additionalInfo) obj.additionalInfo = this.additionalInfo
    if (this.originalError) obj.originalError = this.originalError.toString()
    
    return obj
  }
}

/**
 * 错误消息管理类
 */
export class FeedParserErrorMessages {
  private static readonly messages = new Map<FeedParserErrorType, string>([
    [FeedParserErrorType.INVALID_DATA, '数据无效或为空'],
    [FeedParserErrorType.NETWORK_ERROR, '网络连接错误'],
    [FeedParserErrorType.TIMEOUT_ERROR, '请求超时'],
    [FeedParserErrorType.PARSE_ERROR, '解析失败'],
    [FeedParserErrorType.XML_PARSE_ERROR, 'XML解析错误'],
    [FeedParserErrorType.XML_INVALID_STRUCTURE, 'XML结构无效'],
    [FeedParserErrorType.JSON_PARSE_ERROR, 'JSON解析错误'],
    [FeedParserErrorType.JSON_FEED_VERSION_NOT_FOUND, 'JSON Feed版本信息缺失'],
    [FeedParserErrorType.JSON_FEED_ITEMS_NOT_FOUND, 'JSON Feed条目缺失'],
    [FeedParserErrorType.JSON_FEED_TITLE_NOT_FOUND, 'JSON Feed标题缺失'],
    [FeedParserErrorType.INVALID_JSON, '无效的JSON格式'],
    [FeedParserErrorType.RSS_CHANNEL_NOT_FOUND, 'RSS频道信息缺失'],
    [FeedParserErrorType.RSS_ITEMS_NOT_FOUND, 'RSS条目缺失'],
    [FeedParserErrorType.RSS_INVALID_VERSION, 'RSS版本不支持'],
    [FeedParserErrorType.ATOM_FEED_NOT_FOUND, 'Atom Feed信息缺失'],
    [FeedParserErrorType.ATOM_ENTRIES_NOT_FOUND, 'Atom条目缺失'],
    [FeedParserErrorType.ATOM_INVALID_NAMESPACE, 'Atom命名空间无效'],
    [FeedParserErrorType.NOT_A_FEED, '不是有效的Feed格式'],
    [FeedParserErrorType.UNSUPPORTED_FORMAT, '不支持的Feed格式'],
    [FeedParserErrorType.AMBIGUOUS_FORMAT, 'Feed格式不明确'],
    [FeedParserErrorType.InvalidURL, '无效的URL地址'],
    [FeedParserErrorType.ContentTooShort, 'Feed内容太短'],
    [FeedParserErrorType.MissingRequiredElement, 'Feed缺少必需元素'],
    [FeedParserErrorType.InvalidDateFormat, '日期格式无效'],
    [FeedParserErrorType.EncodingError, '字符编码错误'],
    [FeedParserErrorType.XMLSyntaxError, 'XML语法错误'],
    [FeedParserErrorType.JSONSyntaxError, 'JSON语法错误'],
    [FeedParserErrorType.SecurityError, '安全限制错误'],
    [FeedParserErrorType.Unknown, '未知错误']
  ])

  /**
   * 获取用户友好的错误消息
   */
  static getUserMessage(errorType: FeedParserErrorType): string {
    return FeedParserErrorMessages.messages.get(errorType) || '未知错误'
  }

  /**
   * 获取所有错误类型的描述
   */
  static getAllMessages(): Map<FeedParserErrorType, string> {
    return new Map(FeedParserErrorMessages.messages)
  }
}

/**
 * 错误工厂类
 */
export class FeedParserErrorFactory {
  /**
   * 创建无效数据错误
   */
  static createInvalidDataError(url?: string, details?: string): FeedParserError {
    const message = details ? `数据无效: ${details}` : '数据无效或为空'
    return new FeedParserError(FeedParserErrorType.INVALID_DATA, message, url)
  }

  /**
   * 创建网络错误
   */
  static createNetworkError(url?: string, details?: string): FeedParserError {
    const message = details ? `网络错误: ${details}` : '网络连接失败'
    return new FeedParserError(FeedParserErrorType.NETWORK_ERROR, message, url)
  }

  /**
   * 创建解析错误
   */
  static createParseError(url?: string, details?: string): FeedParserError {
    const message = details ? `解析错误: ${details}` : '内容解析失败'
    return new FeedParserError(FeedParserErrorType.PARSE_ERROR, message, url)
  }

  /**
   * 创建XML解析错误
   */
  static createXMLParseError(url?: string, details?: string): FeedParserError {
    const message = details ? `XML解析错误: ${details}` : 'XML格式解析失败'
    return new FeedParserError(FeedParserErrorType.XML_PARSE_ERROR, message, url)
  }

  /**
   * 创建JSON解析错误
   */
  static createJSONParseError(url?: string, details?: string): FeedParserError {
    const message = details ? `JSON解析错误: ${details}` : 'JSON格式解析失败'
    return new FeedParserError(FeedParserErrorType.JSON_PARSE_ERROR, message, url)
  }

  /**
   * 创建不支持格式错误
   */
  static createUnsupportedFormatError(url?: string, format?: string): FeedParserError {
    const message = format ? `不支持的Feed格式: ${format}` : '不支持的Feed格式'
    return new FeedParserError(FeedParserErrorType.UNSUPPORTED_FORMAT, message, url)
  }

  /**
   * 从原生错误创建Feed解析错误
   */
  static fromError(error: Error, url?: string, errorType?: FeedParserErrorType): FeedParserError {
    const type = errorType || FeedParserErrorType.PARSE_ERROR
    const message = error.message || '解析过程中发生错误'
    
    return new FeedParserError(type, message, url, undefined, undefined, undefined, error)
  }
}

/**
 * 错误处理工具类
 */
export class FeedParserErrorHandler {
  /**
   * 判断是否为可重试错误
   */
  static isRetryableError(error: FeedParserError): boolean {
    const retryableTypes = [
      FeedParserErrorType.NETWORK_ERROR,
      FeedParserErrorType.TIMEOUT_ERROR
    ]
    return retryableTypes.includes(error.errorType)
  }

  /**
   * 判断是否为致命错误
   */
  static isFatalError(error: FeedParserError): boolean {
    const fatalTypes = [
      FeedParserErrorType.INVALID_DATA,
      FeedParserErrorType.UNSUPPORTED_FORMAT,
      FeedParserErrorType.NOT_A_FEED
    ]
    return fatalTypes.includes(error.errorType)
  }

  /**
   * 获取错误的建议解决方案
   */
  static getSuggestion(error: FeedParserError): string {
    const suggestions = new Map<FeedParserErrorType, string>([
      [FeedParserErrorType.NETWORK_ERROR, '请检查网络连接并重试'],
      [FeedParserErrorType.TIMEOUT_ERROR, '请稍后重试或检查网络状况'],
      [FeedParserErrorType.INVALID_DATA, '请检查数据源是否正确'],
      [FeedParserErrorType.NOT_A_FEED, '请确认URL指向有效的RSS/Atom Feed'],
      [FeedParserErrorType.UNSUPPORTED_FORMAT, '当前不支持此Feed格式'],
      [FeedParserErrorType.XML_PARSE_ERROR, '数据源XML格式可能有误'],
      [FeedParserErrorType.JSON_PARSE_ERROR, '数据源JSON格式可能有误']
    ])

    return suggestions.get(error.errorType) || '请联系技术支持'
  }

  /**
   * 记录错误
   */
  static logError(error: FeedParserError, context?: string): void {
    const contextInfo = context ? `[${context}] ` : ''
    const message = `${contextInfo}${error.toString()}`
    
    console.error(message)
    
    if (error.url) {
      console.error(`URL: ${error.url}`)
    }
    
    if (error.details.additionalInfo) {
      console.error('Additional Info:', JSON.stringify(error.details.additionalInfo))
    }
  }
}

export default FeedParserError 