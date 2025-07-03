# 开发环境搭建

## 系统要求
- Windows 10/11
- 建议8GB以上内存，100GB以上硬盘空间

## 工具链
- DevEco Studio 5.0+
- HarmonyOS SDK 5.0.5(17)+
- Hvigor 5.0.0
- Git

## 环境配置步骤
1. 安装 DevEco Studio 并配置 HarmonyOS SDK
2. 配置 Hvigor 构建工具
3. 克隆项目源码：
   ```bash
   git clone [项目地址]
   cd iloverss
   ```
4. 安装依赖并构建：
   ```bash
   hvigor clean
   hvigor assembleHap
   ```
5. 连接 HarmonyOS 设备或启动模拟器
6. 在 DevEco Studio 中运行和调试项目 