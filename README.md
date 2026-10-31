# 小票收纳（SwiftUI 版）

把「小票收纳」用 **Swift + SwiftUI** 重写。产品定位是「票据/票根**收藏夹**」而非纯记账本：**金额可空**——留空即「纪念收藏」（票根、门票、纪念小票、机票等，只收藏不记账），有金额才计入账与统计。

## 功能

- **记账**：有金额的票据列表，搜索、滑动删除、CSV 导出；点分类/日期看子集。
- **收藏**：无金额的纪念票据独立成 Tab，网格卡片展示，可搜索，带地点/心情/标签。
- **扫描 / 编辑**：SwiftUI 表单 + `VNDocumentCameraViewController`（`UIViewControllerRepresentable` 桥接）扫描，Vision OCR 自动填金额/商家/日期；金额留空即进入收藏；详情页可编辑。
- **统计**：仅计入有金额的票据；支持按月切换；本月/今日/累计支出、日均、笔数、柱状图、分类/日期汇总，并显示收藏张数。
- **票据图片**：详情页点击可全屏缩放。
- **票据类型**：发票 / 小票 / 机票 / 收费条 / 门票 / 票根 / 其他。
- **iCloud 云端备份**：一键备份到 iCloud Drive / 文件 App，换机或误删后可一键恢复。
- **桌面小组件**：主屏幕小组件显示本月支出与收藏概览（WidgetKit）。
- **旅行导图（原型）**：iOS 17 SwiftUI `Map` 分天路线 + 编号标记 + 相机动画 + 时间轴联动（详见 `docs/travel-map-design.md`）。

## 文件结构

| 文件 | 职责 |
|---|---|
| `ReceiptBookApp.swift` | `@main` 入口（SwiftUI `App` 生命周期） |
| `RootView.swift` | 四 Tab（记账 / 收藏 / 扫描 / 统计） |
| `Receipt.swift` | `ReceiptType` + `Mood` + `Receipt` struct（Codable，兼容旧 JSON） |
| `ReceiptStore.swift` | `ObservableObject` 单例存储 + 缩略图缓存 + 备份恢复 |
| `ReceiptOCR.swift` | Vision OCR 抽取金额/商家/日期 |
| `ReceiptListView.swift` | 记账列表（含 `ReceiptRow`） |
| `CollectionView.swift` | 收藏夹网格（含 `CollectionCard`） |
| `ReceiptDetailView.swift` | 票据详情 + 编辑 + 删除 |
| `AddReceiptView.swift` | 添加/编辑表单 + 扫描 + OCR + 收藏字段 |
| `DocumentScanner.swift` | `VNDocumentCameraViewController` 的 SwiftUI 桥接 |
| `StatsView.swift` | 统计页（含 `CategoryRow` / `DayRow`） |
| `DailyBarChartView.swift` | 纯 SwiftUI 柱状图 |
| `CSVExport.swift` | CSV 导出 + 分享面板 |
| `FullScreenImageView.swift` | 大图缩放查看器 |
| `BackupService.swift` | iCloud 备份/恢复（单文件、图片内嵌） |
| `BackupView.swift` | 备份与恢复界面 |
| `DocumentPickers.swift` | 文件导出/导入桥接（`UIDocumentPickerViewController`） |
| `WidgetBridge.swift` | 主 App → 小组件共享数据桥接 |
| `Widget/ReceiptWidget.swift` | 桌面小组件（WidgetKit，需单独 Extension 目标） |

## 技术栈

- **UI**：SwiftUI（iOS 17+）
- **状态管理**：Combine（`ObservableObject` / `@Published` / `@EnvironmentObject`）
- **扫描 / OCR**：VisionKit（`VNDocumentCameraViewController`）+ Vision（`VNRecognizeTextRequest`）
- **云端备份**：iCloud Drive / 文件 App（`UIDocumentPickerViewController` + `UniformTypeIdentifiers`）
- **桌面小组件**：WidgetKit + App Group
- **存储**：本地 JSON 索引 + JPEG 图片（Documents）

## 备份 / 恢复 与 桌面小组件

- **备份**：记账 Tab 右上角「☁️↑」按钮 → 「备份到 iCloud Drive」/「从备份恢复」。备份为单个 JSON 文件（票据 + 图片 base64 内嵌），通过系统文件选择器保存到 iCloud Drive。
- **小组件**：`Widget/ReceiptWidget.swift` 是**独立 Extension 代码**，Apelin 单 App 目标无法编译它；需在 Xcode 中新建 Widget Extension target + 开启 App Group（`group.com.receiptbook`）。主 App 已在每次持久化后通过 `WidgetBridge` 把概览写入共享 UserDefaults。

## 构建（Apelin）

1. 用本目录内容覆盖 Apelin 项目根目录，删除旧的全部 `.m/.h` 文件。
2. `apelin-project.json` 已改好：`"language": "swift"`、`"sources": ["Sources/*.swift"]`，frameworks 含 `SwiftUI`、`Combine`、`UniformTypeIdentifiers`。
3. `Resources/` 含全套图标与启动图，`Info.plist` 已配 `CFBundleIcons` + `UILaunchImages`。

> ⚠️ 注意：① 项目模板仍是 `uikit-swift`，若 Apelin 有 SwiftUI 模板建议替换 `template.templateID`；② 图标/启动图需落在 `.app` 包根目录，若桌面图标不显示，请把 PNG 移到项目根并去掉 `resources` 路径前缀 `Resources/`。

## 数据兼容

与旧版共用同一套存储格式（`Documents/receipts.json` + `Documents/Receipts/` 图片），旧数据无需迁移。旧票据都有金额，按「记账」处理；新增字段（地点/心情/标签）缺失时按空处理。
