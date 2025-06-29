import abilityTest from './Ability.test'
import databaseManagerTest from './DatabaseManager.test'
import preferencesUtilTest from './PreferencesUtil.test'
import feedParserTest from './FeedParser.test'
import rssServiceTest from './RSSService.test'
import feedDAOTest from './FeedDAO.test'
import articleDAOTest from './ArticleDAO.test'
import utilsTest from './Utils.test'
import integrationTest from './Integration.test'

export default function testsuite() {
  // 基础功能测试
  abilityTest()
  
  // 数据层测试
  databaseManagerTest()
  feedDAOTest()
  articleDAOTest()
  
  // 服务层测试
  rssServiceTest()
  
  // 工具类测试
  preferencesUtilTest()
  feedParserTest()
  utilsTest()
  
  // 集成测试
  integrationTest()
}