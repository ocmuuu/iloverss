import UIAbility from '@ohos.app.ability.UIAbility';
import hilog from '@ohos.hilog';
import window from '@ohos.window';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import Want from '@ohos.app.ability.Want';
import PreferencesUtil from '../utils/PreferencesUtil';
import { DatabaseManager } from '../model/DatabaseManager';
import RSSRefreshService from '../service/RSSRefreshService';
import { ImageCacheService } from '../service/ImageCacheService';
import { GlobalState } from '../model/GlobalState';
import type common from '@ohos.app.ability.common';

/**
 * 入口Ability
 */
export default class EntryAbility extends UIAbility {
  private mainWindow: window.Window | null = null;
  private refreshService: RSSRefreshService | null = null;
  private isInitialized: boolean = false;

  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onCreate');
    
    try {
      // 初始化数据库
      const dbInitialized = await DatabaseManager.init(this.context);
      if (dbInitialized) {
        hilog.info(0x0000, 'testTag', 'DatabaseManager initialized successfully');

        // 验证默认RSS源是否已插入
        try {
            const store = DatabaseManager.getStore();
           if (store) {
             const result = await store.querySql('SELECT COUNT(*) as count FROM feeds');
             let feedCount = 0;
             if (result.rowCount > 0) {
               result.goToFirstRow();
               feedCount = result.getLong(0);
             }
             result.close();
            
              if (feedCount > 0) {
               // 查询具体的RSS源信息
               const feedsResult = await store.querySql('SELECT id, title, url FROM feeds');
               let feedInfo = '';
               if (feedsResult.rowCount > 0) {
                 feedsResult.goToFirstRow();
                 do {
                   const id = feedsResult.getLong(0);
                   const title = feedsResult.getString(1);
                   const url = feedsResult.getString(2);
                   feedInfo += `[${id}] ${title} (${url}); `;
                 } while (feedsResult.goToNextRow());
               }
               feedsResult.close();
             }
          }
        } catch (error) {
          hilog.error(0x0000, 'testTag', '验证数据库数据失败: %{public}s', JSON.stringify(error) ?? '');
        }
      } else {
        hilog.error(0x0000, 'testTag', 'Failed to initialize DatabaseManager');
      }

      // 初始化首选项
      await PreferencesUtil.init(this.context);
      hilog.info(0x0000, 'testTag', 'PreferencesUtil initialized successfully');

      // 初始化RSS刷新服务（会自动执行首次刷新和启动定时刷新）
      this.refreshService = new RSSRefreshService();
      RSSRefreshService.initialize();
      hilog.info(0x0000, 'testTag', 'RSSRefreshService initialized successfully');

      // 清理过期图片缓存（仅在应用启动时执行）
      try {
        const retentionDays = 30 // 保留30天
        const maxAgeMs = retentionDays * 24 * 60 * 60 * 1000
        hilog.info(0x0000, 'testTag', `开始清理过期图片缓存，保留期: ${retentionDays}天`)
        ImageCacheService.cleanupOldImages(this.context, maxAgeMs)
        hilog.info(0x0000, 'testTag', '图片缓存清理任务已启动')
      } catch (error) {
        hilog.warn(0x0000, 'testTag', '清理过期图片缓存失败: %{public}s', JSON.stringify(error) ?? '')
      }

      // 初始化全局状态管理
      try {
        GlobalState.init()
        hilog.info(0x0000, 'testTag', 'GlobalState initialized successfully')
      } catch (error) {
        hilog.error(0x0000, 'testTag', '初始化全局状态管理失败: %{public}s', JSON.stringify(error) ?? '')
      }
      
      // 标记初始化完成
      this.isInitialized = true;
      
    } catch (error) {
      if (error instanceof Error) {
            hilog.error(0x0000, 'testTag', 'Ability onCreate error: %{public}s', error.message);
  } else {
    hilog.error(0x0000, 'testTag', 'Ability onCreate error: %{public}s', String(error));
  }
    }
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    try {
      // 等待初始化完成
      let retryCount = 0;
      const maxRetries = 30;
      while (!this.isInitialized && retryCount < maxRetries) {
        await new Promise<void>(resolve => setTimeout(resolve, 200));
        retryCount++;
      }
      
      if (!this.isInitialized) {
        console.error('EntryAbility', '初始化超时，继续加载UI');
      } else {
      }

      // 获取主窗口
      this.mainWindow = await windowStage.getMainWindow();

      // 加载主页面
      if (this.mainWindow) {
        await this.mainWindow.setUIContent('pages/Index');
        await this.mainWindow.showWindow();
      }
    } catch (error) {
      if (error instanceof Error) {
              hilog.error(0x0000, 'testTag', 'Ability onWindowStageCreate error: %{public}s', error.message);
    } else {
      hilog.error(0x0000, 'testTag', 'Ability onWindowStageCreate error: %{public}s', String(error));
    }
    }
  }

  onWindowStageDestroy(): void {
    try {
      // 清理窗口
      this.mainWindow = null;
    } catch (error) {
      if (error instanceof Error) {
              hilog.error(0x0000, 'testTag', 'Ability onWindowStageDestroy error: %{public}s', error.message);
    } else {
      hilog.error(0x0000, 'testTag', 'Ability onWindowStageDestroy error: %{public}s', String(error));
    }
    }
  }

  onDestroy(): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onDestroy');
    
    try {
      // 清理数据库连接
      DatabaseManager.cleanup();
      
      // 清理刷新服务
      if (this.refreshService) {
        RSSRefreshService.cleanup();
        this.refreshService = null;
      }
    } catch (error) {
      if (error instanceof Error) {
              hilog.error(0x0000, 'testTag', 'Ability onDestroy error: %{public}s', error.message);
    } else {
      hilog.error(0x0000, 'testTag', 'Ability onDestroy error: %{public}s', String(error));
    }
    }
  }

  onForeground(): void {
    try {
      // 应用进入前台
      if (this.refreshService) {
        RSSRefreshService.startAutoRefresh();
      }
    } catch (error) {
      if (error instanceof Error) {
              hilog.error(0x0000, 'testTag', 'Ability onForeground error: %{public}s', error.message);
    } else {
      hilog.error(0x0000, 'testTag', 'Ability onForeground error: %{public}s', String(error));
    }
    }
  }

  onBackground(): void {
    try {
      // 应用进入后台
      if (this.refreshService) {
        RSSRefreshService.stopAutoRefresh();
      }
    } catch (error) {
      if (error instanceof Error) {
              hilog.error(0x0000, 'testTag', 'Ability onBackground error: %{public}s', error.message);
    } else {
      hilog.error(0x0000, 'testTag', 'Ability onBackground error: %{public}s', String(error));
    }
    }
  }
}
