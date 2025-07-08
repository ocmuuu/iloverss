import hilog from '@ohos.hilog'

/**
 * URL 统一哈希工具
 * 规则：先去掉 "?" 及其后所有查询参数，再进行简易 32-bit 哈希；
 * 确保跨模块一致性，避免重复实现。
 */
export class UrlHashUtil {
  /**
   * 去除 URL 查询参数，返回规范化 URL
   */
  static normalizeUrl(url: string): string {
    try {
      const idx: number = url.indexOf('?')
      return idx >= 0 ? url.substring(0, idx) : url
    } catch (error) {
      hilog.error(0x0000, 'UrlHashUtil', 'normalizeUrl error: %{public}s', JSON.stringify(error) ?? '')
      return url
    }
  }

  /**
   * 计算简易 32-bit 哈希（与 ImageCacheService 中旧实现保持一致）
   */
  static hash32(input: string): string {
    let hash = 0
    for (let i = 0; i < input.length; i++) {
      hash = (hash << 5) - hash + input.charCodeAt(i)
      hash |= 0 // 32 位
    }
    return Math.abs(hash).toString()
  }

  /**
   * 综合生成图片唯一 ID：normalize → hash32
   */
  static generateImageId(url: string): string {
    const normalized = UrlHashUtil.normalizeUrl(url)
    return UrlHashUtil.hash32(normalized)
  }
} 