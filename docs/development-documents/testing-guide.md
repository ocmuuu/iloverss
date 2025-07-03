# 测试指南

## 测试环境
- HarmonyOS 4.0+ 设备或模拟器
- DevEco Studio 测试工具

## 测试类型
- 单元测试：DAO、服务、工具类
- 集成测试：页面与服务联动
- UI测试：界面交互与响应

## 测试流程
1. 编写测试用例（位于 entry/src/ohosTest/ets/test/）
2. 使用 DevEco Studio 运行测试
3. 查看测试报告和日志

## 常用命令
- 运行全部测试：
  ```bash
  hvigor test
  ```
- 查看测试覆盖率

## 测试报告
- 测试通过率、失败用例、覆盖率等 