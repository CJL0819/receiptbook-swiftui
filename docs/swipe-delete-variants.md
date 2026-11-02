# 左滑删除区：两种实现

记录两版「红色删除区」的做法，方便回头切换。

## A. 拉伸式（默认，手感更像跟随手指）

红色区**宽度跟随卡片位移**：`stretchedActionWidth = max(0, -offset - actionGap)`。

- 优点：卡片像是把红色「拉」开，跟随感强；拖得越深红区越宽（可超出按钮宽度）。
- 代价：每帧都在改宽度，文案会被挤压、`RoundedRectangle` 的圆角会被 `min(r, w/2)` 夹紧，
  收回最后一段形状会「塌」一下。

代码位置：`Sources/SwipeActionRow.swift` → `deleteAction`（当前采用）。

## B. 固定尺寸滑入式（备份，tag `swipe-slide-variant`）

红色区**宽度恒定 92pt**，只做位移从屏幕右侧滑入/滑出：
`offset(x: max(0, offset + actionWidth + actionGap))`，文案只在到位后淡入。

- 优点：完全没有逐帧布局，不会有形状「塌陷」；收起时整块滑出屏幕。
- 代价：红色区不会随拖动变宽，观感更「滑出」而非「拉开」；不动画期间变化更「档位感」。

切换方式：

```bash
git checkout swipe-slide-variant -- Sources/SwipeActionRow.swift
```
