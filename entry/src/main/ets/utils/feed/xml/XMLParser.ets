import hilog from '@ohos.hilog'

/**
 * CDATA匹配信息接口
 */
interface CDATAMatch {
  start: number
  end: number
  content: string
}

/**
 * 简化的DOM Element接口
 */
export interface Element {
  tagName: string
  textContent: string | null
  children: Element[]
  attributes: Record<string, string>
  
  getElementsByTagName(tagName: string): Element[]
  getAttribute(name: string): string | null
}

/**
 * 简化的DOM Document接口
 */
export interface Document {
  documentElement: Element | null
  getElementsByTagName(tagName: string): Element[]
}

/**
 * Document实现类
 */
class DocumentImpl implements Document {
  public documentElement: Element | null
  private rootElement: Element | null

  constructor(rootElement: Element | null) {
    this.documentElement = rootElement
    this.rootElement = rootElement
  }

  getElementsByTagName(tagName: string): Element[] {
    return this.rootElement ? this.getElementsByTagNameRecursive(this.rootElement, tagName) : []
  }

  private getElementsByTagNameRecursive(element: Element, tagName: string): Element[] {
    const results: Element[] = []
    
    // 检查当前元素
    if (element.tagName === tagName) {
      results.push(element)
    }
    
    // 递归搜索子元素
    for (const child of element.children) {
      results.push(...this.getElementsByTagNameRecursive(child, tagName))
    }
    
    return results
  }
}

/**
 * Element实现类
 */
class ElementImpl implements Element {
  public tagName: string
  public textContent: string | null
  public children: Element[]
  public attributes: Record<string, string>

  constructor(
    tagName: string,
    textContent: string | null = null,
    children: Element[] = [],
    attributes: Record<string, string> = {}
  ) {
    this.tagName = tagName
    this.textContent = textContent
    this.children = children
    this.attributes = attributes
  }

  getElementsByTagName(searchTagName: string): Element[] {
    const results: Element[] = []
    // 检查当前元素
    if (this.tagName === searchTagName) {
      results.push(this)
    }
    // 递归搜索子元素
    for (const child of this.children) {
      results.push(...child.getElementsByTagName(searchTagName))
    }
    return results
  }

  getAttribute(name: string): string | null {
    return this.attributes[name] || null
  }
}

/**
 * 简化的XML解析器实现
 * 注：这是一个基础实现，实际生产环境建议使用更完善的XML解析库
 */
export class XMLParser {
  
  /**
   * 静态方法：解析XML字符串为Document对象
   */
  static parse(xmlString: string): Document {
    const parser = new XMLParser()
    return parser.parseXML(xmlString)
  }
  
  /**
   * 静态方法：检查是否可以解析XML
   */
  static canParse(xmlString: string): boolean {
    try {
      XMLParser.parse(xmlString)
      return true
    } catch {
      return false
    }
  }
  
  /**
   * 解析XML字符串为Document对象
   */
  parseXML(xmlString: string): Document {
    try {
      // 验证和预处理XML
      const processedXml = this.validateAndPreprocessXML(xmlString)
      
      // 移除XML声明和注释，但不要解码转义字符（在具体内容解析时才解码）
      const cleanXml = this.cleanXML(processedXml)
      
      // 解析根元素
      const rootElement = this.parseElement(cleanXml)
      
      return new DocumentImpl(rootElement)
    } catch (error) {
      hilog.error(0x0000, 'XMLParser', `XML解析失败: ${error}`)
      throw new Error(`XML解析失败: ${error}`)
    }
  }
  
  /**
   * 验证和预处理XML内容
   */
  private validateAndPreprocessXML(xml: string): string {
    if (!xml || xml.trim() === '') {
      throw new Error('XML内容为空')
    }
    
    // 移除BOM标记
    xml = xml.replace(/^\uFEFF/, '')
    
    // 基本的XML格式检查
    const openTags = xml.match(/<[^/!?][^>]*>/g) || []
    const closeTags = xml.match(/<\/[^>]+>/g) || []
        
    // 检查是否有基本的XML结构
    if (openTags.length === 0) {
      throw new Error('未找到有效的XML标签')
    }
    
    return xml
  }
  
  /**
   * 清理XML字符串，移除声明和注释
   */
  private cleanXML(xml: string): string {
    // 移除XML声明
    xml = xml.replace(/<\?xml[^>]*\?>/gi, '')
    
    // 移除注释
    xml = xml.replace(/<!--[\s\S]*?-->/g, '')
    
    // 移除多余的空白字符
    xml = xml.trim()
    
    return xml
  }

