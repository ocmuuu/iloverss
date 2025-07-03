# 代码结构说明

## 目录结构

```
iloverss/
├── AppScope/                 # 应用级配置
├── entry/                    # 主模块
│   ├── src/main/ets/        # 主要源代码
│   │   ├── component/       # UI组件
│   │   ├── entryability/    # 应用入口
│   │   ├── model/          # 数据模型
│   │   ├── pages/          # 页面
│   │   ├── service/        # 业务服务
│   │   └── utils/          # 工具类
│   └── src/ohosTest/       # 测试代码
├── docs/                    # 项目文档
└── build-profile.json5     # 构建配置
```

## 主要模块说明
- **component/**：UI组件，负责界面展示和交互
- **entryability/**：应用入口，生命周期管理
- **model/**：数据模型和DAO
- **pages/**：页面入口和路由
- **service/**：业务逻辑和服务
- **utils/**：工具类和通用方法
- **ohosTest/**：单元测试和集成测试 