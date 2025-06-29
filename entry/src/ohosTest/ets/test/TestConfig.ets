/**
 * 测试配置文件
 * 定义测试相关的常量和配置
 */

// 测试常量
export const TEST_CONSTANTS = {
  // 超时时间
  TIMEOUT: {
    SHORT: 1000,
    MEDIUM: 5000,
    LONG: 10000
  },
  
  // 测试数据
  TEST_DATA: {
    FEED_URL: 'https://example.com/test-feed.xml',
    FEED_TITLE: '测试RSS源',
    ARTICLE_TITLE: '测试文章',
    AUTHOR_NAME: '测试作者'
  },
  
  // 测试文件
  TEST_FILES: {
    RSS_SAMPLE: 'test-rss.xml',
    ATOM_SAMPLE: 'test-atom.xml',
    JSON_SAMPLE: 'test-json.json'
  },
  
  // 数据库测试
  DATABASE: {
    TEST_DB_NAME: 'test_rss_reader.db',
    TEST_TABLE_PREFIX: 'test_'
  }
}

// 测试工具函数
export class TestUtils {
  /**
   * 生成测试ID
   */
  static generateTestId(): string {
    return `test_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }
  
  /**
   * 创建测试RSS内容
   */
  static createTestRssContent(title: string = '测试RSS源', itemCount: number = 1): string {
    const items = [];
    for (let i = 1; i <= itemCount; i++) {
      items.push(`
    <item>
      <title>测试文章${i}</title>
      <description>这是第${i}篇测试文章的描述</description>
      <link>https://example.com/article${i}</link>
      <pubDate>Mon, 01 Jan 2024 12:00:00 GMT</pubDate>
      <guid>test-article-${i}</guid>
    </item>`);
    }
    
    return `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>${title}</title>
    <description>用于测试的RSS源</description>
    <link>https://example.com</link>
    <language>zh-CN</language>${items.join('')}
  </channel>
</rss>`;
  }
  
  /**
   * 创建测试Atom内容
   */
  static createTestAtomContent(title: string = '测试Atom源', entryCount: number = 1): string {
    const entries = [];
    for (let i = 1; i <= entryCount; i++) {
      entries.push(`
  <entry>
    <title>测试条目${i}</title>
    <summary>这是第${i}个测试条目的摘要</summary>
    <link href="https://example.com/entry${i}"/>
    <id>test-entry-${i}</id>
    <published>2024-01-01T12:00:00Z</published>
  </entry>`);
    }
    
    return `<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>${title}</title>
  <subtitle>用于测试的Atom源</subtitle>
  <link href="https://example.com"/>
  <id>test-feed-id</id>${entries.join('')}
</feed>`;
  }
  
  /**
   * 创建测试JSON Feed内容
   */
  static createTestJsonFeedContent(title: string = '测试JSON Feed', itemCount: number = 1): string {
    const items = [];
    for (let i = 1; i <= itemCount; i++) {
      items.push({
        id: `test-item-${i}`,
        title: `测试项目${i}`,
        content_text: `这是第${i}个测试项目的内容`,
        url: `https://example.com/item${i}`,
        date_published: '2024-01-01T12:00:00Z'
      });
    }
    
    return JSON.stringify({
      version: 'https://jsonfeed.org/version/1.1',
      title: title,
      description: '用于测试的JSON Feed',
      home_page_url: 'https://example.com',
      items: items
    }, null, 2);
  }
  
  /**
   * 模拟延迟
   */
  static async delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
  
  /**
   * 验证测试结果
   */
  static validateTestResult(result: any, expectedKeys: string[]): boolean {
    if (!result || typeof result !== 'object') {
      return false;
    }
    
    return expectedKeys.every(key => key in result);
  }
  
  /**
   * 清理测试数据
   */
  static async cleanupTestData(): Promise<void> {
    // 这里可以添加清理测试数据的逻辑
    // 比如删除测试数据库、清理临时文件等
    console.info('TestUtils', '清理测试数据');
  }
}

// 测试断言扩展
export class TestAssertions {
  /**
   * 断言对象包含指定属性
   */
  static assertHasProperties(obj: any, properties: string[]): void {
    properties.forEach(prop => {
      if (!(prop in obj)) {
        throw new Error(`对象缺少属性: ${prop}`);
      }
    });
  }
  
  /**
   * 断言数组包含指定元素
   */
  static assertArrayContains<T>(array: T[], element: T): void {
    if (!array.includes(element)) {
      throw new Error(`数组不包含元素: ${element}`);
    }
  }
  
  /**
   * 断言字符串匹配正则表达式
   */
  static assertStringMatches(str: string, regex: RegExp): void {
    if (!regex.test(str)) {
      throw new Error(`字符串不匹配正则表达式: ${regex}`);
    }
  }
  
  /**
   * 断言异步函数抛出异常
   */
  static async assertThrowsAsync(fn: () => Promise<any>, errorType?: any): Promise<void> {
    try {
      await fn();
      throw new Error('期望函数抛出异常，但没有抛出');
    } catch (error) {
      if (errorType && !(error instanceof errorType)) {
        throw new Error(`期望异常类型 ${errorType.name}，但得到 ${error.constructor.name}`);
      }
    }
  }
} 