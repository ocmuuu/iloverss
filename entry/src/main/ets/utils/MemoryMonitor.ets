/**
 * 内存监控工具类
 * 用于监控应用内存使用情况，特别是WebView的内存占用
 */
export class MemoryMonitor {
  private static instance: MemoryMonitor | null = null
  private memoryCheckInterval: number | null = null
  private memoryWarningThreshold: number = 100 * 1024 * 1024 // 100MB警告阈值
  private callbacks: Array<(memoryInfo: MemoryInfo) => void> = []

  /**
   * 获取单例实例
   */
  static getInstance(): MemoryMonitor {
    if (!MemoryMonitor.instance) {
      MemoryMonitor.instance = new MemoryMonitor()
    }
    return MemoryMonitor.instance
  }

  /**
   * 开始内存监控
   */
  startMonitoring(intervalMs: number = 10000) {
    if (this.memoryCheckInterval) {
      this.stopMonitoring()
    }

    this.memoryCheckInterval = setInterval(() => {
      this.checkMemoryUsage()
    }, intervalMs)

    console.info('MemoryMonitor', '内存监控已启动')
  }

  /**
   * 停止内存监控
   */
  stopMonitoring() {
    if (this.memoryCheckInterval) {
      clearInterval(this.memoryCheckInterval)
      this.memoryCheckInterval = null
      console.info('MemoryMonitor', '内存监控已停止')
    }
  }

  /**
   * 添加内存状态回调
   */
  addCallback(callback: (memoryInfo: MemoryInfo) => void) {
    this.callbacks.push(callback)
  }

  /**
   * 移除内存状态回调
   */
  removeCallback(callback: (memoryInfo: MemoryInfo) => void) {
    const index = this.callbacks.indexOf(callback)
    if (index > -1) {
      this.callbacks.splice(index, 1)
    }
  }

  /**
   * 检查内存使用情况
   */
  private checkMemoryUsage() {
    try {
      // 获取当前内存信息
      const memoryInfo = this.getCurrentMemoryInfo()
      
      // 通知所有回调
      this.callbacks.forEach(callback => {
        try {
          callback(memoryInfo)
        } catch (error) {
          console.error('MemoryMonitor', '内存监控回调执行失败:', error)
        }
      })

      // 检查是否超过警告阈值
      if (memoryInfo.usedMemory > this.memoryWarningThreshold) {
        console.warn('MemoryMonitor', `内存使用量过高: ${this.formatBytes(memoryInfo.usedMemory)}`)
        this.triggerMemoryWarning(memoryInfo)
      }

    } catch (error) {
      console.error('MemoryMonitor', '内存检查失败:', error)
    }
  }

  /**
   * 获取当前内存信息
   */
  private getCurrentMemoryInfo(): MemoryInfo {
    // 注意：HarmonyOS可能没有直接的内存API，这里使用模拟数据
    // 实际项目中需要使用系统提供的内存监控API
    return {
      usedMemory: this.getEstimatedMemoryUsage(),
      totalMemory: 512 * 1024 * 1024, // 假设512MB总内存
      timestamp: Date.now()
    }
  }

  /**
   * 估算内存使用量（模拟实现）
   */
  private getEstimatedMemoryUsage(): number {
    // 这里是模拟实现，实际应该使用系统API
    // 可以通过监控对象数量、字符串长度等来估算
    const baseMemory = 50 * 1024 * 1024 // 50MB基础内存
    const randomVariation = Math.random() * 20 * 1024 * 1024 // 随机变化20MB
    return baseMemory + randomVariation
  }

  /**
   * 触发内存警告
   */
  private triggerMemoryWarning(memoryInfo: MemoryInfo) {
    console.warn('MemoryMonitor', '内存警告:', {
      usedMemory: this.formatBytes(memoryInfo.usedMemory),
      totalMemory: this.formatBytes(memoryInfo.totalMemory),
      usagePercentage: `${((memoryInfo.usedMemory / memoryInfo.totalMemory) * 100).toFixed(2)}%`
    })
  }

  /**
   * 格式化字节数
   */
  private formatBytes(bytes: number): string {
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    if (bytes === 0) return '0 Bytes'
    const i = Math.floor(Math.log(bytes) / Math.log(1024))
    return `${Math.round(bytes / Math.pow(1024, i) * 100) / 100} ${sizes[i]}`
  }

  /**
   * 手动触发垃圾回收建议
   */
  suggestGarbageCollection(): void {
    console.info('MemoryMonitor', '建议执行垃圾回收')
    // 在HarmonyOS中可能需要使用特定的API来建议GC
    // 这里只是记录日志
  }

  /**
   * 设置内存警告阈值
   */
  setMemoryWarningThreshold(thresholdBytes: number) {
    this.memoryWarningThreshold = thresholdBytes
    console.info('MemoryMonitor', `内存警告阈值已设置为: ${this.formatBytes(thresholdBytes)}`)
  }
}

/**
 * 内存信息接口
 */
export interface MemoryInfo {
  usedMemory: number
  totalMemory: number
  timestamp: number
}

/**
 * 内存监控配置
 */
export interface MemoryMonitorConfig {
  intervalMs?: number
  warningThresholdMB?: number
  enableLogging?: boolean
}

/**
 * 便捷的内存监控启动函数
 */
export function startMemoryMonitoring(config: MemoryMonitorConfig = {}) {
  const monitor = MemoryMonitor.getInstance()
  
  if (config.warningThresholdMB) {
    monitor.setMemoryWarningThreshold(config.warningThresholdMB * 1024 * 1024)
  }
  
  monitor.startMonitoring(config.intervalMs || 10000)
  
  return monitor
} 