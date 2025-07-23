import { FolderDAO } from '../model/FolderDAO';
import { FeedDAO } from '../model/FeedDAO';
import RSSRefreshService from '../service/RSSRefreshService';
import fs from '@ohos.file.fs';
import fileio from '@ohos.fileio';
import { common } from '@kit.AbilityKit';
import util from '@ohos.util';
import picker from '@ohos.file.picker';

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
   * 使用文件选择器保存OPML文件，让用户选择保存位置
   * 返回保存的文件路径，如果用户取消则抛出错误
   */
  static async saveOpmlFileWithPicker(content: string, context: common.UIAbilityContext): Promise<string> {
    try {
      // 创建文档保存选择器
      const documentPicker = new picker.DocumentViewPicker(context);
      const documentSaveOptions = new picker.DocumentSaveOptions();
      
      // 设置默认文件名
      const timestamp = new Date().toISOString().slice(0, 19).replace(/:/g, '-');
      documentSaveOptions.newFileNames = [`订阅源备份_${timestamp}.opml`];
      
      // 弹出保存对话框
      const result = await documentPicker.save(documentSaveOptions);
      
      if (!result || result.length === 0) {
        throw new Error('用户取消了保存操作');
      }
      
      const filePath = result[0];
      
      // 保存文件内容
      const file = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY);
      const encoder = new util.TextEncoder('utf-8');
      const data = encoder.encode(content);
      fs.writeSync(file.fd, data.buffer);
      fs.closeSync(file.fd);
      
      return filePath;
    } catch (error) {
      if (error instanceof Error) {
        throw error;
      } else {
        throw new Error(`保存OPML文件失败: ${error}`);
      }
    }
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
    const newFeedIds = await OPMLService.parseAndSaveOpml(content)
    // 刷新新增的订阅源（逐个刷新）
    for (const id of newFeedIds) {
      try {
        await RSSRefreshService.refreshSingleFeed(id);
      } catch (_) {
        // 忽略单个失败
      }
    }
  }

  /**
   * 使用文件选择器导入OPML文件，让用户选择导入的文件
   */
  static async importOpmlWithPicker(context: common.UIAbilityContext): Promise<void> {
    try {
      // 创建文档选择器
      const documentPicker = new picker.DocumentViewPicker(context);
      const documentSelectOptions = new picker.DocumentSelectOptions();
      
      // 设置文件过滤器，只显示opml文件
      documentSelectOptions.maxSelectNumber = 1;
      documentSelectOptions.fileSuffixFilters = ['OPML文件|.opml'];
      
      // 弹出选择对话框
      const result = await documentPicker.select(documentSelectOptions);
      
      if (!result || result.length === 0) {
        throw new Error('用户取消了导入操作');
      }
      
      const srcUri = result[0];
      console.info('OPMLService', `选择的文件路径: ${srcUri}`);

      // 复制到应用私有目录（使用 fs 流复制）
      const dstPath = `${context.filesDir}/opml_import_${Date.now()}.opml`;
      try {
        let srcPath: string = srcUri;
        let srcFile: fs.File | null = null;
        try {
          srcFile = fs.openSync(srcPath, fs.OpenMode.READ_ONLY);
        } catch (_) {
          // 若失败，去掉 file:// 前缀再试一次
          if (srcUri.startsWith('file://')) {
            srcPath = srcUri.replace(/^file:\/\//, '/');
            srcFile = fs.openSync(srcPath, fs.OpenMode.READ_ONLY);
          } else {
            throw new Error('无法访问选择的文件');
          }
        }
        const srcStat = await fs.stat(srcFile.fd);
        const buf = new ArrayBuffer(srcStat.size);
        await fs.read(srcFile.fd, buf);
        fs.closeSync(srcFile);

        const dstFile = fs.openSync(dstPath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
        await fs.write(dstFile.fd, buf);
        fs.closeSync(dstFile);

        console.info('OPMLService', `已复制到内部路径: ${dstPath}`);

        // 读取并解析
        const content = await OPMLService.readTextFile(dstPath);
        console.info('OPMLService', `文件读取成功，内容长度: ${content.length}`);
        const newFeedIds = await OPMLService.parseAndSaveOpml(content);
        console.info('OPMLService', 'OPML解析完成');
        // 刷新新增的订阅源
        for (const id of newFeedIds) {
          try {
            await RSSRefreshService.refreshSingleFeed(id);
          } catch (_) {}
        }
      } catch (fileError) {
        console.error('OPMLService', `文件处理错误: ${fileError}`);
        if (fileError instanceof Error) {
          throw fileError;
        } else {
          throw new Error(String(fileError));
        }
      }
    } catch (error) {
      if (error instanceof Error) {
        // 为常见错误提供更友好的提示
        let errorMessage = error.message;
        
        if (errorMessage.includes('Permission denied') || errorMessage.includes('权限')) {
          errorMessage = '文件访问权限不足，请检查文件权限';
        } else if (errorMessage.includes('No such file') || errorMessage.includes('文件不存在')) {
          errorMessage = '选择的文件不存在或已被删除';
        } else if (errorMessage.includes('不是有效的OPML文件')) {
          errorMessage = `${errorMessage}。请确保选择的是正确的OPML格式文件`;
        } else if (errorMessage.includes('文件内容为空')) {
          errorMessage = '选择的文件是空文件，请选择包含OPML数据的文件';
        } else if (errorMessage.includes('没有找到任何订阅源信息')) {
          errorMessage = '该OPML文件中没有包含有效的RSS订阅源信息';
        }
        
        throw new Error(errorMessage);
      } else {
        throw new Error(`导入OPML文件失败: ${error}`);
      }
    }
  }

  private static async readTextFile(uri: string): Promise<string> {
    try {
      console.info('OPMLService', `准备读取文件: ${uri}`);

      let realUri = uri;
      if (uri.startsWith('file://')) {
        realUri = uri.replace(/^file:\/\//, '/');
      }

      // 使用 fileio.readText 直接读取
      let content: string;
      try {
        content = await fileio.readText(realUri, 'utf-8');
      } catch (_) {
        throw new Error('无法读取文件，请检查权限');
      }

      if (!content || content.length === 0) {
        throw new Error('文件内容为空');
      }

      // 10MB大小限制
      if (content.length > 10 * 1024 * 1024) {
        throw new Error('文件过大，请选择小于10MB的OPML文件');
      }
 
      if (!content.trim()) {
        throw new Error('文件内容为空或无法读取');
      }
      return content;
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      throw new Error(`读取文件失败: ${msg}`);
    }
  }

  /**
   * 验证OPML文件格式
   */
  private static validateOpmlFormat(content: string): void {
    if (!content || content.trim().length === 0) {
      throw new Error('文件内容为空')
    }

    // 检查基本的OPML结构
    const normalizedContent = content.toLowerCase()
    
    if (!normalizedContent.includes('<opml')) {
      throw new Error('不是有效的OPML文件：缺少<opml>标签')
    }
    
    if (!normalizedContent.includes('<head>') && !normalizedContent.includes('<head ')) {
      throw new Error('不是有效的OPML文件：缺少<head>标签')
    }
    
    if (!normalizedContent.includes('<body>') && !normalizedContent.includes('<body ')) {
      throw new Error('不是有效的OPML文件：缺少<body>标签')
    }
    
    if (!normalizedContent.includes('<outline')) {
      throw new Error('OPML文件中没有找到任何订阅源信息')
    }
  }

  /**
   * 解析 OPML 字符串并保存到数据库
   */
  private static async parseAndSaveOpml(content: string): Promise<number[]> {
    // 首先验证OPML格式
    OPMLService.validateOpmlFormat(content)
    
    const lines: Array<string> = content.split(/\r?\n/)
    const folderStack: Array<number | null> = []
    let feedCount = 0
    let folderCount = 0
    const newFeedIds: number[] = []
    
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
        // 这是RSS订阅源
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
        const newId: number = await FeedDAO.addFeed({
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
        feedCount++
        newFeedIds.push(newId)
      } else {
        // 这是文件夹
        const nameMatch = line.match(/title="([^"]+)"/i) || line.match(/text="([^"]+)"/i)
        if (nameMatch) {
          const folderName = nameMatch[1]
          
          // 检查是否是自闭合标签（空文件夹）
          const isSelfClosing = line.endsWith('/>') || line.endsWith('/>')
          
          // 检查重复
          const existingFolders = await FolderDAO.getAllFolders(true)
          const dup = existingFolders.find(f => f.name === folderName)
          let folderId: number
          if (dup) {
            folderId = dup.id
          } else {
            folderId = await FolderDAO.createFolder({ name: folderName })
            folderCount++
          }
          
          // 如果不是自闭合标签，则压入文件夹栈等待后续内容
          if (!isSelfClosing) {
            folderStack.push(folderId)
          }
          // 如果是自闭合标签，则这是一个空文件夹，不需要压栈
        }
      }
    }
    
    // 验证导入结果
    if (feedCount === 0 && folderCount === 0) {
      throw new Error('OPML文件解析完成，但没有找到有效的订阅源或文件夹')
    }
    return newFeedIds;
  }
} 