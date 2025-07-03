/**
 * 解析后的作者信息
 */
export interface ParsedAuthor {
  name?: string
  url?: string
  avatarURL?: string
  emailAddress?: string
}

/**
 * 作者信息工具类
 */
export class AuthorUtils {
  
  /**
   * 创建作者信息
   */
  static createAuthor(name?: string, url?: string, avatarURL?: string, emailAddress?: string): ParsedAuthor {
    return {
      name: name,
      url: url,
      avatarURL: avatarURL,
      emailAddress: emailAddress
    }
  }

  /**
   * 从字符串创建作者信息
   */
  static createFromString(authorString: string): ParsedAuthor {
    if (!authorString) {
      return {}
    }

    // 尝试解析邮箱格式: "Name <email@example.com>"
    const emailMatch = authorString.match(/^(.*?)\s*<([^>]+)>$/)
    if (emailMatch) {
      return {
        name: emailMatch[1].trim(),
        emailAddress: emailMatch[2].trim()
      }
    }

    // 检查是否为邮箱地址
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
    if (emailRegex.test(authorString.trim())) {
      return {
        emailAddress: authorString.trim()
      }
    }

    // 作为姓名处理
    return {
      name: authorString.trim()
    }
  }

  /**
   * 获取作者显示名称
   */
  static getDisplayName(author: ParsedAuthor): string {
    if (author.name) {
      return author.name
    }
    if (author.emailAddress) {
      return author.emailAddress
    }
    if (author.url) {
      return author.url
    }
    return '未知作者'
  }

  /**
   * 检查作者信息是否有效
   */
  static isValidAuthor(author: ParsedAuthor): boolean {
    return !!(author.name || author.emailAddress || author.url || author.avatarURL)
  }

  /**
   * 合并作者信息
   */
  static mergeAuthors(authors: ParsedAuthor[]): ParsedAuthor[] {
    const authorMap = new Map<string, ParsedAuthor>()
    
    authors.forEach(author => {
      if (!AuthorUtils.isValidAuthor(author)) {
        return
      }

      const key = author.emailAddress || author.name || author.url || ''
      if (key) {
        const existing = authorMap.get(key)
        if (existing) {
          // 合并信息
          authorMap.set(key, {
            name: existing.name || author.name,
            url: existing.url || author.url,
            avatarURL: existing.avatarURL || author.avatarURL,
            emailAddress: existing.emailAddress || author.emailAddress
          })
        } else {
          authorMap.set(key, author)
        }
      }
    })

    return Array.from(authorMap.values())
  }

  /**
   * 计算作者的哈希值（用于去重）
   */
  static getAuthorHash(author: ParsedAuthor): string {
    const parts = [
      author.name || '',
      author.emailAddress || '',
      author.url || '',
      author.avatarURL || ''
    ]
    return parts.join('|')
  }
}

export default ParsedAuthor 