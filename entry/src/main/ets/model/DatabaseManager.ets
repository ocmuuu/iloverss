import relationalStore from '@ohos.data.relationalStore'
import hilog from '@ohos.hilog'

/**
 * 默认Feed数据类
 */
class DefaultFeedData {
  url: string
  title: string  
  description: string
  link: string
  category: string
  sort_order: number

  constructor(url: string, title: string, description: string, link: string, category: string, sort_order: number) {
    this.url = url
    this.title = title
    this.description = description
    this.link = link
    this.category = category
    this.sort_order = sort_order
  }
}

/**
 * 数据库管理器
 */
export class DatabaseManager {
  private static store: relationalStore.RdbStore | null = null
  private static readonly DATABASE_NAME = 'RSSReader.db'
  private static readonly DATABASE_VERSION = 2 // 升级版本号
  private static isInitialized: boolean = false

  /**
   * 数据库配置
   */
  private static readonly STORE_CONFIG: relationalStore.StoreConfig = {
    name: DatabaseManager.DATABASE_NAME,
    securityLevel: relationalStore.SecurityLevel.S1,
    encrypt: false
  }

  /**
   * 初始化数据库
   */
  static async init(context: Context): Promise<boolean> {
    try {
      hilog.info(0x0000, 'DatabaseManager', '开始初始化数据库...')
      
      // 步骤1: 获取数据库实例
      try {
        DatabaseManager.store = await relationalStore.getRdbStore(context, DatabaseManager.STORE_CONFIG)
        hilog.info(0x0000, 'DatabaseManager', '数据库连接创建成功')
      } catch (error) {
        hilog.error(0x0000, 'DatabaseManager', '创建数据库连接失败: %{public}s', JSON.stringify(error) ?? '')
        throw new Error('创建数据库连接失败')
      }
      
      // 步骤2: 检查并升级数据库版本
      try {
        await DatabaseManager.checkAndUpgradeDatabase()
        hilog.info(0x0000, 'DatabaseManager', '数据库版本检查完成')
      } catch (error) {
        hilog.error(0x0000, 'DatabaseManager', '数据库版本升级失败: %{public}s', JSON.stringify(error) ?? '')
        // 如果升级失败，尝试重新创建数据库
        await DatabaseManager.recreateDatabase()
      }
      
      // 步骤3: 创建所有表
      try {
        await DatabaseManager.createTables()
        hilog.info(0x0000, 'DatabaseManager', '数据表创建成功')
      } catch (error) {
        hilog.error(0x0000, 'DatabaseManager', '创建数据表失败: %{public}s', JSON.stringify(error) ?? '')
        throw new Error('创建数据表失败')
      }
      
      // 步骤4: 初始化默认数据
      try {
        await DatabaseManager.initDefaultData()
        hilog.info(0x0000, 'DatabaseManager', '默认数据初始化成功')
      } catch (error) {
        hilog.error(0x0000, 'DatabaseManager', '初始化默认数据失败: %{public}s', JSON.stringify(error) ?? '')
        // 默认数据初始化失败不是致命错误，可以继续使用
        hilog.warn(0x0000, 'DatabaseManager', '默认数据初始化失败，但数据库仍可使用')
      }
      
      hilog.info(0x0000, 'DatabaseManager', '数据库初始化完全成功')
      DatabaseManager.isInitialized = true
      return true
    } catch (error) {
      hilog.error(0x0000, 'DatabaseManager', '数据库初始化失败: %{public}s', error instanceof Error ? error.message : JSON.stringify(error))
      DatabaseManager.isInitialized = false
      return false
    }
  }

  /**
   * 获取数据库实例
   */
  static getStore(): relationalStore.RdbStore | null {
    if (!DatabaseManager.store) {
      hilog.warn(0x0000, 'DatabaseManager', '数据库实例为null，可能未初始化')
      console.warn('DatabaseManager', '数据库实例为null，可能未初始化')
    }
    return DatabaseManager.store
  }

