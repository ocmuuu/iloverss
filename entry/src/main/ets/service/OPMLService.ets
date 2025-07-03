import { FolderDAO } from '../model/FolderDAO';
import { FeedDAO } from '../model/FeedDAO';
import fs from '@ohos.file.fs';
import { common } from '@kit.AbilityKit';
import util from '@ohos.util';

/**
 * OPML 服务
 * 负责生成和解析OPML文件
 */
export class OPMLService {

  /**
   * 生成OPML字符串（包含所有文件夹和订阅源）
   */
  static async generateOpml(): Promise<string> {
    const folders = await FolderDAO.getAllFolders(true);
    const feeds = await FeedDAO.getAllFeeds(true);

    let opml = '<?xml version="1.0" encoding="UTF-8"?>\n';
    opml += '<opml version="2.0">\n';
    opml += '  <head>\n    <title>iLoveRSS Subscriptions</title>\n  </head>\n';
    opml += '  <body>\n';

    // 文件夹及其内的订阅
    for (const folder of folders) {
      opml += `    <outline text="${OPMLService.escapeXml(folder.name)}" title="${OPMLService.escapeXml(folder.name)}">\n`;
      const feedsInFolder = feeds.filter(f => f.folderId === folder.id);
      for (const feed of feedsInFolder) {
        opml += `      <outline type="rss" text="${OPMLService.escapeXml(feed.title)}" title="${OPMLService.escapeXml(feed.title)}" xmlUrl="${OPMLService.escapeXml(feed.url)}" />\n`;
      }
      opml += '    </outline>\n';
    }

    // 不在任何文件夹中的订阅
    const feedsWithoutFolder = feeds.filter(f => !f.folderId);
    for (const feed of feedsWithoutFolder) {
      opml += `    <outline type="rss" text="${OPMLService.escapeXml(feed.title)}" title="${OPMLService.escapeXml(feed.title)}" xmlUrl="${OPMLService.escapeXml(feed.url)}" />\n`;
    }

    opml += '  </body>\n'
    opml += '</opml>'

    return opml;
  }

  /**
   * 保存OPML文件到应用私有目录 (filesDir/exports)
   * 返回保存的文件绝对路径
   */
  static async saveOpmlFile(content: string, context: common.UIAbilityContext): Promise<string> {
    // 导出到应用私有目录，无需申请外部存储权限
    const exportDir = `${context.filesDir}/exports`;
    await OPMLService.ensureDirectoryExists(exportDir);

    const fileName = `subscriptions_${Date.now()}.opml`;
    const filePath = `${exportDir}/${fileName}`;

    const file = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY);
    const encoder = new util.TextEncoder('utf-8');
    const data = encoder.encode(content);
    fs.writeSync(file.fd, data.buffer);
    fs.closeSync(file.fd);

    return filePath;
  }

  /**
   * 确保目录存在
   */
  private static async ensureDirectoryExists(dirPath: string): Promise<void> {
    try {
      const stat = await fs.stat(dirPath);
      if (stat && stat.isDirectory()) {
        return;
      }
      // 如果同名文件存在则抛错
      throw new Error('目标路径不是目录');
    } catch (_) {
      // 不存在，尝试创建
      await fs.mkdir(dirPath, true);
    }
  }

  /**
   * XML 字符串转义
   */
  private static escapeXml(text: string): string {
    return text.replace(/[<>&"']/g, ch => {
      switch (ch) {
        case '<': return '&lt;';
        case '>': return '&gt;';
        case '&': return '&amp;';
        case '"': return '&quot;';
        case "'": return '&apos;';
        default: return ch;
      }
    });
  }

  /**
   * 导入 Download 目录中的 OPML 文件（若存在多个，取最新修改时间）
   */
  static async importOpml(context: common.UIAbilityContext): Promise<void> {
    // 从应用私有目录导入 OPML，无需读取外部存储权限
    const exportDir = `${context.filesDir}/exports`;
    await OPMLService.ensureDirectoryExists(exportDir);
    // 若目录不存在则直接报错
    const files: Array<string> = (await fs.listFile(exportDir)) as Array<string>
    const opmlFiles: Array<string> = []
    for (const fileName of files) {
      if (fileName.toLowerCase().endsWith('.opml')) {
        opmlFiles.push(fileName)
      }
    }
    if (opmlFiles.length === 0) {
      throw new Error('未找到可导入的 .opml 文件')
    }
    // 取最近修改的文件
    let latestPath = ''
    let latestMtime = 0
    for (const name of opmlFiles) {
      const path = `${exportDir}/${name}`
      const stat = await fs.stat(path)
      if (stat.mtime > latestMtime) {
        latestMtime = stat.mtime
        latestPath = path
      }
    }

    const content = await OPMLService.readTextFile(latestPath)
    await OPMLService.parseAndSaveOpml(content)
  }

  private static async readTextFile(path: string): Promise<string> {
    const stat = await fs.stat(path);
    const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
    const buffer = new ArrayBuffer(stat.size);
    const u8 = new Uint8Array(buffer);
    fs.readSync(file.fd, u8);
    fs.closeSync(file.fd);
    const decoder = new util.TextDecoder('utf-8');
    return decoder.decode(u8);
  }

  /**
   * 解析 OPML 字符串并保存到数据库
   */
  private static async parseAndSaveOpml(content: string): Promise<void> {
    const lines: Array<string> = content.split(/\r?\n/)
    const folderStack: Array<number | null> = []
    for (let rawLine of lines) {
      const line = rawLine.trim()
      if (!line.startsWith('<outline')) {
        if (line.startsWith('</outline')) {
          // 结束一个文件夹
          folderStack.pop()
        }
        continue
      }

      const xmlUrlMatch = line.match(/xmlUrl="([^"]+)"/i)
      if (xmlUrlMatch) {
        // 这是订阅
        const url = xmlUrlMatch[1]
        let title = ''
        const titleMatch = line.match(/title="([^"]+)"/i)
        if (titleMatch) {
          title = titleMatch[1]
        } else {
          const textMatch = line.match(/text="([^"]+)"/i)
          title = textMatch ? textMatch[1] : url
        }

        // 检查是否已存在
        const existing = await FeedDAO.getFeedByUrl(url)
        if (existing) {
          continue
        }

        const folderId = folderStack.length > 0 ? folderStack[folderStack.length - 1] : null
        // 创建订阅
        await FeedDAO.addFeed({
          url: url,
          title: title,
          description: '',
          link: '',
          language: '',
          lastBuildDate: '',
          imageUrl: '',
          category: '导入',
          isActive: true,
          sortOrder: 999,
          folderId: folderId
        })
      } else {
        // 认为是文件夹开始
        const nameMatch = line.match(/title="([^"]+)"/i) || line.match(/text="([^"]+)"/i)
        if (nameMatch) {
          const folderName = nameMatch[1]
          // 检查重复
          const existingFolders = await FolderDAO.getAllFolders(true)
          const dup = existingFolders.find(f => f.name === folderName)
          let folderId: number
          if (dup) {
            folderId = dup.id
          } else {
            folderId = await FolderDAO.createFolder({ name: folderName })
          }
          folderStack.push(folderId)
        } else {
          folderStack.push(null)
        }
      }
    }
  }
} 