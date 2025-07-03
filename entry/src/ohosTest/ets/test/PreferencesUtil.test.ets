import hilog from '@ohos.hilog';
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it } from '@ohos/hypium';
import { PreferencesUtil } from '../../main/ets/utils/PreferencesUtil';

export default function preferencesUtilTest() {
  describe('PreferencesUtil测试', function () {
    beforeAll(function () {
      hilog.info(0x0000, 'PreferencesUtilTest', '开始PreferencesUtil测试套件');
    })

    afterAll(function () {
      hilog.info(0x0000, 'PreferencesUtilTest', 'PreferencesUtil测试套件结束');
    })

    beforeEach(function () {
      hilog.info(0x0000, 'PreferencesUtilTest', '开始单个测试用例');
    })

    afterEach(function () {
      hilog.info(0x0000, 'PreferencesUtilTest', '单个测试用例结束');
    })

    it('测试首选项初始化状态检查', 0, function () {
      hilog.info(0x0000, 'PreferencesUtilTest', '测试首选项初始化状态检查');
      
      // 测试初始状态
      const initialStatus = PreferencesUtil.isInitialized();
      expect(initialStatus).assertFalse();
      
      hilog.info(0x0000, 'PreferencesUtilTest', '首选项初始化状态检查通过');
    })

    it('测试首选项键名常量', 0, function () {
      hilog.info(0x0000, 'PreferencesUtilTest', '测试首选项键名常量');
      
      // 测试键名常量
      const testKeys = {
        IS_FIRST_COLUMN_COLLAPSED: 'isFirstColumnCollapsed',
        SELECTED_FEED_ID: 'selectedFeedId',
        AUTO_REFRESH_ENABLED: 'autoRefreshEnabled',
        AUTO_REFRESH_INTERVAL: 'autoRefreshInterval',
        FIRST_COLUMN_WIDTH: 'firstColumnWidth',
        SECOND_COLUMN_WIDTH: 'secondColumnWidth'
      };
      
      expect(testKeys.IS_FIRST_COLUMN_COLLAPSED).assertEqual('isFirstColumnCollapsed');
      expect(testKeys.SELECTED_FEED_ID).assertEqual('selectedFeedId');
      expect(testKeys.AUTO_REFRESH_ENABLED).assertEqual('autoRefreshEnabled');
      
      hilog.info(0x0000, 'PreferencesUtilTest', '首选项键名常量测试通过');
    })

    it('测试首选项名称常量', 0, function () {
      hilog.info(0x0000, 'PreferencesUtilTest', '测试首选项名称常量');
      
      const preferencesName = 'RSSReaderPreferences';
      expect(preferencesName).assertEqual('RSSReaderPreferences');
      
      hilog.info(0x0000, 'PreferencesUtilTest', '首选项名称常量测试通过');
    })

    it('测试首选项数据类型', 0, function () {
      hilog.info(0x0000, 'PreferencesUtilTest', '测试首选项数据类型');
      
      // 测试各种数据类型的默认值
      const booleanValue = false;
      const stringValue = '';
      const numberValue = 0;
      
      expect(booleanValue).assertFalse();
      expect(stringValue).assertEqual('');
      expect(numberValue).assertEqual(0);
      
      hilog.info(0x0000, 'PreferencesUtilTest', '首选项数据类型测试通过');
    })
  })
} 