  /**
   * 检查数据库是否已初始化
   */
  static isInitializedSync(): boolean {
    return DatabaseManager.isInitialized
  }

  /**
   * 检查数据库状态
   */
  static async checkDatabaseStatus(): Promise<boolean> {
    try {
      const store = DatabaseManager.getStore()
      if (!store) {
        hilog.error(0x0000, 'DatabaseManager', '数据库状态检查失败：数据库未初始化')
        console.error('DatabaseManager', '数据库状态检查失败：数据库未初始化')
        return false
      }

      // 尝试执行一个简单的查询来测试连接
      const resultSet = await store.querySql('SELECT COUNT(*) FROM articles')
      
      let count = 0
      if (resultSet.rowCount > 0) {
        resultSet.goToFirstRow() // 必须先调用这个方法
        count = resultSet.getLong(0)
      } else {
      }
      resultSet.close()
      
      hilog.info(0x0000, 'DatabaseManager', `数据库状态正常，当前文章数: ${count}`)
      return true
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : JSON.stringify(error)
      hilog.error(0x0000, 'DatabaseManager', `数据库状态检查失败: ${errorMsg}`)
      console.error('DatabaseManager', `数据库状态检查失败: ${errorMsg}`)
      console.error('DatabaseManager', `错误详情: ${JSON.stringify(error)}`)
      return false
    }
  }

  /**
   * 检查并升级数据库版本
   */
  private static async checkAndUpgradeDatabase(): Promise<void> {
    if (!DatabaseManager.store) {
      throw new Error('数据库未初始化')
    }

    try {
      // 检查是否存在version表
      const versionTableExists = await DatabaseManager.checkTableExists('version')
      
      if (!versionTableExists) {
        // 创建version表
        await DatabaseManager.store.executeSql(`
          CREATE TABLE IF NOT EXISTS version (
            id INTEGER PRIMARY KEY,
            version INTEGER NOT NULL
          )
        `)
        
        // 插入当前版本
        await DatabaseManager.store.executeSql(
          'INSERT INTO version (id, version) VALUES (1, ?)',
          [DatabaseManager.DATABASE_VERSION]
        )
        
        hilog.info(0x0000, 'DatabaseManager', `数据库版本表创建成功，当前版本: ${DatabaseManager.DATABASE_VERSION}`)
      } else {
        // 检查当前版本
        const resultSet = await DatabaseManager.store.querySql('SELECT version FROM version WHERE id = 1')
        
        if (resultSet.rowCount > 0) {
          resultSet.goToFirstRow()
          const currentVersion = resultSet.getLong(0)
          
          if (currentVersion < DatabaseManager.DATABASE_VERSION) {
            hilog.info(0x0000, 'DatabaseManager', `需要升级数据库: ${currentVersion} -> ${DatabaseManager.DATABASE_VERSION}`)
            await DatabaseManager.upgradeDatabase(currentVersion, DatabaseManager.DATABASE_VERSION)
          }
        }
        
        resultSet.close()
      }
    } catch (error) {
      hilog.error(0x0000, 'DatabaseManager', `数据库版本检查失败: ${JSON.stringify(error) ?? ''}`)
      throw new Error(`数据库版本检查失败: ${error}`)
    }
  }

  /**
   * 检查表是否存在
   */
  private static async checkTableExists(tableName: string): Promise<boolean> {
    if (!DatabaseManager.store) {
      return false
    }

    try {
      const resultSet = await DatabaseManager.store.querySql(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [tableName]
      )
      
      const exists = resultSet.rowCount > 0
      resultSet.close()
      return exists
    } catch (error) {
      hilog.error(0x0000, 'DatabaseManager', `检查表存在性失败: ${tableName}, ${JSON.stringify(error) ?? ''}`)
      return false
    }
  }

