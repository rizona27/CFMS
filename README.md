# 客户基金管理系统 · 一基暴富(CFMS)

![Swift](https://img.shields.io/badge/Swift-5.5+-orange)
![Platform](https://img.shields.io/badge/Platform-iOS_15.0+-blue)
![License](https://img.shields.io/badge/License-GPL%20v3-green)

简单的为基金管理设计的工具，支持多客户基金持仓跟踪、实时净值查询、收益统计分析等功能。



## 📁项目结构

```

 CFMS/                          # 主应用代码目录
   ├── App/                      # 应用入口和主视图
   │   ├── CFMS.entitlements     # 应用权限配置
   │   ├── CFMSApp.swift         # 应用入口点，初始化核心服务
   │   ├── ContentView.swift     # 根视图，处理主布局和认证流程
   │   ├── CustomTabBar.swift    # 自定义TabBar导航组件
   │   └── Info/                 # 应用信息文件
   ├── Assets.xcassets/          # 资源文件目录
   │   ├── AccentColor.colorset/ # 主题颜色配置
   │   └── AppIcon.appiconset/   # 应用图标
   ├── Models/                   # 数据模型
   │   ├── DataValidation.swift  # 数据验证和错误处理
   │   ├── FundModels.swift      # 基金持仓数据模型
   │   └── TableColumn.swift     # 表格列配置模型
   ├── Services/                 # 核心服务层
   │   ├── AuthService.swift     # 用户认证服务
   │   ├── CloudSyncManager.swift # 云端数据同步管理
   │   ├── DataManager.swift     # 本地数据管理
   │   ├── FundService.swift     # 基金数据API服务
   │   └── ToastQueueManager.swift # Toast提示队列管理
   ├── Supporting/               # 支持文件
   │   └── AboutView.swift       # 关于页面视图
   ├── Utilities/                # 工具类
   │   ├── ColorExtension.swift  # 颜色扩展工具
   │   ├── PrivacyHelpers.swift  # 隐私策略工具
   │   ├── StringExtensions.swift # 字符串扩展工具
   │   └── Theme.swift           # 应用主题定义
   └── Views/                    # 视图组件
       ├── Components/           # 通用组件
       │   ├── AuthView.swift    # 用户认证视图
       │   ├── CardModifier.swift # 卡片样式修饰器
       │   ├── EmptyStateView.swift # 空状态视图
       │   ├── GradientButton.swift # 渐变按钮组件
       │   ├── HoldingRow.swift  # 持仓行组件
       │   ├── ProfileView.swift # 用户资料视图
       │   ├── RedemptionView.swift # 赎回视图
       │   └── ToastView.swift   # Toast提示组件
       ├── ConfigViews/          # 配置相关视图
       │   ├── AddHoldingView.swift # 添加持仓视图
       │   ├── APILogView.swift  # API日志视图
       │   ├── CloudSyncView.swift # 云同步视图
       │   ├── ConfigView.swift  # 设置视图
       │   ├── EditHoldingView.swift # 编辑持仓视图
       │   └── ManageHoldingsView.swift # 管理持仓视图
       └── MainViews/            # 主功能视图
           ├── ClientView.swift  # 客户视图
           ├── SummaryView.swift # 一览视图
           └── TopPerformersView.swift # 排行视图
```

- ### 📊 数据可视化与分析
- **持仓概览**: 展示基金持仓总览和收益情况
- **客户分组**: 支持客户信息管理
- **业绩排名**: 多维度排序和筛选功能
- **收益分析**: 计算收益和收益率

- ### 🔄 智能数据管理
- **实时净值更新**: 多API源获取最新净值
- **数据持久化**: 本地存储，确保数据安全
- **批量操作**: 支持批量刷和编辑持仓信息
- **云端同步**: 认证后支持数据云端备份和恢复

- ### 🛡️ 认证与安全
- **安全认证**: 验证码、登录次数等安全机制
- **会话管理**: 自动超时登出，后台时间监控
- **设备限制**: 注册频率和设备数量限制
- **隐私保护**: 信息支持脱敏显示

- ### 🎨 用户体验
- **响应式设计**: 适配不同尺寸的iOS设备
- **智能搜索**: 客户和基金模糊匹配
- **多主题支持**: 浅色、深色和自动跟随系统

- ---

**专业 · 专注 · 价值**

*CFMS - 让持仓管理更简单、更智能*
