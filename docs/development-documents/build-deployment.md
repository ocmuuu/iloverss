# 构建部署指南

## 构建流程
1. 安装依赖：
   ```bash
   hvigor clean
   hvigor assembleHap
   ```
2. 生成 HAP 安装包
3. 在 DevEco Studio 中连接设备或模拟器
4. 运行或调试应用

## 部署方式
- 方式一：源码编译部署
- 方式二：使用预编译 HAP 包

## HAP 包安装
1. 通过 hdc 工具安装：
   ```bash
   hdc install iloverss.hap
   ```
2. 安装完成后在设备上启动应用

## 注意事项
- 确保设备已开启开发者模式
- 保证网络连接畅通 