  /**
   * 解码HTML转义字符
   */
  private decodeHTMLEntities(text: string): string {
    if (!text) return text
    
    return text
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'")
      .replace(/&apos;/g, "'")
      // 处理数字实体
      .replace(/&#(\d+);/g, (match: string, dec: string) => {
        return String.fromCharCode(parseInt(dec, 10))
      })
      // 处理十六进制实体
      .replace(/&#x([0-9a-fA-F]+);/g, (match: string, hex: string) => {
        return String.fromCharCode(parseInt(hex, 16))
      })
  }
  
  /**
   * 解析单个元素
   */
  private parseElement(xml: string, startIndex: number = 0): Element | null {
    // 查找开始标签，改进正则表达式以更好地处理各种标签格式
    const startTagMatch = xml.substring(startIndex).match(/<([a-zA-Z][a-zA-Z0-9:_-]*)\s*([^>]*)>/)
    if (!startTagMatch) {
      return null
    }
    
    const tagName = startTagMatch[1]
    const attributesString = startTagMatch[2]
    const startTagEnd = startIndex + startTagMatch.index! + startTagMatch[0].length
    
    // 验证标签名不为空
    if (!tagName || tagName.trim() === '') {
      throw new Error(`无效的标签名: "${tagName}"`)
    }
    
    // 检查是否为自闭合标签
    if (attributesString.endsWith('/')) {
      const attributes = this.parseAttributes(attributesString.slice(0, -1))
      return new ElementImpl(tagName, '', [], attributes)
    }
    
    // 查找对应的结束标签，需要考虑嵌套情况
    const endTag = `</${tagName}>`
    let endTagIndex = this.findMatchingEndTag(xml, tagName, startTagEnd)
    
    if (endTagIndex === -1) {
      throw new Error(`未找到结束标签: ${endTag}，标签名: "${tagName}"`)
    }
    
    // 提取元素内容
    const content = xml.substring(startTagEnd, endTagIndex)
    
    // 解析属性
    const attributes = this.parseAttributes(attributesString)
    
    // 解析子元素和文本内容
    const children: Element[] = []
    let textContent = ''
    
    // 首先检查是否包含CDATA
    let processedContent = content
    const cdataRegex = /<!\[CDATA\[([\s\S]*?)\]\]>/g
    const cdataMatches: CDATAMatch[] = []
    let cdataMatch: RegExpExecArray | null
    
    while ((cdataMatch = cdataRegex.exec(content)) !== null) {
      const cdataInfo: CDATAMatch = {
        start: cdataMatch.index!,
        end: cdataMatch.index! + cdataMatch[0].length,
        content: cdataMatch[1] // CDATA内容不需要解码转义字符
      }
      cdataMatches.push(cdataInfo)
    }
    
    let currentIndex = 0
    while (currentIndex < processedContent.length) {
      // 检查当前位置是否在CDATA区间内
      const inCDATA = cdataMatches.find(cdata => 
        currentIndex >= cdata.start && currentIndex < cdata.end
      )
      
      if (inCDATA) {
        // 处理CDATA内容
        textContent += inCDATA.content
        currentIndex = inCDATA.end
        continue
      }
      
      const nextTagIndex = processedContent.indexOf('<', currentIndex)
      
      if (nextTagIndex === -1) {
        // 没有更多标签，剩余内容为文本
        const remainingText = processedContent.substring(currentIndex).trim()
        if (remainingText) {
          textContent += this.decodeHTMLEntities(remainingText)
        }
        break
      }
      
      // 添加标签前的文本内容
      if (nextTagIndex > currentIndex) {
        const text = processedContent.substring(currentIndex, nextTagIndex).trim()
        if (text) {
          textContent += this.decodeHTMLEntities(text)
        }
      }
      
      // 跳过CDATA区间
      const cdataStart = xml.indexOf('<![CDATA[', currentIndex)
      const nextTagPos = xml.indexOf('<', currentIndex)
      
      if (cdataStart !== -1 && (nextTagPos === -1 || cdataStart < nextTagPos)) {
        const cdataEnd = xml.indexOf(']]>', cdataStart)
        if (cdataEnd !== -1) {
          // 提取CDATA内容并追加到文本
          const cdataContent = xml.substring(cdataStart + 9, cdataEnd)
          textContent += cdataContent
          currentIndex = cdataEnd + 3
          continue
        } else {
          hilog.warn(0x0000, 'XMLParser', `未闭合的CDATA区间，位置: ${cdataStart}`)
          break
        }
      }
      
      // 解析子元素
      try {
        const childElement = this.parseElement(processedContent, nextTagIndex)
        if (childElement) {
          children.push(childElement)
          
          // 计算子元素结束位置
          const childEndTag = `</${childElement.tagName}>`
          const childEndIndex = processedContent.indexOf(childEndTag, nextTagIndex)
          if (childEndIndex !== -1) {
            currentIndex = childEndIndex + childEndTag.length
          } else {
            currentIndex = nextTagIndex + 1
          }
        } else {
          currentIndex = nextTagIndex + 1
        }
      } catch (error) {
        currentIndex = nextTagIndex + 1
      }
    }
    
    const element = new ElementImpl(tagName, textContent || null, children, attributes)
    
    return element
  }
  
  /**
   * 解析属性字符串
   */
  private parseAttributes(attributesString: string): Record<string, string> {
    const attributes: Record<string, string> = {}
    
    if (!attributesString.trim()) {
      return attributes
    }
    
    // 匹配属性模式：name="value" 或 name='value'
    const attributeRegex = /([^\s=]+)=["']([^"']*)["']/g
    let match: RegExpExecArray | null
    
    while ((match = attributeRegex.exec(attributesString)) !== null) {
      const name = match[1] as string
      const value = this.decodeHTMLEntities(match[2] as string) // 解码属性值中的转义字符
      attributes[name] = value
    }
    
    return attributes
  }
  
  /**
   * 查找匹配的结束标签，考虑嵌套情况
   */
  private findMatchingEndTag(xml: string, tagName: string, startPos: number): number {
    // 验证输入参数
    if (!tagName || tagName.trim() === '') {
      return -1
    }
    
    const startTag = `<${tagName}`
    const endTag = `</${tagName}>`
    
    let pos = startPos
    let depth = 1
    let iterations = 0
    const maxIterations = 10000 // 防止无限循环
    
    // 调试日志已移除：查找结束标签
    
    while (pos < xml.length && depth > 0 && iterations < maxIterations) {
      iterations++
      
      // 跳过CDATA区间
      const cdataStart = xml.indexOf('<![CDATA[', pos)
      const nextTagPos = xml.indexOf('<', pos)
      
      if (cdataStart !== -1 && (nextTagPos === -1 || cdataStart < nextTagPos)) {
        const cdataEnd = xml.indexOf(']]>', cdataStart)
        if (cdataEnd !== -1) {
          pos = cdataEnd + 3
          continue
        } else {
          hilog.warn(0x0000, 'XMLParser', `未闭合的CDATA区间，位置: ${cdataStart}`)
          break
        }
      }
      
      const nextStart = xml.indexOf(startTag, pos)
      const nextEnd = xml.indexOf(endTag, pos)
      
      if (nextEnd === -1) {
        return -1 // 没有找到结束标签
      }
      
      // 检查结束标签是否在字符串内或CDATA内
      if (this.isPositionInStringOrCDATA(xml, nextEnd)) {
        pos = nextEnd + 1
        continue
      }
      
      if (nextStart !== -1 && nextStart < nextEnd && !this.isPositionInStringOrCDATA(xml, nextStart)) {
        // 找到了嵌套的开始标签
        // 确保这是一个完整的开始标签（不是属性值的一部分）
        const tagEnd = xml.indexOf('>', nextStart)
        if (tagEnd !== -1 && !xml.substring(nextStart, tagEnd + 1).endsWith('/>')) {
          // 验证这确实是同名标签的开始标签
          const foundTagMatch = xml.substring(nextStart).match(/<([^>\s]+)/)
                  if (foundTagMatch && foundTagMatch[1] === tagName) {
          depth++
          // 调试日志已移除：找到嵌套开始标签
        }
        }
        pos = nextStart + startTag.length
      } else {
        // 找到了结束标签
        depth--
        // 调试日志已移除：找到结束标签
        if (depth === 0) {
          // 调试日志已移除：匹配的结束标签位置
          return nextEnd
        }
        pos = nextEnd + endTag.length
      }
    }
    
    if (iterations >= maxIterations) {
      hilog.error(0x0000, 'XMLParser', `查找结束标签超过最大迭代次数: ${maxIterations}`)
    }
    
    return -1
  }

  /**
   * 检查位置是否在字符串内或CDATA内
   */
  private isPositionInStringOrCDATA(xml: string, position: number): boolean {
    // 检查是否在CDATA内
    let checkPos = 0
    while (checkPos < position) {
      const cdataStart = xml.indexOf('<![CDATA[', checkPos)
      if (cdataStart === -1 || cdataStart >= position) break
      
      const cdataEnd = xml.indexOf(']]>', cdataStart)
      if (cdataEnd === -1) break
      
      if (position >= cdataStart && position <= cdataEnd + 2) {
        return true
      }
      
      checkPos = cdataEnd + 3
    }
    
    return false
  }

  /**
   * 按标签名查找元素
   */
  private getElementsByTagName(element: Element, tagName: string): Element[] {
    const results: Element[] = []
    
    // 检查当前元素
    if (element.tagName === tagName) {
      results.push(element)
    }
    
    // 递归搜索子元素
    for (const child of element.children) {
      results.push(...this.getElementsByTagName(child, tagName))
    }
    
    return results
  }
} 