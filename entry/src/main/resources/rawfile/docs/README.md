# 爱读RSS 文档中心

本目录包含爱读RSS应用的完整文档，用于在应用内展示帮助信息和软件介绍。

## 目录结构

```
docs/
├── help/                   # 帮助文档
│   ├── index.html         # 帮助首页
│   ├── getting-started.html # 快速开始指南
│   ├── features.html      # 功能介绍
│   ├── settings.html      # 设置说明
│   └── faq.html          # 常见问题
├── about/                 # 关于软件
│   ├── index.html        # 关于页面
│   ├── privacy.html      # 隐私政策
│   ├── terms.html        # 使用条款
│   └── changelog.html    # 更新日志
├── assets/               # 静态资源
│   ├── css/
│   │   └── docs.css      # 文档样式
│   ├── images/           # 图片资源
│   └── js/               # JavaScript文件
└── README.md             # 本文件
```

## 使用方法

在应用中加载文档的示例代码：

```typescript
// 读取HTML文档内容
private async loadDocument(docPath: string): Promise<string> {
  try {
    const context = getContext(this)
    const resourceMgr = context.resourceManager
    const fileData = await resourceMgr.getRawFileContent(`docs/${docPath}`)
    const decoder = util.TextDecoder.create('utf-8')
    return decoder.decodeWithStream(fileData)
  } catch (error) {
    console.error('加载文档失败:', error)
    return '<h1>文档加载失败</h1>'
  }
}

// 使用示例
const helpContent = await this.loadDocument('help/index.html')
const aboutContent = await this.loadDocument('about/index.html')
```

## 文档特性

- **响应式设计**：适配不同屏幕尺寸
- **统一样式**：使用docs.css提供一致的视觉体验
- **导航友好**：页面间相互链接，便于浏览
- **内容丰富**：涵盖应用的所有功能和使用说明
- **易于维护**：HTML格式，便于更新和修改

## 样式说明

文档使用了以下CSS类：

- `.container` - 主容器
- `.header` - 页面头部
- `.content` - 内容区域
- `.info-box` - 信息提示框
- `.feature-list` - 功能列表
- `.code-block` - 代码块
- `.nav-links` - 导航链接
- `.footer` - 页面底部

## 更新维护

当需要更新文档内容时：

1. 直接编辑对应的HTML文件
2. 如需添加新页面，请保持目录结构的一致性
3. 确保新页面引用了正确的CSS文件路径
4. 更新相关页面的导航链接

## 注意事项

- 所有文档文件使用UTF-8编码
- 图片资源放在assets/images/目录下
- CSS路径使用相对路径引用
- 保持HTML结构的一致性，便于维护 