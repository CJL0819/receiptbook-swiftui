# 小票收纳（SwiftUI 版）

把「小票收纳」用 **Swift + SwiftUI** 重写。产品定位是「票据/票根**收藏夹**」而非纯记账本：**金额可空**——留空即「纪念收藏」（票根、门票、纪念小票、机票等，只收藏不记账），有金额才计入账与统计。

## 功能

- **记账**：有金额的票据列表，搜索、滑动删除、批量删除、CSV 导出；点分类/日期看子集。
- **收藏**：无金额的纪念票据独立成 Tab，网格卡片展示，标签筛选，带地点/心情/标签。
- **扫描 / 编辑**：SwiftUI 表单 + `VNDocumentCameraViewController` 桥接扫描，Vision OCR 自动填金额/商家/日期；金额留空即进入收藏；详情页可编辑、可分享。
- **统计**：仅计入有金额的票据；支持月/年切换；本月/本年支出、日均、笔数、柱状图、分类/日期汇总，并显示收藏张数。
- **票据图片**：详情页点击可全屏缩放。
- **票据类型**：发票 / 小票 / 机票 / 收费条 / 门票 / 票根 / 其他。
- **iCloud 云端备份**：一键备份到 iCloud Drive（含图片/仅数据两种），换机或误删可恢复。
- **桌面小组件**：主屏幕小组件显示本月支出与收藏概览（WidgetKit）。
- **旅行导图（原型）**：iOS 17 SwiftUI `Map` 分天路线 + 编号标记 + 相机动画 + 时间轴联动（详见 `docs/travel-map-design.md`）。

## 文件结构

| 文件 | 职责 |
|---|---|
| `ReceiptBookApp.swift` | `@main` 入口（SwiftUI `App` 生命周期） |
| `RootView.swift` | 四 Tab（记账 / 收藏 / 统计 / 旅行）+ 悬浮「+」 |
| `Receipt.swift` | `ReceiptType` + `Mood` + `Receipt` struct（Codable，兼容旧 JSON） |
| `ReceiptStore.swift` | `ObservableObject` 单例存储 + 缩略图缓存 + 备份恢复 |
| `ReceiptOCR.swift` | Vision OCR 抽取金额/商家/日期 |
| `ReceiptListView.swift` | 记账列表（含 `ReceiptRow`） |
| `CollectionView.swift` | 收藏夹网格（含 `CollectionCard`） |
| `ReceiptDetailView.swift` | 票据详情 + 编辑 + 分享 + 删除 |
| `AddReceiptView.swift` | 添加/编辑表单 + 扫描 + OCR + 收藏字段 |
| `DocumentScanner.swift` | `VNDocumentCameraViewController` 的 SwiftUI 桥接 |
| `StatsView.swift` | 统计页（月/年，含 `CategoryRow` / `DayRow`） |
| `DailyBarChartView.swift` | 纯 SwiftUI 柱状图 |
| `CSVExport.swift` | CSV 导出 + 分享面板 |
| `FullScreenImageView.swift` | 大图缩放查看器 |
| `BackupService.swift` | iCloud 备份/恢复（单文件、图片内嵌） |
| `BackupView.swift` | 备份与恢复界面 |
| `DocumentPickers.swift` | 文件导出/导入桥接（`UIDocumentPickerViewController`） |
| `Formatters.swift` | 金额格式化（千分位） |
| `WidgetBridge.swift` | 主 App → 小组件共享数据桥接 |
| `TravelModels.swift` | 旅行数据模型 + 示例数据 |
| `TravelMapView.swift` | 旅行导图（分天路线 + 时间轴联动） |
| `Widget/ReceiptWidget.swift` | 桌面小组件（WidgetKit，独立 Extension） |
| `project.yml` | XcodeGen 工程描述 |
| `Entitlements/` | App Group 权限（主 App + 小组件） |

## 技术栈

- **UI**：SwiftUI（iOS 17+）
- **状态管理**：Combine（`ObservableObject` / `@Published` / `@EnvironmentObject`）
- **扫描 / OCR**：VisionKit（`VNDocumentCameraViewController`）+ Vision（`VNRecognizeTextRequest`）
- **地图**：MapKit（`Map` / `MapPolyline` / `MapCameraPosition`）
- **云端备份**：iCloud Drive / 文件 App（`UIDocumentPickerViewController` + `UniformTypeIdentifiers`）
- **桌面小组件**：WidgetKit + App Group
- **存储**：本地 JSON 索引 + JPEG 图片（Documents）

## 构建（Xcode · iOS 17+）

**方式一：XcodeGen（一条命令生成工程，推荐）**

1. 安装 XcodeGen：`brew install xcodegen`
2. 项目根目录执行：`xcodegen generate`
3. 打开生成的 `ReceiptBook.xcodeproj` → 选签名团队 → 运行。

**方式二：手动创建工程**

1. Xcode → New → iOS App（SwiftUI，名称 `ReceiptBook`，Bundle ID `com.receiptbook`，Deployment Target **17.0**）。
2. 把 `Sources/` 下所有 `.swift` 拖进主 target。
3. 新建 Widget Extension target（File → New → Target → Widget Extension），把 `Widget/ReceiptWidget.swift` 加进去。
4. 主 App 与 Widget 的 Signing & Capabilities 都开 **App Group**，填 `group.com.receiptbook`（`Entitlements/` 已备好文件）。
5. 图标/启动图：`Resources/` 的 PNG 加入主 target 的 Copy Bundle Resources；`Info.plist` 已配 `CFBundleIcons` + `UILaunchImages`（也可改用 Asset Catalog）。
6. 相机权限 `NSCameraUsageDescription` 已在 `Resources/Info.plist` 写好。

## 云构建 IPA（GitHub Actions）

推送代码到 `main` 分支后，GitHub Actions 会自动在云端生成**未签名 IPA**（越狱设备用），产物以 Artifact 形式提供：

1. GitHub 仓库 → Actions → 最新一次运行 → Artifacts → 下载 `ReceiptBook-ipa`（zip）。
2. 解压得到 `ReceiptBook.ipa`，传到手机（AirDrop / iCloud / 微信「文件」）。
3. 越狱设备（已装 AppSync Unified）用 **Filza** 打开 IPA → 点「安装」。

> 未签名 IPA 仅用于越狱设备。若要上架 App Store / 正常侧载，需在 `.github/workflows/build.yml` 里换成你自己的开发者账号签名。

## 备份 / 恢复 与 桌面小组件

- **备份**：记账 Tab 右上角「☁️↑」按钮 → 「备份到 iCloud Drive（含图片 / 仅数据）」/「从备份恢复」。备份为单个 JSON 文件，通过系统文件选择器保存。
- **小组件**：`Widget/ReceiptWidget.swift` 由 `ReceiptWidget` Extension target 编译；主 App 每次持久化后通过 `WidgetBridge` 把概览写入 App Group 共享 UserDefaults。

## 数据兼容

与旧版共用同一套存储格式（`Documents/receipts.json` + `Documents/Receipts/` 图片），旧数据无需迁移。旧票据都有金额，按「记账」处理；新增字段（地点/心情/标签）缺失时按空处理。
