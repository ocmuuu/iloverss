import { RSSFolder, RSSFeed, RSSDataService } from '../model/RSSModel'
import FolderDAO from '../model/FolderDAO'
import { Toast } from '../utils/Toast'

@Component
export struct RSSFolderManager {
  @State folders: RSSFolder[] = []
  @State selectedFolderId: string | null = null
  @State feedsInFolder: RSSFeed[] = []
  @State showCreateDialog: boolean = false
  @State newFolderName: string = ''
  @State newFolderDescription: string = ''
  @State newFolderColor: string = '#1890ff'

  async aboutToAppear() {
    await this.loadFolders()
  }

  /**
   * 加载所有文件夹
   */
  async loadFolders() {
    try {
      this.folders = await RSSDataService.getAllFolders()
    } catch (error) {
      Toast.show('加载文件夹失败')
    }
  }

  /**
   * 加载指定文件夹下的订阅源
   */
  async loadFeedsInFolder(folderId: string | null) {
    try {
      this.feedsInFolder = await RSSDataService.getFeedsByFolderId(folderId)
      this.selectedFolderId = folderId
    } catch (error) {
      Toast.show('加载文件夹内容失败')
    }
  }

  /**
   * 创建新文件夹
   */
  async createFolder() {
    if (!this.newFolderName.trim()) {
      Toast.show('请输入文件夹名称')
      return
    }

    try {
      const success = await RSSDataService.createFolder(
        this.newFolderName.trim(),
        this.newFolderDescription.trim(),
        this.newFolderColor
      )
      
      if (success) {
        Toast.show('文件夹创建成功')
        this.showCreateDialog = false
        this.newFolderName = ''
        this.newFolderDescription = ''
        this.newFolderColor = '#1890ff'
        await this.loadFolders()
      } else {
        Toast.show('文件夹创建失败')
      }
    } catch (error) {
      Toast.show('文件夹创建失败')
    }
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('文件夹管理')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .flexGrow(1)

        Button('新建文件夹')
          .fontSize(14)
          .backgroundColor('#1890ff')
          .onClick(() => {
            this.showCreateDialog = true
          })
      }
      .width('100%')
      .padding(16)
      .justifyContent(FlexAlign.SpaceBetween)

      Divider()

      // 文件夹列表
      List() {
        // 未分类项
        ListItem() {
          Row() {
            Image($r('app.media.rss'))
              .width(20)
              .height(20)
              .margin({ right: 12 })

            Column() {
              Text('未分类')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
              Text('未归类的订阅源')
                .fontSize(12)
                .fontColor('#666')
                .margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Start)
            .flexGrow(1)

            Text('点击查看')
              .fontSize(12)
              .fontColor('#999')
          }
          .width('100%')
          .padding(12)
          .backgroundColor(this.selectedFolderId === null ? '#f0f0f0' : '#fff')
        }
        .onClick(() => {
          this.loadFeedsInFolder(null)
        })

        // 文件夹列表
        ForEach(this.folders, (folder: RSSFolder) => {
          ListItem() {
            Row() {
              // 文件夹图标
              Text('📁')
                .fontSize(20)
                .margin({ right: 12 })

              Column() {
                Text(folder.name)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                
                Text(`${folder.feedCount} 个订阅源`)
                  .fontSize(12)
                  .fontColor('#666')
                  .margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Start)
              .flexGrow(1)

              Column() {
                if (folder.unreadCount > 0) {
                  Text(folder.unreadCount.toString())
                    .fontSize(12)
                    .fontColor('#fff')
                    .backgroundColor('#ff4d4f')
                    .borderRadius(10)
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                }
              }
            }
            .width('100%')
            .padding(12)
            .backgroundColor(this.selectedFolderId === folder.id ? '#f0f0f0' : '#fff')
          }
          .onClick(() => {
            this.loadFeedsInFolder(folder.id)
          })
        }, (folder: RSSFolder) => folder.id)
      }
      .divider({ strokeWidth: 1, color: '#f0f0f0' })
      .flexGrow(1)

      // 选中文件夹的内容
      if (this.selectedFolderId !== null || this.feedsInFolder.length > 0) {
        Divider()
        
        Column() {
          Text(this.selectedFolderId === null ? '未分类订阅源' : '文件夹内容')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .margin({ bottom: 8 })

          if (this.feedsInFolder.length === 0) {
            Text('暂无订阅源')
              .fontSize(14)
              .fontColor('#999')
              .textAlign(TextAlign.Center)
          } else {
            List() {
              ForEach(this.feedsInFolder, (feed: RSSFeed) => {
                ListItem() {
                  Row() {
                    Image(feed.favicon)
                      .width(20)
                      .height(20)
                      .margin({ right: 8 })

                    Column() {
                      Text(feed.title)
                        .fontSize(14)
                        .fontWeight(FontWeight.Medium)
                      Text(feed.description)
                        .fontSize(12)
                        .fontColor('#666')
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                    }
                    .alignItems(HorizontalAlign.Start)
                    .flexGrow(1)

                    if (feed.unreadCount > 0) {
                      Text(feed.unreadCount.toString())
                        .fontSize(12)
                        .fontColor('#fff')
                        .backgroundColor('#1890ff')
                        .borderRadius(10)
                        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                    }
                  }
                  .width('100%')
                  .padding(8)
                }
              }, (feed: RSSFeed) => feed.id)
            }
            .height(200)
          }
        }
        .padding(16)
        .alignItems(HorizontalAlign.Start)
      }
    }
    .height('100%')
    .backgroundColor('#fff')
    .bindSheet($$this.showCreateDialog, this.CreateFolderDialog(), {
      height: 300,
      dragBar: true
    })
  }

  @Builder CreateFolderDialog() {
    Column() {
      Text('创建新文件夹')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 20 })

      TextInput({ placeholder: '文件夹名称' })
        .onChange((value: string) => {
          this.newFolderName = value
        })
        .margin({ bottom: 12 })

      TextInput({ placeholder: '文件夹描述（可选）' })
        .onChange((value: string) => {
          this.newFolderDescription = value
        })
        .margin({ bottom: 12 })

      Row() {
        Text('颜色:')
          .fontSize(14)
          .margin({ right: 8 })

        ForEach(['#1890ff', '#52c41a', '#faad14', '#f5222d', '#722ed1'], (color: string) => {
          Button()
            .width(20)
            .height(20)
            .backgroundColor(color)
            .margin({ right: 8 })
            .borderRadius(10)
            .border({ width: this.newFolderColor === color ? 2 : 0, color: '#000' })
            .onClick(() => {
              this.newFolderColor = color
            })
        })
      }
      .margin({ bottom: 20 })

      Row() {
        Button('取消')
          .flexGrow(1)
          .backgroundColor('#f0f0f0')
          .fontColor('#000')
          .margin({ right: 8 })
          .onClick(() => {
            this.showCreateDialog = false
          })

        Button('创建')
          .flexGrow(1)
          .backgroundColor('#1890ff')
          .onClick(() => {
            this.createFolder()
          })
      }
    }
    .padding(20)
    .alignItems(HorizontalAlign.Start)
  }
} 