/**
 * Hub信息接口
 * 用于WebSub协议的Hub信息
 */
export interface HubInfo {
  url: string
  type?: string
  description?: string
}

/**
 * Hub链接信息
 */
export interface HubLink {
  rel: string
  href: string
  type?: string
}

/**
 * 解析后的Hub信息类
 */
export class ParsedHub implements HubInfo {
  public url: string
  public type?: string
  public description?: string

  constructor(url: string, type?: string, description?: string) {
    this.url = url
    this.type = type
    this.description = description
  }

  /**
   * 验证Hub URL是否有效
   */
  isValid(): boolean {
    if (!this.url || this.url.trim().length === 0) {
      return false
    }
    
    // 简单的URL格式验证
    try {
      return this.url.startsWith('http://') || this.url.startsWith('https://')
    } catch (error) {
      return false
    }
  }

  /**
   * 获取Hub的协议类型
   */
  getProtocol(): string {
    if (!this.url) return ''
    
    if (this.url.startsWith('https://')) {
      return 'https'
    } else if (this.url.startsWith('http://')) {
      return 'http'
    }
    
    return ''
  }

  /**
   * 获取Hub的域名
   */
  getDomain(): string {
    if (!this.url) return ''
    
    try {
      const withoutProtocol = this.url.replace(/^https?:\/\//, '')
      const parts = withoutProtocol.split('/')
      return parts[0] || ''
    } catch (error) {
      return ''
    }
  }

  /**
   * 转换为字符串表示
   */
  toString(): string {
    return `ParsedHub(url: ${this.url}, type: ${this.type || 'unknown'})`
  }

  /**
   * 转换为普通对象
   */
  toObject(): HubInfo {
    return {
      url: this.url,
      type: this.type,
      description: this.description
    }
  }

  /**
   * 创建ParsedHub实例的静态方法
   */
  static create(url: string, type?: string, description?: string): ParsedHub {
    return new ParsedHub(url, type, description)
  }

  /**
   * 从对象创建ParsedHub实例
   */
  static fromObject(obj: HubInfo): ParsedHub {
    return new ParsedHub(obj.url, obj.type, obj.description)
  }

  /**
   * 从链接信息创建ParsedHub实例
   */
  static fromLink(link: HubLink): ParsedHub {
    let type = link.type
    if (!type && link.rel) {
      // 根据rel属性推断类型
      if (link.rel.includes('hub')) {
        type = 'websub'
      } else if (link.rel.includes('self')) {
        type = 'self'
      }
    }
    
    return new ParsedHub(link.href, type)
  }
}

/**
 * Hub工具类
 */
export class ParsedHubUtils {
  /**
   * 验证Hub URL数组
   */
  static validateHubs(hubs: ParsedHub[]): ParsedHub[] {
    return hubs.filter(hub => hub.isValid())
  }

  /**
   * 查找指定类型的Hub
   */
  static findHubByType(hubs: ParsedHub[], type: string): ParsedHub | null {
    const found = hubs.find(hub => hub.type === type)
    return found || null
  }

  /**
   * 获取所有有效的Hub URL
   */
  static getValidUrls(hubs: ParsedHub[]): string[] {
    return hubs
      .filter(hub => hub.isValid())
      .map(hub => hub.url)
  }

  /**
   * 合并重复的Hub（相同URL）
   */
  static deduplicateHubs(hubs: ParsedHub[]): ParsedHub[] {
    const urlSet = new Set<string>()
    const result: ParsedHub[] = []
    
    for (const hub of hubs) {
      if (!urlSet.has(hub.url)) {
        urlSet.add(hub.url)
        result.push(hub)
      }
    }
    
    return result
  }

  /**
   * 按类型分组Hub
   */
  static groupByType(hubs: ParsedHub[]): Map<string, ParsedHub[]> {
    const groups = new Map<string, ParsedHub[]>()
    
    for (const hub of hubs) {
      const type = hub.type || 'unknown'
      if (!groups.has(type)) {
        groups.set(type, [])
      }
      groups.get(type)!.push(hub)
    }
    
    return groups
  }

  /**
   * 排序Hub（按类型和URL）
   */
  static sortHubs(hubs: ParsedHub[]): ParsedHub[] {
    return hubs.slice().sort((a, b) => {
      // 首先按类型排序
      const typeA = a.type || 'zzz'
      const typeB = b.type || 'zzz'
      
      if (typeA !== typeB) {
        return typeA.localeCompare(typeB)
      }
      
      // 然后按URL排序
      return a.url.localeCompare(b.url)
    })
  }

  /**
   * 检查是否包含WebSub Hub
   */
  static hasWebSubHub(hubs: ParsedHub[]): boolean {
    return hubs.some(hub => 
      hub.type === 'websub' || 
      hub.type === 'hub' || 
      (hub.url && hub.url.includes('hub'))
    )
  }

  /**
   * 创建默认Hub信息
   */
  static createDefault(baseUrl: string): ParsedHub {
    // 尝试从基础URL创建默认的Hub URL
    const hubUrl = baseUrl.endsWith('/') 
      ? baseUrl + 'hub' 
      : baseUrl + '/hub'
    
    return new ParsedHub(hubUrl, 'websub', 'Default WebSub Hub')
  }
}

export default ParsedHub 