  /**
   * 升级数据库
   */
  private static async upgradeDatabase(fromVersion: number, toVersion: number): Promise<void> {
    if (!DatabaseManager.store) {
      throw new Error('数据库未初始化')
    }

    try {
      hilog.info(0x0000, 'DatabaseManager', `开始升级数据库: ${fromVersion} -> ${toVersion}`)
      
      // 如果是从版本1升级到版本2，需要添加新的表
      if (fromVersion === 1 && toVersion === 2) {
        // 添加新的表结构
        await DatabaseManager.createStatusesTable()
        await DatabaseManager.createAuthorsTable()
        await DatabaseManager.createAuthorsarticlesTable()
        await DatabaseManager.createSearchTable()
        await DatabaseManager.createSyncstatusTable()
        await DatabaseManager.createAttachmentsTable()
        await DatabaseManager.createHubsTable()
        
        // 更新现有表结构
        await DatabaseManager.upgradeArticlesTable()
      }
      
      // 更新版本号
      await DatabaseManager.store.executeSql(
        'UPDATE version SET version = ? WHERE id = 1',
        [toVersion]
      )
      
      hilog.info(0x0000, 'DatabaseManager', `数据库升级完成: ${fromVersion} -> ${toVersion}`)
    } catch (error) {
      hilog.error(0x0000, 'DatabaseManager', `数据库升级失败: ${JSON.stringify(error) ?? ''}`)
      throw new Error(`数据库升级失败: ${error}`)
    }
  }

  /**
   * 重新创建数据库
   */
  private static async recreateDatabase(): Promise<void> {
    if (!DatabaseManager.store) {
      throw new Error('数据库未初始化')
    }

    try {
      hilog.info(0x0000, 'DatabaseManager', '开始重新创建数据库...')
      
      // 删除所有表
      const tables = ['feeds', 'articles', 'statuses', 'authors', 'authorsarticles', 'search', 'syncstatus', 'attachments', 'hubs', 'version']
      
      for (const table of tables) {
        try {
          await DatabaseManager.store.executeSql(`DROP TABLE IF EXISTS ${table}`)
        } catch (error) {
          hilog.warn(0x0000, 'DatabaseManager', `删除表失败: ${table}, ${JSON.stringify(error) ?? ''}`)
        }
      }
      
      hilog.info(0x0000, 'DatabaseManager', '数据库重新创建完成')
    } catch (error) {
      hilog.error(0x0000, 'DatabaseManager', `重新创建数据库失败: ${JSON.stringify(error) ?? ''}`)
      throw new Error(`重新创建数据库失败: ${error}`)
    }
  }

  /**
   * 升级文章表结构
   */
  private static async upgradeArticlesTable(): Promise<void> {
    if (!DatabaseManager.store) {
      throw new Error('数据库未初始化')
    }

    try {
      // 检查是否需要添加新字段
      const resultSet = await DatabaseManager.store.querySql("PRAGMA table_info(articles)")
      const columns: string[] = []
      
      while (!resultSet.isAtLastRow) {
        resultSet.goToNextRow()
        const columnName = resultSet.getString(1)
        columns.push(columnName)
      }
      resultSet.close()
      
      // 添加缺失的字段
      const requiredColumns = ['searchRowID', 'language', 'created_at', 'updated_at']
      
      for (const column of requiredColumns) {
        if (!columns.includes(column)) {
          let sql = ''
          switch (column) {
            case 'searchRowID':
              sql = 'ALTER TABLE articles ADD COLUMN searchRowID INTEGER'
              break
            case 'language':
              sql = 'ALTER TABLE articles ADD COLUMN language TEXT'
              break
            case 'created_at':
              sql = 'ALTER TABLE articles ADD COLUMN created_at TEXT DEFAULT CURRENT_TIMESTAMP'
              break
            case 'updated_at':
              sql = 'ALTER TABLE articles ADD COLUMN updated_at TEXT DEFAULT CURRENT_TIMESTAMP'
              break
          }
          
          if (sql) {
            await DatabaseManager.store.executeSql(sql)
            hilog.info(0x0000, 'DatabaseManager', `添加字段成功: articles.${column}`)
          }
        }
      }
    } catch (error) {
      hilog.error(0x0000, 'DatabaseManager', `升级文章表失败: ${JSON.stringify(error) ?? ''}`)
      throw new Error(`升级文章表失败: ${error}`)
    }
  }

