# 小票收纳（SwiftUI 版）

把「小票收纳」用 **Swift + SwiftUI** 重写。产品定位是「票据/票根**收藏夹**」而非纯记账本：**金额可空**——留空即「纪念收藏」（票根、门票、纪念小票、机票等，只收藏不记账），有金额才计入账与统计。

## 功能

- **记账**：有金额的票据列表（顶部类型筛选 + 日期/金额排序、卡片式行、类型彩色胶囊、相对日期「今天/昨天」），自定义左滑删除（圆角删除区 + 粒子消散动画 + 震动反馈 + 5 秒撤销），批量删除，多页票据在缩略图右下角显示页数角标；点分类/日期看子集。
- **收藏**：无金额的纪念票据独立成 Tab，网格卡片展示，**标签筛选**（标签在添加/编辑页填写），带地点/心情/标签。
- **扫描 / 编辑**：SwiftUI 表单 + `VNDocumentCameraViewController` 桥接扫描，Vision OCR 自动填金额/商家/日期；金额留空即进入收藏；详情页可编辑、可分享。
- **统计**：仅计入有金额的票据；支持月/年切换；本月/本年支出、日均、笔数、柱状图、分类/日期汇总，并显示收藏张数。
- **票据图片**：详情页点击可全屏缩放；列表缩略图走 ImageIO 降采样（不占用大内存）。
- **票据类型**：小票 / 门票 / 车票 / 机票 / 发票 / 收费条 / 其他（顺序即筛选条顺序）。
- **iCloud 云端备份**：一键备份到 iCloud Drive（含图片/仅数据两种），换机或误删可恢复。
- **桌面小组件**：主屏幕显示本月支出与收藏概览（WidgetKit）；主 App 每次保存后调用 `WidgetCenter.reloadAllTimelines()` 立即刷新。
- **旅行导图（原型）**：iOS 17 SwiftUI `Map` 分天路线 + 编号标记 + 相机动画 + 时间轴联动（详见 `docs/travel-map-design.md`）。

## 快速开始

```bash
brew install xcodegen        # 只需一次
make gen                     # 由 project.yml 生成 ReceiptBook.xcodeproj
make run                     # 编译 + 装进 iOS 17+ 模拟器 + 启动
make seed                    # 可选：灌入 8 条示例数据（含现场绘制的小票图片，仅 Debug）
make verify                  # 装到验证机 iPhone 15（自动灌示例数据）
make deploy                  # 同时装到体验机 iPhone 15 Pro 与验证机
make reset-data              # 重置体验机数据为 8 条示例
make ipa                     # 本地复现 CI：出未签名 IPA（越狱机用）
make help                    # 全部命令 + 当前自动选中的模拟器
```

在 Xcode 里就是打开工程后 `⌘R`；调 UI 时按 `⌥⌘↩` 打开 Canvas，`Sources/Previews.swift` 里有 13 个预览（整页 + 组件）。

> **纪律**：新增 `.swift` 文件放进 `Sources/` 后，必须重新 `make gen`；否则文件不会进入 target（编译会报 `cannot find ... in scope`）。同理，改过 `project.yml` 也要重新生成。

## 文件结构

| 文件 | 职责 |
|---|---|
| `ReceiptBookApp.swift` | `@main` 入口（SwiftUI `App` 生命周期） |
| `RootView.swift` | 四 Tab（记账 / 收藏 / 统计 / 旅行）+ 悬浮「+」 |
| `Receipt.swift` | `ReceiptType` + `Mood` + `Receipt`（Codable，容错解码）+ 标签解析 |
| `ReceiptStore.swift` | `ObservableObject` 单例存储 + 图片缓存 + 备份恢复 + 损坏索引保护 |
| `ReceiptOCR.swift` | Vision OCR 抽取金额/商家/日期 |
| `ReceiptListView.swift` | 记账列表（含 `ReceiptRow`）、批量删除、导出当前列表 |
| `CollectionView.swift` | 收藏夹网格（含 `CollectionCard`）+ 标签筛选 |
| `ReceiptDetailView.swift` | 票据详情 + 编辑 + 删除（含地点/详细地址/心情/标签） |
| `AddReceiptView.swift` | 添加/编辑表单（标准样式） |
| `AddReceiptViewB.swift` | 添加/编辑表单（拍照优先样式，可在「我的」切换） |
| `AddReceiptModel.swift` | 拍照优先表单的共享模型（OCR + 保存） |
| `ReceiptFormFields.swift` | 类型/心情胶囊选择器 + 地点区块 |
| `DocumentScanner.swift` | `VNDocumentCameraViewController` 的 SwiftUI 桥接 |
| `StatsView.swift` | 统计页（月/年，含 `CategoryRow` / `DayRow`） |
| `DailyBarChartView.swift` | 纯 SwiftUI 柱状图 |
| `CSVExport.swift` | CSV 导出（含详细地址列）+ 分享面板 |
| `FullScreenImageView.swift` | 大图缩放查看器 |
| `BackupService.swift` | iCloud 备份/恢复（单文件、图片内嵌） |
| `BackupView.swift` | 备份与恢复界面 |
| `DocumentPickers.swift` | 文件导出/导入桥接（`UIDocumentPickerViewController`） |
| `Formatters.swift` | 金额格式化（千分位） |
| `WidgetBridge.swift` | 主 App → 小组件共享数据桥接（含时间线刷新） |
| `TravelModels.swift` | 旅行数据模型 + 示例数据 |
| `TravelMapView.swift` | 旅行导图（分天路线 + 时间轴联动） |
| `Previews.swift` | 13 个 `#Preview`（仅 Debug，示例数据走独立临时目录） |
| `DebugSeed.swift` | `-seedSampleData` 启动参数灌示例数据（仅 Debug） |
| `AppState.swift` | 跨视图 UI 状态 + 添加页样式枚举 |
| `MeView.swift` | 「我的」：备份/导出、样式切换、存储状态、关于 |
| `Widget/ReceiptWidget.swift` | 桌面小组件（WidgetKit，独立 Extension） |
| `Resources/LaunchScreen.storyboard` | 启动画面（logo + App 名 + 背景色） |
| `Resources/Icon-1024.png` | 仅用于 App Store Connect 上传（构建不引用，图标以 Asset Catalog 为准） |
| `Makefile` | `gen / run / seed / ipa / devices / clean` |
| `project.yml` | XcodeGen 工程描述（含 App Group 与隐私清单） |
| `Entitlements/` | App Group 权限（由 `project.yml` 的 `properties` 生成） |

