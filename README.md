# CustomerFundsManagementSystem·客户基金管理系统 · 一基暴富 

![Swift](https://img.shields.io/badge/Swift-5.0+-orange)
![Platform](https://img.shields.io/badge/Platform-iOS-blue)
![License](https://img.shields.io/badge/License-GPL%20v3-green)

这是一个简单的为基金管理设计的持仓管理工具，支持多客户基金持仓跟踪、实时净值查询、收益统计分析等功能。



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



## 项目结构

text

```
FundManagement/
├── Views/                 # 主要界面
│   ├── ContentView.swift          # 主入口和标签页
│   ├── SummaryView.swift          # 基金概览
│   ├── ClientView.swift           # 客户持仓
│   ├── TopPerformersView.swift    # 业绩排名
│   └── ConfigView.swift           # 设置页面
├── Components/            # 可复用组件
│   ├── HoldingRow.swift           # 持仓行组件
│   ├── EmptyStateView.swift       # 空状态
│   ├── ToastView.swift            # 提示组件
│   └── CardModifier.swift         # 卡片样式
├── Models/                # 数据模型
│   ├── FundModels.swift           # 基金模型
│   ├── DataManager.swift          # 数据管理
│   └── FundService.swift          # 网络服务
├── Utilities/             # 工具类
│   ├── Theme.swift                # 主题配置
│   ├── ColorExtension.swift       # 颜色扩展
│   ├── StringExtensions.swift     # 字符串扩展
│   └── PrivacyHelpers.swift       # 隐私工具
└── Resources/             # 资源文件
    └── Assets.xcassets           # 图片资源
```



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
