import hilog from '@ohos.hilog';
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it } from '@ohos/hypium';
import { FeedParser } from '../../main/ets/utils/feed/FeedParser';
import { ParserData } from '../../main/ets/utils/feed/ParserData';
import { FeedType } from '../../main/ets/utils/feed/FeedType';

export default function feedParserTest() {
  describe('FeedParser测试', function () {
    beforeAll(function () {
      hilog.info(0x0000, 'FeedParserTest', '开始FeedParser测试套件');
    })

    afterAll(function () {
      hilog.info(0x0000, 'FeedParserTest', 'FeedParser测试套件结束');
    })

    beforeEach(function () {
      hilog.info(0x0000, 'FeedParserTest', '开始单个测试用例');
    })

    afterEach(function () {
      hilog.info(0x0000, 'FeedParserTest', '单个测试用例结束');
    })

    it('测试RSS Feed类型检测', 0, function () {
      hilog.info(0x0000, 'FeedParserTest', '测试RSS Feed类型检测');
      
      const rssXml = `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>测试RSS源</title>
    <description>这是一个测试RSS源</description>
    <link>https://example.com</link>
  </channel>
</rss>`;
      
      const parserData = ParserData.create(rssXml, 'https://example.com/rss');
      const feedType = FeedParser.getFeedType(parserData);
      
      expect(feedType).assertEqual(FeedType.RSS);
      
      hilog.info(0x0000, 'FeedParserTest', 'RSS Feed类型检测测试通过');
    })

    it('测试Atom Feed类型检测', 0, function () {
      hilog.info(0x0000, 'FeedParserTest', '测试Atom Feed类型检测');
      
      const atomXml = `<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>测试Atom源</title>
  <subtitle>这是一个测试Atom源</subtitle>
  <link href="https://example.com"/>
</feed>`;
      
      const parserData = ParserData.create(atomXml, 'https://example.com/atom');
      const feedType = FeedParser.getFeedType(parserData);
      
      expect(feedType).assertEqual(FeedType.Atom);
      
      hilog.info(0x0000, 'FeedParserTest', 'Atom Feed类型检测测试通过');
    })

    it('测试JSON Feed类型检测', 0, function () {
      hilog.info(0x0000, 'FeedParserTest', '测试JSON Feed类型检测');
      
      const jsonFeed = `{
        "version": "https://jsonfeed.org/version/1.1",
        "title": "测试JSON Feed",
        "description": "这是一个测试JSON Feed",
        "home_page_url": "https://example.com"
      }`;
      
      const parserData = ParserData.create(jsonFeed, 'https://example.com/feed.json');
      const feedType = FeedParser.getFeedType(parserData);
      
      expect(feedType).assertEqual(FeedType.JSONFeed);
      
      hilog.info(0x0000, 'FeedParserTest', 'JSON Feed类型检测测试通过');
    })

    it('测试无效Feed类型检测', 0, function () {
      hilog.info(0x0000, 'FeedParserTest', '测试无效Feed类型检测');
      
      const invalidContent = '这不是一个有效的Feed内容';
      const parserData = ParserData.create(invalidContent, 'https://example.com/invalid');
      const feedType = FeedParser.getFeedType(parserData);
      
      expect(feedType).assertEqual(FeedType.Unknown);
      
      hilog.info(0x0000, 'FeedParserTest', '无效Feed类型检测测试通过');
    })

    it('测试Feed有效性检查', 0, function () {
      hilog.info(0x0000, 'FeedParserTest', '测试Feed有效性检查');
      
      const validRss = `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>有效RSS源</title>
  </channel>
</rss>`;
      
      const invalidContent = '无效内容';
      
      const validParserData = ParserData.create(validRss, 'https://example.com/valid');
      const invalidParserData = ParserData.create(invalidContent, 'https://example.com/invalid');
      
      const isValidFeed = FeedParser.isValidFeed(validParserData);
      const isInvalidFeed = FeedParser.isValidFeed(invalidParserData);
      
      expect(isValidFeed).assertTrue();
      expect(isInvalidFeed).assertFalse();
      
      hilog.info(0x0000, 'FeedParserTest', 'Feed有效性检查测试通过');
    })

    it('测试Feed解析能力检查', 0, function () {
      hilog.info(0x0000, 'FeedParserTest', '测试Feed解析能力检查');
      
      const rssXml = `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>可解析的RSS源</title>
  </channel>
</rss>`;
      
      const invalidContent = '不可解析的内容';
      
      const parseableData = ParserData.create(rssXml, 'https://example.com/parseable');
      const unparseableData = ParserData.create(invalidContent, 'https://example.com/unparseable');
      
      const canParseValid = FeedParser.canParse(parseableData);
      const canParseInvalid = FeedParser.canParse(unparseableData);
      
      expect(canParseValid).assertTrue();
      expect(canParseInvalid).assertFalse();
      
      hilog.info(0x0000, 'FeedParserTest', 'Feed解析能力检查测试通过');
    })
  })
} 