## 技术栈

- **UI**：SwiftUI（iOS 17+）
- **状态管理**：Combine（`ObservableObject` / `@Published` / `@EnvironmentObject`）
- **扫描 / OCR**：VisionKit（`VNDocumentCameraViewController`）+ Vision（`VNRecognizeTextRequest`）
- **地图**：MapKit（`Map` / `MapPolyline` / `MapCameraPosition`）
- **云端备份**：iCloud Drive / 文件 App（`UIDocumentPickerViewController` + `UniformTypeIdentifiers`）
- **桌面小组件**：WidgetKit + App Group + `WidgetCenter`
- **存储**：本地 JSON 索引 + JPEG 图片（Documents）

## 构建（Xcode · iOS 17+）

**方式一：XcodeGen（推荐）**

```bash
make gen && make run
```

**方式二：手动创建工程**

1. Xcode → New → iOS App（SwiftUI，名称 `ReceiptBook`，Bundle ID `com.receiptbook`，Deployment Target **17.0**）。
2. 把 `Sources/` 下所有 `.swift` 拖进主 target；`Assets.xcassets` 一并加入。
3. 新建 Widget Extension target，把 `Widget/ReceiptWidget.swift` 加进去。
4. 主 App 与 Widget 的 Signing & Capabilities 都开 **App Group**，填 `group.com.receiptbook`。
5. 图标走 Asset Catalog（`AppIcon`）；启动屏是 `Resources/LaunchScreen.storyboard`（logo 用 `LaunchLogo`，背景用 `LaunchBackground` 颜色）。

## 云构建 IPA（GitHub Actions）

推送代码到 `main` 分支后，GitHub Actions 会自动在云端生成**未签名 IPA**（越狱设备用），产物以 Artifact 形式提供：

1. GitHub 仓库 → Actions → 最新一次运行 → Artifacts → 下载 `ReceiptBook-ipa`（zip）。
2. 解压得到 `ReceiptBook.ipa`，传到手机（AirDrop / iCloud / 微信「文件」）。
3. 越狱设备（已装 AppSync Unified）用 **Filza** 打开 IPA → 点「安装」。

> 未签名 IPA 仅用于越狱设备。若要上架 App Store / 正常侧载，需在 `.github/workflows/build.yml` 里换成你自己的开发者账号签名。

## 备份 / 恢复 与 桌面小组件

- **备份**： 「我的」→「备份与恢复」→「备份到 iCloud Drive（含图片 / 仅数据）」/「从备份恢复」。备份为单个 JSON 文件，通过系统文件选择器保存。打包/恢复都在后台执行并显示进度；恢复会二次确认（覆盖不可撤销）。
- **小组件**：`Widget/ReceiptWidget.swift` 由 `ReceiptWidget` Extension target 编译；主 App 每次持久化后通过 `WidgetBridge` 把概览写入 App Group 共享 UserDefaults，并立即刷新时间线。
- **注意**：App Group 依赖**签名后的 entitlements**。未签名的越狱 IPA 没有 entitlements，小组件读不到数据（显示 0）。验证小组件请用模拟器或用你自己的开发者账号签名真机。

## 数据兼容

与旧版共用同一套存储格式（`Documents/receipts.json` + `Documents/Receipts/` 图片），旧数据无需迁移。旧票据都有金额，按「记账」处理；新增字段（地点/地址/心情/标签）缺失时按空处理。

解码是容错的：未知的心情字符串按「无」处理、日期同时兼容 Unix 时间戳与 ISO8601，单条脏数据不会让整个索引解码失败。若主索引彻底解不开，会先另存一份 `receipts.corrupt-<时间戳>.json` 保留现场，再回退到 `.bak`，并在「我的 → 存储状态」里提示。

## 隐私

`Resources/PrivacyInfo.xcprivacy` 已声明：不做跟踪、不收集数据；使用了 UserDefaults（原因码 `CA92.1`）。
