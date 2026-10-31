# 旅游导图 · 功能设计文档

> 状态：设计稿 · 版本：v1.0 · 2026-11-01

## 1. 概述

「旅游导图」是「小票收纳」的旅行模块：用户选择**城市、日期、景点、交通方式、出发时间**，系统自动把景点**串联成最优路线**、按天切分并生成时间轴，最终在**真实地图**中丝滑渲染。核心诉求不是"死板的前端页面"，而是**丝滑优雅的地图展示 + 地图与时间轴实时联动**。

本文档在"成熟 + 最新最优"之间取舍：优先采用 Apple 最新的 SwiftUI MapKit（iOS 17+）；对低系统不支持的项，标注可降级方案，用户可自行决定是否升级部署目标。

---

## 2. 技术选型（成熟 + 最新最优）

| 能力 | 首选方案 | 理由 | 最低 iOS |
|---|---|---|---|
| 地图渲染 | **SwiftUI `Map`（iOS 17+）** | 声明式、可动画、内置 `MapPolyline` / `MapStyle` / `MapCameraPosition` | **17** |
| 路线计算 | `MKDirections`（walk/drive/transit） | Apple 原生、成熟、返回真实转向+ETA | 7+ |
| 地理编码 / 搜索 | `MKLocalSearch` + `CLGeocoder` | 原生、国内走高德数据 | 7+ |
| 国内 POI / 公交准点 | 高德 / 腾讯 Web API（可选增强） | 覆盖全、公交数据更准 | — |
| 路线优化（≤20 点） | **最近邻 + 2-opt/3-opt**（端上） | 近最优、毫秒级、零依赖 | — |
| 路线优化（大规模/带时间窗） | Google OR-Tools（服务端） | 成熟最优（TSPTW） | — |
| 底部行程卡 | `presentationDetents` + `matchedGeometryEffect` | 丝滑过渡、系统级 | 16 / 17 |
| 动画 | SwiftUI `spring` / `withAnimation` | 原生流畅、不卡顿 | — |
| 持久化 | SwiftData（iOS 17+）或现有 JSON 方案 | 结构化、可查询 | 17 |

**部署目标**：**已确定 iOS 17+，不做 iOS 16 支持**（`MapPolyline` / `MapStyle` / `MapReader` 等核心渲染 API 都在 17 才可用），部署目标已改为 17.0。

---

## 3. 数据模型

```swift
struct TripPlan: Codable, Identifiable {
    let id: UUID
    var city: String
    var startDate: Date
    var endDate: Date
    var places: [Place]
    var days: [TripDay]        // 排程结果
}

struct Place: Codable, Identifiable {
    let id: UUID
    var name: String
    var coordinate: CLLocationCoordinate2D   // 需自定义 Codable
    var stayDuration: TimeInterval           // 停留时长
    var openHours: (Date, Date)?             // 开放时间（硬约束，可选）
    var preferredTime: Date?                 // 期望几点到（软约束，可选）
}

struct TripDay: Codable, Identifiable {
    let id: UUID
    var index: Int              // 第几天
    var legs: [Leg]             // 交通段 + 景点，按时间排序
    var boundingRect: MKMapRect // 当天路线包围盒（用于相机飞行动画）
}

struct Leg: Codable, Identifiable {
    enum Kind: String, Codable { case move, stay }
    let id: UUID
    var kind: Kind
    var from: Place?
    var to: Place
    var transport: Transport?   // kind == .move 时有值
    var departure: Date
    var duration: TimeInterval
}

enum Transport: String, Codable {
    case walk, subway, bus, drive, train, flight
    var symbol: String {          // SF Symbol
        switch self {
        case .walk: return "figure.walk"
        case .subway: return "tram.fill"
        case .bus: return "bus.fill"
        case .drive: return "car.fill"
        case .train: return "train.side.front.car"
        case .flight: return "airplane"
        }
    }
}
```

> `CLLocationCoordinate2D` / `MKMapRect` 不是 Codable，需存 `latitude/longitude` 或自定义转换（文档从略）。

---

## 4. 路线优化算法

**问题本质**：给定 N 个景点 + 每对之间的交通耗时（`MKDirections` 得到），找一条总耗时最短的访问顺序 —— 即**旅行商问题（TSP）**；加入开放时间/期望出发时间后变为**带时间窗的 TSP（TSPTW）**，是 NP-hard。

**端上方案（推荐，N ≤ 20）**：
1. 构建距离矩阵（缓存 `MKDirections` 结果）。
2. **最近邻构造**：从起点出发，每次取"当前点 + 交通耗时 + 停留时长"后最早可达的未访问点。
3. **2-opt（必要时 3-opt）局部优化**：交换两段边，若总耗时下降则保留，迭代到无改进。
4. 约束处理：开放时间作硬约束（越界则顺延或换序），期望时间作软目标。

复杂度：N=20 时 2-opt 毫秒级完成，完全可端上实时算。

**服务端方案（未来规模大/复杂约束）**：Google OR-Tools（CP-SAT / 路由求解器），成熟且全局最优；需要后端 + 网络，暂不进 MVP。

---

## 5. 地图渲染方案（核心 · 丝滑优雅）

### 5.1 选型：SwiftUI `Map`（iOS 17+）

声明式、可动画，配合 `MapPolyline`、`MapStyle`、`MapCameraPosition`、`MapReader`，比 `MKMapView` 更适合做"丝滑"交互。

