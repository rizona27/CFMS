# 客户基金管理系统 · 一基暴富(CFMS)

![Swift](https://img.shields.io/badge/Swift-5.5+-orange)
![Platform](https://img.shields.io/badge/Platform-iOS_15.0+-blue)
![License](https://img.shields.io/badge/License-GPL%20v3-green)

简单的为基金管理设计的工具，支持多客户基金持仓跟踪、实时净值查询、收益统计分析等功能。



## 项目结构

```
CFMS/
├── CFMSApp.swift           # 应用入口文件
├── App/                    # 启动和核心配置
│   ├── Assets.xcassets     # 图片和资源
│   ├── ContentView.swift   # 主内容视图
│   ├── CustomTabBar.swift  # 自定义标签栏视图
│   └── Info.plist          # 应用信息配置
├── Models/                 # 数据模型
│   ├── DataValidation.swift    # 数据验证逻辑
│   ├── FundModels.swift        # 基金相关的数据模型
│   └── TableColumn.swift       # 表格列配置或模型
├── Services/               # 业务逻辑和数据处理服务
│   ├── DataManager.swift       # 通用数据管理/存储
│   ├── FundService.swift       # 基金相关的业务/网络服务
│   └── ToastQueueManager.swift # 提示消息队列管理服务
├── Utilities/              # 辅助工具类
│   ├── ColorExtension.swift    # 颜色扩展
│   ├── PrivacyHelpers.swift    # 隐私保护相关工具
│   ├── Theme.swift             # 主题配置
│   └── StringExtensions.swift  # 字符串扩展
├── Views/                  # 所有用户界面相关文件
│   ├── Components/             # 可复用的小组件
│   │   ├── CardModifier.swift      # 卡片样式修改器
│   │   ├── EmptyStateView.swift    # 空状态视图
│   │   ├── GradientButton.swift    # 渐变色按钮
│   │   ├── HoldingRow.swift        # 持仓行组件
│   │   └── ToastView.swift         # 提示组件
│   ├── ConfigViews/            # 配置/设置相关视图
│   │   ├── AddHoldingView.swift    # 添加持仓视图
│   │   ├── APILogView.swift        # API日志视图
│   │   ├── ConfigView.swift        # 主要设置视图
│   │   ├── EditHoldingView.swift   # 编辑持仓视图
│   │   └── ManageHoldingsView.swift# 管理持仓视图
│   └── MainViews/              # 主要功能视图
│       ├── ClientView.swift        # 客户视图/持仓
│       ├── SummaryView.swift       # 概览视图/摘要
│       └── TopPerformersView.swift # 业绩排名视图
└── Supporting/             # 支撑性视图或文件
    └── AboutView.swift         # 关于页面视图
```



### 📊 数据可视化

- **持仓概览**: 展示基金持仓情况
- **客户分组**: 按客户维度组织持仓数据
- **业绩排名**: 多维度排序和筛选功能
- **收益分析**: 实时计算收益率

### 🔄 数据管理

- **CSV导入导出**: 标准CSV数据导入导出
- **实时净值更新**: 多API获取最新净值
- **数据持久化**: 本地存储数据
- **批量操作**: 批量刷新和编辑持仓

### 🎨 用户体验

- **多主题支持**: 浅色、深色和跟随系统
- **响应式设计**: 适配不同尺寸的iOS设备
- **智能搜索**: 快速定位客户和基金

### 架构设计

- **MVVM模式**: 数据流和状态管理
- **SwiftUI**: 声明式UI框架
- **Combine**: 响应式编程
- **Async/Await**: 并发处理

### 数据层

- **多数据源**: 支持多个API数据源
- **智能缓存**: 自动缓存和过期管理
- **错误重试**: 网络请求自动重试机制
- **数据验证**: 输入验证和错误处理

### CSV导入格式

支持标准CSV格式，包含以下列：

- 客户姓名
- 基金代码 (6位数字)
- 购买金额
- 购买份额
- 购买日期 (YYYY-MM-DD)
- 客户号 (可选)
- 备注 (可选)

### 基金数据

- 实时净值查询
- 历史收益率数据
- 基金基本信息
- 自动数据更新

------

**专业 · 专注 · 价值**
