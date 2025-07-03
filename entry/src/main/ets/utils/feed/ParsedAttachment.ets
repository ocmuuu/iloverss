/**
 * 解析后的附件信息
 */
export interface ParsedAttachment {
  url: string
  mimeType?: string
  title?: string
  sizeInBytes?: number
  durationInSeconds?: number
}

/**
 * 附件工具类
 */
export class AttachmentUtils {

  /**
   * 创建附件信息
   */
  static createAttachment(url: string, mimeType?: string, title?: string, sizeInBytes?: number, durationInSeconds?: number): ParsedAttachment | null {
    if (!url || url.trim().length === 0) {
      return null
    }
    
    return {
      url: url.trim(),
      mimeType: mimeType,
      title: title,
      sizeInBytes: sizeInBytes,
      durationInSeconds: durationInSeconds
    }
  }

  /**
   * 从enclosure标签解析附件
   */
  static parseFromEnclosure(enclosureTag: string): ParsedAttachment | null {
    const url = AttachmentUtils.extractAttributeValue(enclosureTag, 'url')
    if (!url) {
      return null
    }

    const mimeType = AttachmentUtils.extractAttributeValue(enclosureTag, 'type')
    const lengthStr = AttachmentUtils.extractAttributeValue(enclosureTag, 'length')
    const sizeInBytes = lengthStr ? parseInt(lengthStr) : undefined

    return AttachmentUtils.createAttachment(url, mimeType, undefined, sizeInBytes)
  }

  /**
   * 提取XML属性值
   */
  private static extractAttributeValue(tag: string, attributeName: string): string | undefined {
    const regex = new RegExp(`${attributeName}\\s*=\\s*['"]([^'"]*?)['"]`, 'i')
    const match = tag.match(regex)
    return match ? match[1] : undefined
  }

  /**
   * 获取附件类型
   */
  static getAttachmentType(attachment: ParsedAttachment): AttachmentType {
    if (!attachment.mimeType) {
      return AttachmentType.UNKNOWN
    }

    const mimeType = attachment.mimeType.toLowerCase()
    
    if (mimeType.startsWith('image/')) {
      return AttachmentType.IMAGE
    }
    if (mimeType.startsWith('audio/')) {
      return AttachmentType.AUDIO
    }
    if (mimeType.startsWith('video/')) {
      return AttachmentType.VIDEO
    }
    if (mimeType.includes('pdf')) {
      return AttachmentType.PDF
    }
    if (mimeType.startsWith('text/')) {
      return AttachmentType.TEXT
    }
    if (mimeType.includes('zip') || mimeType.includes('archive')) {
      return AttachmentType.ARCHIVE
    }

    return AttachmentType.OTHER
  }

  /**
   * 获取附件的可读文件大小
   */
  static getReadableFileSize(sizeInBytes?: number): string {
    if (!sizeInBytes || sizeInBytes <= 0) {
      return '未知大小'
    }

    const units = ['B', 'KB', 'MB', 'GB', 'TB']
    let size = sizeInBytes
    let unitIndex = 0

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024
      unitIndex++
    }

    return `${size.toFixed(unitIndex > 0 ? 1 : 0)} ${units[unitIndex]}`
  }

  /**
   * 获取附件的可读时长
   */
  static getReadableDuration(durationInSeconds?: number): string {
    if (!durationInSeconds || durationInSeconds <= 0) {
      return '未知时长'
    }

    const hours = Math.floor(durationInSeconds / 3600)
    const minutes = Math.floor((durationInSeconds % 3600) / 60)
    const seconds = Math.floor(durationInSeconds % 60)

    if (hours > 0) {
      return `${hours}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`
    } else {
      return `${minutes}:${seconds.toString().padStart(2, '0')}`
    }
  }

  /**
   * 检查附件是否有效
   */
  static isValidAttachment(attachment: ParsedAttachment): boolean {
    return !!(attachment.url && attachment.url.trim().length > 0)
  }

  /**
   * 获取附件文件名
   */
  static getFileName(attachment: ParsedAttachment): string {
    if (attachment.title) {
      return attachment.title
    }

    try {
      // 从URL中提取文件名，替代URL构造器
      const lastSlashIndex = attachment.url.lastIndexOf('/')
      if (lastSlashIndex >= 0 && lastSlashIndex < attachment.url.length - 1) {
        const fileName = attachment.url.substring(lastSlashIndex + 1)
        // 移除查询参数
        const questionMarkIndex = fileName.indexOf('?')
        return questionMarkIndex >= 0 ? fileName.substring(0, questionMarkIndex) : fileName
      }
      return '未知文件'
    } catch (error) {
      return '未知文件'
    }
  }

  /**
   * 计算附件的哈希值（用于去重）
   */
  static getAttachmentHash(attachment: ParsedAttachment): string {
    return attachment.url
  }
}

/**
 * 附件类型枚举
 */
export enum AttachmentType {
  IMAGE = 'image',
  AUDIO = 'audio',
  VIDEO = 'video',
  PDF = 'pdf',
  TEXT = 'text',
  ARCHIVE = 'archive',
  OTHER = 'other',
  UNKNOWN = 'unknown'
}

export default ParsedAttachment 