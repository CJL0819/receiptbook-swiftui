# 性能实验记录（2026-11）

## 结论

记账列表保持 **`ScrollView + LazyVStack`**。
`List`（UICollectionView 底座）实测滚动性能高 3～4 倍，但与自定义左滑删除交互冲突，
暂不采用；后续若要合并，需要先把「滑动态」整体移出视图（见下文）。

## 已合入 main 的优化（框架无关，均已生效）

| 优化 | 位置 |
|---|---|
| 过滤/搜索/排序/合计结果缓存（按 数据版本 \| 筛选 \| 类型 \| 排序 \| 搜索词） | `ReceiptListView.ListCache` |
| 统计结果缓存（该日/月/年票据、每日分组、趋势序列） | `StatsView.StatsCache` |
| 每日明细不再 O(31×n)，改用一次预分组 | `StatsView` |
| 分页渲染（80 条/页，滚到底追加），分页切片也缓存 | `ReceiptListView` |
| 搜索防抖 180ms | `ReceiptListView` |
| 行级等值跳过（`ReceiptRow: Equatable` + `.equatable()`） | `ReceiptListView` |
| 缩略图后台降采样 + 后 4 行预取 + NSCache | `ThumbnailImage` / `ReceiptStore` |
| 行尺寸/屏幕位置改用引用类型，滚动不触发 View 失效 | `SwipeActionRow.Metrics` |
| 120Hz 解锁（`CADisableMinimumFrameDurationOnPhone`） | `Resources/Info.plist` |

## 实测（iPhone 15 Pro / 2000 条 / 24 次快速滚动脚本）

| 版本 | CPU | 脚本耗时 | 内存 |
|---|---|---|---|
| LazyVStack（main） | 30–38% | 70s | 256–260MB |
| List + drawingGroup | 7–15% | 16s | 250MB |
| LazyVStack + drawingGroup | 21–36% | 70s | ~256MB |

`drawingGroup()` 单独收益很小（且在噪声范围内），未合入。

## List 方案卡在哪（下次继续时的起点）

1. 行的自定义 `DragGesture` 会和 List 的滚动抢仲裁 → 列表滚不动；
2. 改在 window 上装 `UIPanGestureRecognizer`（`Sources/SwipeBridge.swift`，分支 `perf-uikit`），
   滚动与「左滑露出删除」都正常；
3. **未解决**：List 复用/重建 cell 会重置行内 `@State` 的 offset，
   「左滑 → 点击删除」之间行被关闭，点击落到行内容上（跳详情）。
   用 `openRowID` 补偿也不稳定。

下次的正确路径：把 `openID + offset` 整体搬到 `SwipeHub`（或父视图状态），
行只做纯展示渲染；行重建时从 hub 恢复，动画衔接交给 hub 统一驱动。

## 备份

- 标签 `design-original`：合并前的设计基线
- 桌面快照：`ReceiptBook-design-original-20261104-0200.zip`
- 实验分支：`perf-uikit`（手势桥）、`perf-list-snapshot`（List + drawingGroup）