  /**
   * 创建所有数据表
   */
  private static async createTables(): Promise<void> {
    if (!DatabaseManager.store) {
      throw new Error('数据库未初始化')
    }

    try {
      // 创建文件夹表
      await DatabaseManager.createFoldersTable()
      
      // 创建RSS源表
      await DatabaseManager.createFeedsTable()
      
      // 创建文章表
      await DatabaseManager.createArticlesTable()
      
      // 创建文章状态表 
      await DatabaseManager.createStatusesTable()
      
      // 创建作者表
      await DatabaseManager.createAuthorsTable()
      
      // 创建作者关联表 
      await DatabaseManager.createAuthorsarticlesTable()
      
      // 创建全文搜索表
      await DatabaseManager.createSearchTable()
      
      // 创建同步状态表
      await DatabaseManager.createSyncstatusTable()
      
      // 创建附件表 
      await DatabaseManager.createAttachmentsTable()
      
      // 创建Hub表
      await DatabaseManager.createHubsTable()
      
      hilog.info(0x0000, 'DatabaseManager', '所有数据表创建成功')
    } catch (error) {
      hilog.error(0x0000, 'DatabaseManager', '创建数据表失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('创建数据库失败')
    }
  }

  /**
   * 创建文件夹表
   */
  private static async createFoldersTable(): Promise<void> {
    const sql = `
      CREATE TABLE IF NOT EXISTS folders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        icon TEXT,
        color TEXT,
        sort_order INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    `
    await DatabaseManager.store!.executeSql(sql)
    
    // 创建索引
    await DatabaseManager.store!.executeSql('CREATE INDEX IF NOT EXISTS idx_folders_name ON folders (name)')
    await DatabaseManager.store!.executeSql('CREATE INDEX IF NOT EXISTS idx_folders_sort_order ON folders (sort_order)')
    
    hilog.info(0x0000, 'DatabaseManager', 'folders表创建成功')
  }

  /**
   * 创建RSS源表
   */
  private static async createFeedsTable(): Promise<void> {
    const sql = `
      CREATE TABLE IF NOT EXISTS feeds (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        folder_id INTEGER,
        url TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL,
        description TEXT,
        link TEXT,
        language TEXT,
        last_build_date TEXT,
        image_url TEXT,
        favicon_url TEXT,
        favicon_path TEXT,
        category TEXT,
        is_active INTEGER DEFAULT 1,
        sort_order INTEGER DEFAULT 0,
        feed_type TEXT DEFAULT 'rss',
        next_url TEXT,
        expired INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        last_fetch_at TEXT,
        error_count INTEGER DEFAULT 0,
        last_error TEXT,
        FOREIGN KEY (folder_id) REFERENCES folders (id) ON DELETE SET NULL
      )
    `
    await DatabaseManager.store!.executeSql(sql)
    
    // 创建索引
    await DatabaseManager.store!.executeSql('CREATE INDEX IF NOT EXISTS idx_feeds_url ON feeds (url)')
    await DatabaseManager.store!.executeSql('CREATE INDEX IF NOT EXISTS idx_feeds_active ON feeds (is_active)')
    await DatabaseManager.store!.executeSql('CREATE INDEX IF NOT EXISTS idx_feeds_folder ON feeds (folder_id)')
    
    hilog.info(0x0000, 'DatabaseManager', 'feeds表创建成功')
  }

  /**
   * 创建文章表 
   */
  private static async createArticlesTable(): Promise<void> {
    const sql = `
      CREATE TABLE IF NOT EXISTS articles (
        articleID TEXT PRIMARY KEY,
        feedID INTEGER NOT NULL,
        uniqueID TEXT NOT NULL,
        title TEXT,
        contentHTML TEXT,
        contentText TEXT,
        url TEXT,
        externalURL TEXT,
        summary TEXT,
        imageURL TEXT,
        bannerImageURL TEXT,
        datePublished TEXT,
        dateModified TEXT,
        searchRowID INTEGER,
        language TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (feedID) REFERENCES feeds (id) ON DELETE CASCADE,
        UNIQUE(feedID, uniqueID)
      )
    `
    await DatabaseManager.store!.executeSql(sql)
    
    // 创建索引
    await DatabaseManager.store!.executeSql('CREATE INDEX IF NOT EXISTS idx_articles_feed_id ON articles (feedID)')
    await DatabaseManager.store!.executeSql('CREATE INDEX IF NOT EXISTS idx_articles_date_published ON articles (datePublished DESC)')
    await DatabaseManager.store!.executeSql('CREATE INDEX IF NOT EXISTS idx_articles_unique_id ON articles (feedID, uniqueID)')
    await DatabaseManager.store!.executeSql('CREATE INDEX IF NOT EXISTS idx_articles_search_row_id ON articles (searchRowID)')
    
    hilog.info(0x0000, 'DatabaseManager', 'articles表创建成功')
  }

  /**
   * 创建文章状态表 
   */
  private static async createStatusesTable(): Promise<void> {
    const sql = `
      CREATE TABLE IF NOT EXISTS statuses (
        articleID TEXT PRIMARY KEY,
        read INTEGER DEFAULT 0,
        starred INTEGER DEFAULT 0,
        dateArrived TEXT DEFAULT CURRENT_TIMESTAMP,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (articleID) REFERENCES articles (articleID) ON DELETE CASCADE
      )
    `
    await DatabaseManager.store!.executeSql(sql)
    
    // 创建索引
    await DatabaseManager.store!.executeSql('CREATE INDEX IF NOT EXISTS idx_statuses_read ON statuses (read)')
    await DatabaseManager.store!.executeSql('CREATE INDEX IF NOT EXISTS idx_statuses_starred ON statuses (starred)')
    await DatabaseManager.store!.executeSql('CREATE INDEX IF NOT EXISTS idx_statuses_date_arrived ON statuses (dateArrived DESC)')
    
    hilog.info(0x0000, 'DatabaseManager', 'statuses表创建成功')
  }

  /**
   * 创建作者表 
   */
  private static async createAuthorsTable(): Promise<void> {
    const sql = `
      CREATE TABLE IF NOT EXISTS authors (
        authorID TEXT PRIMARY KEY,
        name TEXT,
        url TEXT,
        avatarURL TEXT,
        emailAddress TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    `
    await DatabaseManager.store!.executeSql(sql)
    
    // 创建索引
    await DatabaseManager.store!.executeSql('CREATE INDEX IF NOT EXISTS idx_authors_name ON authors (name)')
    await DatabaseManager.store!.executeSql('CREATE INDEX IF NOT EXISTS idx_authors_email ON authors (emailAddress)')
    
    hilog.info(0x0000, 'DatabaseManager', 'authors表创建成功')
  }

  /**
   * 创建作者关联表 
   */
  private static async createAuthorsarticlesTable(): Promise<void> {
    const sql = `
      CREATE TABLE IF NOT EXISTS authorsarticles (
        authorID TEXT NOT NULL,
        articleID TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (authorID, articleID),
        FOREIGN KEY (authorID) REFERENCES authors (authorID) ON DELETE CASCADE,
        FOREIGN KEY (articleID) REFERENCES articles (articleID) ON DELETE CASCADE
      )
    `
    await DatabaseManager.store!.executeSql(sql)
    
    // 创建索引
    await DatabaseManager.store!.executeSql('CREATE INDEX IF NOT EXISTS idx_authorsarticles_authorID ON authorsarticles (authorID)')
    await DatabaseManager.store!.executeSql('CREATE INDEX IF NOT EXISTS idx_authorsarticles_articleID ON authorsarticles (articleID)')
    
    hilog.info(0x0000, 'DatabaseManager', 'authorsarticles表创建成功')
  }

  /**
   * 创建全文搜索表 
   * 注：HarmonyOS的SQLite可能不支持FTS4，这里使用普通表模拟
   */
  private static async createSearchTable(): Promise<void> {
    const sql = `
      CREATE TABLE IF NOT EXISTS search (
        rowid INTEGER PRIMARY KEY AUTOINCREMENT,
        articleID TEXT NOT NULL,
        title TEXT,
        body TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (articleID) REFERENCES articles (articleID) ON DELETE CASCADE
      )
    `
    await DatabaseManager.store!.executeSql(sql)
    
    // 创建索引用于搜索
    await DatabaseManager.store!.executeSql('CREATE INDEX IF NOT EXISTS idx_search_article_id ON search (articleID)')
    await DatabaseManager.store!.executeSql('CREATE INDEX IF NOT EXISTS idx_search_title ON search (title)')
    
    hilog.info(0x0000, 'DatabaseManager', 'search表创建成功')
  }

  /**
   * 创建同步状态表
   */
  private static async createSyncstatusTable(): Promise<void> {
    const sql = `
      CREATE TABLE IF NOT EXISTS syncstatus (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        articleID TEXT NOT NULL,
        key TEXT NOT NULL,
        flag INTEGER DEFAULT 0,
        selected INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(articleID, key),
        FOREIGN KEY (articleID) REFERENCES articles (articleID) ON DELETE CASCADE
      )
    `
    await DatabaseManager.store!.executeSql(sql)
    
    // 创建索引
    await DatabaseManager.store!.executeSql('CREATE INDEX IF NOT EXISTS idx_sync_status_article ON syncstatus (articleID)')
    await DatabaseManager.store!.executeSql('CREATE INDEX IF NOT EXISTS idx_sync_status_key ON syncstatus (key)')
    await DatabaseManager.store!.executeSql('CREATE INDEX IF NOT EXISTS idx_sync_status_selected ON syncstatus (selected)')
    
    hilog.info(0x0000, 'DatabaseManager', 'syncstatus表创建成功')
  }

  /**
   * 创建附件表 (扩展功能)
   */
  private static async createAttachmentsTable(): Promise<void> {
    const sql = `
      CREATE TABLE IF NOT EXISTS attachments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        articleID TEXT NOT NULL,
        url TEXT NOT NULL,
        mimeType TEXT,
        title TEXT,
        sizeInBytes INTEGER,
        durationInSeconds INTEGER,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (articleID) REFERENCES articles (articleID) ON DELETE CASCADE
      )
    `
    await DatabaseManager.store!.executeSql(sql)
    
    // 创建索引
    await DatabaseManager.store!.executeSql('CREATE INDEX IF NOT EXISTS idx_attachments_article ON attachments (articleID)')
    await DatabaseManager.store!.executeSql('CREATE INDEX IF NOT EXISTS idx_attachments_mime_type ON attachments (mimeType)')
    
    hilog.info(0x0000, 'DatabaseManager', 'attachments表创建成功')
  }

  /**
   * 创建Hub表 (扩展功能)
   */
  private static async createHubsTable(): Promise<void> {
    const sql = `
      CREATE TABLE IF NOT EXISTS hubs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        feedID INTEGER NOT NULL,
        type TEXT NOT NULL,
        url TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (feedID) REFERENCES feeds (id) ON DELETE CASCADE
      )
    `
    await DatabaseManager.store!.executeSql(sql)
    
    // 创建索引
    await DatabaseManager.store!.executeSql('CREATE INDEX IF NOT EXISTS idx_hubs_feed ON hubs (feedID)')
    await DatabaseManager.store!.executeSql('CREATE INDEX IF NOT EXISTS idx_hubs_type ON hubs (type)')
    
    hilog.info(0x0000, 'DatabaseManager', 'hubs表创建成功')
  }

  /**
   * 初始化默认数据
   */
  private static async initDefaultData(): Promise<void> {
    if (!DatabaseManager.store) {
      throw new Error('数据库未初始化')
    }

    try {
      // 检查是否已经初始化过
      const resultSet = await DatabaseManager.store.querySql('SELECT COUNT(*) as count FROM feeds')
      resultSet.goToFirstRow()
      const count = resultSet.getLong(0)
      resultSet.close()

      if (count > 0) {
        hilog.info(0x0000, 'DatabaseManager', '数据库已包含数据，跳过默认数据初始化')
        return
      }

      // 插入默认文件夹
      const folderSql = `
        INSERT INTO folders (name, sort_order)
        VALUES (?, ?)
      `
      await DatabaseManager.store.executeSql(folderSql, ['Hello', 1])
      await DatabaseManager.store.executeSql(folderSql, ['World', 2])

      hilog.info(0x0000, 'DatabaseManager', '默认文件夹初始化成功，共添加 2 个文件夹')

      // 插入默认RSS源
      const defaultFeeds: DefaultFeedData[] = [
        new DefaultFeedData(
          'https://www.ruanyifeng.com/blog/atom.xml',
          '阮一峰的网络日志',
          '阮一峰的个人博客，分享技术和思考',
          'https://www.ruanyifeng.com/blog/',
          '技术博客',
          1
        ),
        new DefaultFeedData(
          'https://sspai.com/feed',
          '少数派',
          '致力于更好地运用数字产品或科学方法，帮助用户提升工作效率和生活品质',
          'https://sspai.com/',
          '数字生活',
          2
        ),
        new DefaultFeedData(
          'https://www.ifanr.com/feed',
          '爱范儿',
          '让未来触手可及，专注于数字产品和创新科技',
          'https://www.ifanr.com/',
          '科技资讯',
          3
        ),
        new DefaultFeedData(
          'https://www.yystv.cn/rss/feed',
          '游戏研究社',
          '专业游戏媒体，关注游戏文化和游戏产业',
          'https://www.yystv.cn/',
          '游戏资讯',
          4
        ),
        new DefaultFeedData(
          'https://www.gcores.com/rss',
          '机核网',
          '游戏、科技、流行文化，聚合内容平台',
          'https://www.gcores.com/',
          '游戏文化',
          5
        ),
        new DefaultFeedData(
          'https://www.solidot.org/index.rss',
          'Solidot',
          '奇客的资讯，重要的东西',
          'https://www.solidot.org/',
          '科技新闻',
          6
        )
      ]

      for (const feed of defaultFeeds) {
        const sql = `
          INSERT INTO feeds (url, title, description, link, category, sort_order, is_active)
          VALUES (?, ?, ?, ?, ?, ?, 1)
        `
        await DatabaseManager.store.executeSql(sql, [
          feed.url,
          feed.title,
          feed.description,
          feed.link,
          feed.category,
          feed.sort_order
        ])
      }

      hilog.info(0x0000, 'DatabaseManager', `默认RSS源初始化成功，共添加 ${defaultFeeds.length} 个源`)

    } catch (error) {
      hilog.error(0x0000, 'DatabaseManager', '初始化默认数据失败: %{public}s', JSON.stringify(error) ?? '')
      throw new Error('初始化默认数据失败')
    }
  }

  /**
   * 清理数据库
   */
  static async cleanup(): Promise<void> {
    if (DatabaseManager.store) {
      try {
        await DatabaseManager.store.close()
        DatabaseManager.store = null
        DatabaseManager.isInitialized = false
        hilog.info(0x0000, 'DatabaseManager', '数据库连接已关闭')
      } catch (error) {
        hilog.error(0x0000, 'DatabaseManager', '关闭数据库连接失败: %{public}s', JSON.stringify(error) ?? '')
      }
    }
  }

  /**
   * 获取数据库版本
   */
  static getDatabaseVersion(): number {
    return DatabaseManager.DATABASE_VERSION
  }

  /**
   * 获取数据库名称
   */
  static getDatabaseName(): string {
    return DatabaseManager.DATABASE_NAME
  }
}