```swift
@State private var camera: MapCameraPosition = .automatic
@State private var selectedPlace: Place.ID?
@State private var activeDayIndex: Int = 0

MapReader { proxy in
    Map(position: $camera, selection: $selectedPlace) {
        // ① 分天路线：每天一条折线 + 专属颜色/线型
        ForEach(plan.days) { day in
            MapPolyline(coordinates: day.routeCoordinates)
                .stroke(
                    day.color,
                    style: StrokeStyle(
                        lineWidth: day == activeDay ? 5 : 3,
                        lineCap: .round, lineJoin: .round,
                        dash: day.dominantTransport == .walk ? [2, 8] : []
                    )
                )
        }
        // ② 编号地点标记
        ForEach(plan.orderedPlaces) { place in
            Annotation(place.name, coordinate: place.coordinate, anchor: .bottom) {
                NumberBadge(order: place.order, color: place.dayColor)
            }
            .tag(place.id)
        }
    }
    .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
    .mapControls { MapCompass(); MapScaleView() }
}
```

### 5.2 丝滑的关键手法

1. **分天渐变色路线** —— 第 N 天一个主题色，整条线形成"从 Day1 到 DayN 的渐变感"；当前天加粗、其余天降透明度。
2. **编号地点标记** —— 圆形数字徽章（1→2→3…），底色跟随所属天；`selectedPlace` 选中时放大 + 弹簧动画。
3. **相机动画** —— 用 `MapReader` 拿 `proxy`，切天/选点时 `withAnimation(.spring)` 飞过去：

```swift
.onChange(of: activeDayIndex) { _, day in
    withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
        camera = .rect(plan.days[day].boundingRect)   // 平滑飞到当天范围
    }
}
```

4. **路线"生长"动画** —— `MapPolyline` 本身不支持 stroke 动画；用 `UIViewRepresentable` 包一层 `MKPolyline`，通过分步 `addOverlay` 逐段浮现（可选增强，非 MVP 必需）。
5. **时间轴联动（避免"死板页面"的核心）** —— 底部一张可拖拽的行程卡，与地图实时联动：

```swift
.sheet(isPresented: $showTimeline) {
    TimelineSheet(day: plan.days[activeDayIndex])
        .presentationDetents([.height(180), .medium, .large])
        .presentationDragIndicator(.visible)
}
```

- 选"第 1 天" → 地图只显示当天路线 + 相机飞到当天范围
- 卡内是当天时间轴：`09:30 出发 → 🚇 20min → 10:00 到故宫 → 停留 2h …`
- `matchedGeometryEffect` 让"地点卡 ↔ 地图标记"切换有**形变过渡**

### 5.3 交通方式可视化

| 交通 | 线型 | SF Symbol |
|---|---|---|
| 步行 | 虚线 | `figure.walk` |
| 地铁/公交 | 实线 | `tram.fill` / `bus.fill` |
| 驾车 | 点线 | `car.fill` |
| 火车/飞机 | 粗实线 | `train.side.front.car` / `airplane` |

---

## 6. 数据源

- **地理编码 / 景点搜索**：`MKLocalSearch`（国内走高德底图数据，够用）。
- **POI 增强（可选）**：高德 / 腾讯 Web API（更全的门店/开放时间/评分）。
- **公交准点**：`MKDirections` `.transit` 国内数据较薄，地铁/步行可靠，公交作估算；若要准点接高德公交 API。

---

## 7. 交互与动画设计

| 交互 | 实现 |
|---|---|
| 地图点选景点 | `selection` 绑定 + 选中标记脉冲 + 相机平移 |
| 切天 | 行程卡 tab + 地图只显示当天路线 + 相机飞当天范围 |
| 行程卡拖拽 | `presentationDetents` 三段高度 + `spring` 展开 |
| 地点卡↔标记 | `matchedGeometryEffect` 形变过渡 |
| 一键全览 | 回到 `.rect(整个行程 boundingRect)` |
| 路线生成瞬间 | 全览相机飞入 + 分天路线渐显 |

---

## 8. 一键真实地图

- App 内本就是**真实地图**（MapKit = Apple Maps 瓦片），非示意图。
- 「在 Apple Maps 打开」：`MKMapItem.openMaps` 或 `maps://?saddr=…&daddr=…` 多段 deep link，交给系统导航（真实转向 + 实时 ETA）。
- `MKDirections` 返回的 `MKRoute.steps` 可直接做"下一步指引"。

---

## 9. 分阶段里程碑

| 阶段 | 内容 | 产出 |
|---|---|---|
| **M1 骨架** | 城市+日期输入、`MKLocalSearch` 搜索添加景点、地点列表 | 可建行程 |
| **M2 排程** | 距离矩阵 + 最近邻/2-opt、分天、时间轴生成 | 可算出路线 |
| **M3 渲染（成败点）** | SwiftUI `Map` 分天路线 + 编号标记 + 相机动画 + 行程卡联动 | **丝滑地图** |
| **M4 打通** | 交通方式/出发时间编辑、一键 Apple Maps 导航 | 完整闭环 |
| **M5 进阶** | AI 补全行程、导出/分享导图（图片/PDF） | 增强 |

---

## 10. iOS 版本策略

**已确定目标 iOS 17+（不做 iOS 16 支持）**，部署目标已改为 17.0，解锁 `MapPolyline` / `MapStyle` / `MapCameraPosition` / `MapReader` 等核心渲染 API。

---

## 11. 风险与对策

| 风险 | 对策 |
|---|---|
| 国内 POI/公交覆盖 | 优先 `MKLocalSearch`；不足则接高德/腾讯 API |
| TSPTW 复杂度 | 端上启发式（≤20 点）；规模大再上 OR-Tools 服务端 |
| 地图动画性能 | 只渲染当天 overlay；相机动画用系统 `spring` 不自行插值 |
| 依赖 iOS 17 | 升级部署目标（用户已确认可接受） |
