// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI

// MARK: - 设计常量

enum StatsStyle {
    /// 卡片圆角
    static let radius: CGFloat = 22
    /// 页面左右留白
    static let gutter: CGFloat = 20

    static var pageBackground: Color { Color(uiColor: .systemGroupedBackground) }
    static var cardBackground: Color { Color(uiColor: .secondarySystemGroupedBackground) }

    /// 深色 hero 卡的渐变：接近墨黑到深靛蓝，和浅色页面形成对比
    static var heroGradient: LinearGradient {
        LinearGradient(colors: [Color(red: 0.09, green: 0.10, blue: 0.14),
                                Color(red: 0.16, green: 0.18, blue: 0.30)],
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing)
    }

    /// 支出上涨用暖色、下降用绿色（对花钱来说「涨」不是好事）
    static func deltaColor(_ delta: Double) -> Color {
        if delta > 0.0001 { return Color(uiColor: .systemOrange) }
        if delta < -0.0001 { return Color(uiColor: .systemGreen) }
        return .secondary
    }
}

/// 通用卡片底：白底 + 大圆角 + 很淡的投影
struct StatsCardBackground: ViewModifier {
    var padding: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(StatsStyle.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: StatsStyle.radius, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
    }
}

extension View {
    func statsCard(padding: CGFloat = 18) -> some View {
        modifier(StatsCardBackground(padding: padding))
    }
}

/// 小节标题
struct StatsSectionTitle: View {
    let text: String
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.6)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - 月份/年份切换

/// 胶囊分段控件：月 / 年
struct StatsScopeSwitch: View {
    @Binding var scope: StatsScope
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 2) {
            ForEach(StatsScope.allCases) { item in
                let selected = item == scope
                Button {
                    Haptics.selection()
                    withAnimation(.easeInOut(duration: 0.3)) { scope = item }
                } label: {
                    Text(item.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(selected ? Color(.label) : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background {
                            if selected {
                                Capsule(style: .continuous)
                                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                                    .shadow(color: .black.opacity(0.08), radius: 4, y: 1)
                                    .matchedGeometryEffect(id: "scope", in: namespace)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("stats.scope.\(item.rawValue)")
            }
        }
        .padding(3)
        .background(Capsule(style: .continuous).fill(Color(.tertiarySystemFill)))
    }
}

/// ‹ 2026年11月 › 这样的期间导航
struct StatsPeriodNavigator: View {
    let title: String
    /// 当前是否就停在「今天 / 本月 / 今年」
    let isCurrentPeriod: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onPick: () -> Void
    /// 回到当前期间
    let onReturnToNow: () -> Void

    private let slot: CGFloat = 30

    var body: some View {
        // 单条 HStack，所有控件常驻（返回按钮用透明度开关，不做 if 分支）：
        // 条件插入会让布局与命中区域在动画期间错位，右侧箭头会偶发点不动。
        HStack(spacing: 8) {
            arrow("chevron.left", action: onPrevious)
                .accessibilityIdentifier("stats.prev")

            // 左侧对称占位：与右侧返回按钮同宽
            Color.clear
                .frame(width: slot, height: slot)

            Spacer(minLength: 0)

            // 不显示下拉箭头：把宽度让给日期本身，放不下时等比缩小而不是省略
            Button(action: onPick) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .allowsTightening(true)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("stats.period")

            Spacer(minLength: 0)

            returnButton
                .opacity(isCurrentPeriod ? 0 : 1)
                .allowsHitTesting(!isCurrentPeriod)

            arrow("chevron.right", action: onNext)
                .accessibilityIdentifier("stats.next")
        }
        .frame(height: 44)
        .padding(.horizontal, 4)
        .animation(.snappy(duration: 0.2), value: isCurrentPeriod)
    }

    /// 回到今天 / 本月 / 今年
    private var returnButton: some View {
        Button {
            Haptics.selection()
            onReturnToNow()
        } label: {
            Image(systemName: "arrow.uturn.backward")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.accentColor)
                .frame(width: slot, height: slot)
                .background(Circle().fill(Color.accentColor.opacity(0.14)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("stats.returnToNow")
        .accessibilityLabel("回到当前期间")
    }

    private func arrow(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color(.tertiarySystemFill)).frame(width: slot, height: slot))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
struct StatsHeroCard: View {
    let caption: String
    let amount: String
    let countText: String
    let delta: Double?
    let deltaText: String?
    let sparkline: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 固定行高：同比徽章有没有数据都不改变卡片高度，避免切换期间整页跳动
            HStack {
                Text(caption)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
                Spacer(minLength: 8)
                deltaBadge
            }
            .frame(height: 24)

            Text(amount)
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())

            Text(countText)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            sparklineView
                .frame(height: 44)
                .padding(.top, 2)
        }
        .padding(20)
        .background {
            ZStack {
                StatsStyle.heroGradient
                // 右上角一团柔光，避免整块死板的纯渐变
                Circle()
                    .fill(Color(red: 0.35, green: 0.42, blue: 0.95).opacity(0.55))
                    .frame(width: 180, height: 180)
                    .blur(radius: 60)
                    .offset(x: 90, y: -70)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: StatsStyle.radius, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
    }

    /// 同比徽章：没有数据时用等高的透明占位，保证行高恒定
    @ViewBuilder
    private var deltaBadge: some View {
        if let delta, let deltaText {
            HStack(spacing: 3) {
                Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 10, weight: .bold))
                Text(deltaText)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(StatsStyle.deltaColor(delta))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(.white.opacity(0.10)))
        } else {
            Color.clear
        }
    }

    private var sparklineView: some View {
        // 先归一化成 0…1 再补间：0 → 有金额时曲线从底部长到满高，
        // 有金额 → 0 时平滑落到平线，不会「一下子」跳过去。
        let values = Self.normalized(sparkline)
        return ZStack {
            SparklinePath(values: values, closed: true)
                .fill(LinearGradient(colors: [.white.opacity(0.22), .white.opacity(0.02)],
                                     startPoint: .top, endPoint: .bottom))
            SparklinePath(values: values)
                .stroke(LinearGradient(colors: [.white.opacity(0.9), .white.opacity(0.35)],
                                       startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        // 显式挂动画：不依赖外层 withAnimation 事务，切日/月/年时折线一定连贯地回涨/回落
        .animation(.easeInOut(duration: 0.34), value: values)
    }

    /// 归一化到 0…1 后再重采样：补间时高度比例才是线性变化的
    private static func normalized(_ values: [Double], count: Int = 32) -> [Double] {
        let peak = values.max() ?? 0
        guard peak > 0 else { return Array(repeating: 0, count: count) }
        let ratios = values.map { $0 / peak }
        return resample(ratios, count: count)
    }

    /// 把不同长度的序列重采样到固定点数：长度一致才能逐点补间。
    private static func resample(_ values: [Double], count: Int = 32) -> [Double] {
        guard values.count > 1 else {
            return Array(repeating: values.first ?? 0, count: count)
        }
        if values.count == count { return values }
        return (0..<count).map { index in
            let position = Double(index) * Double(values.count - 1) / Double(count - 1)
            let lower = Int(position.rounded(.down))
            let upper = min(values.count - 1, lower + 1)
            let t = position - Double(lower)
            return values[lower] * (1 - t) + values[upper] * t
        }
    }
}

/// 让一组 Double 也能参与 SwiftUI 补间（标准库没有给数组提供 VectorArithmetic）
struct AnimatableValues: VectorArithmetic {
    var values: [Double]

    /// 折线固定重采样到 32 点，所以 zero 也用 32 个 0，避免空数组参与运算
    static var zero: AnimatableValues { AnimatableValues(values: Array(repeating: 0, count: 32)) }

    static func + (lhs: AnimatableValues, rhs: AnimatableValues) -> AnimatableValues {
        combine(lhs, rhs, +)
    }

    static func - (lhs: AnimatableValues, rhs: AnimatableValues) -> AnimatableValues {
        combine(lhs, rhs, -)
    }

    /// 逐点运算；长度不一致时补 0，绝不丢点
    private static func combine(_ lhs: AnimatableValues,
                                _ rhs: AnimatableValues,
                                _ op: (Double, Double) -> Double) -> AnimatableValues {
        let count = max(lhs.values.count, rhs.values.count)
        var a = lhs.values
        var b = rhs.values
        if a.count < count { a += Array(repeating: 0, count: count - a.count) }
        if b.count < count { b += Array(repeating: 0, count: count - b.count) }
        return AnimatableValues(values: zip(a, b).map { op($0.0, $0.1) })
    }

    mutating func scale(by rhs: Double) {
        values = values.map { $0 * rhs }
    }

    var magnitudeSquared: Double {
        values.reduce(0) { $0 + $1 * $1 }
    }
}

/// 折线（closed = true 时是面积路径）。数值全部为 0 时自然画成一条贴底的平线。
struct SparklinePath: Shape {
    /// 已归一化到 0…1 的高度序列（补间即高度比例的变化）
    var values: [Double]
    var closed: Bool = false

    var animatableData: AnimatableValues {
        get { AnimatableValues(values: values) }
        set { values = newValue.values }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count > 1 else { return path }

        let step = rect.width / CGFloat(values.count - 1)

        func point(_ index: Int) -> CGPoint {
            let ratio = CGFloat(min(max(values[index], 0), 1))
            return CGPoint(x: CGFloat(index) * step,
                           y: rect.height - ratio * (rect.height - 6) - 3)
        }

        if closed {
            path.move(to: CGPoint(x: 0, y: rect.height))
            for index in values.indices { path.addLine(to: point(index)) }
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.closeSubpath()
        } else {
            path.move(to: point(0))
            for index in values.indices.dropFirst() { path.addLine(to: point(index)) }
        }
        return path
    }
}

// MARK: - 指标行

struct StatsMetric: Identifiable {
    /// 用标题当 id：切期时格子复用而不是重建，才不会有闪一下的感觉
    var id: String { title }
    let title: String
    let value: String
    let symbol: String
}

struct StatsMetricRow: View {
    let metrics: [StatsMetric]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(metrics) { metric in
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: metric.symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(metric.value)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .allowsTightening(true)
                    Text(metric.title)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(StatsStyle.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
            }
        }
    }
}

// MARK: - 分类构成

struct StatsCategorySlice: Identifiable {
    let type: ReceiptType
    let count: Int
    let total: Double
    let fraction: Double

    var id: Int { type.rawValue }
}

struct StatsCompositionCard: View {
    let slices: [StatsCategorySlice]
    let onSelect: (ReceiptType) -> Void

    private var total: Double { slices.reduce(0) { $0 + $1.total } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            stackedBar

            VStack(spacing: 0) {
                ForEach(Array(slices.enumerated()), id: \.element.id) { index, slice in
                    Button {
                        Haptics.selection()
                        onSelect(slice.type)
                    } label: {
                        row(slice)
                    }
                    .buttonStyle(.plain)

                    if index < slices.count - 1 {
                        Divider()
                            .padding(.leading, 30)
                            .opacity(0.5)
                    }
                }
            }
        }
        .statsCard()
    }

    private var stackedBar: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 3
            let available = max(0, proxy.size.width - spacing * CGFloat(max(0, slices.count - 1)))
            HStack(spacing: spacing) {
                ForEach(slices) { slice in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(slice.type.tintColor)
                        .frame(width: max(3, available * slice.fraction))
                }
            }
        }
        .frame(height: 10)
    }

    private func row(_ slice: StatsCategorySlice) -> some View {
        HStack(spacing: 11) {
            Circle()
                .fill(slice.type.tintColor)
                .frame(width: 9, height: 9) 
            Text(slice.type.displayName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 6)

            Text("\(slice.count) 笔")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .fixedSize()
                .contentTransition(.numericText())

            Text(slice.total.yuan)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .contentTransition(.numericText())

            Text("\(Int((slice.fraction * 100).rounded()))%")
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(minWidth: 40, alignment: .trailing)
                .layoutPriority(1)
                .contentTransition(.numericText())

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.quaternary)
                .fixedSize()
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }
}

// MARK: - 趋势图

struct StatsTrendPoint: Identifiable {
    let id: Int
    let label: String
    let value: Double
    var isHighlighted: Bool = false
}

struct StatsTrendCard: View {
    let title: String
    let subtitle: String
    let points: [StatsTrendPoint]
    let onSelect: (Int) -> Void


    private var maxValue: Double { max(points.map(\.value).max() ?? 0, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            HStack(alignment: .bottom, spacing: 2) {
                ForEach(points) { point in
                    Button {
                        Haptics.selection()
                        onSelect(point.id)
                    } label: {
                        VStack(spacing: 5) {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(point.value > 0
                                      ? AnyShapeStyle(barStyle(for: point))
                                      : AnyShapeStyle(Color(.quaternarySystemFill)))
                                .frame(height: barHeight(point))
                            Text(point.label)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(point.isHighlighted ? Color.primary : Color.secondary)
                                .lineLimit(1)
                                // 允许横向溢出：列的宽度只有 9pt 左右，两位数会被截成「…」；
                                // 相邻列没有标签，溢出不会撞到东西
                                .fixedSize()
                                .frame(height: 11)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 122)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(point.label) \(point.value.yuan)")
                }
            }
        }
        .statsCard()
    }

    private func barHeight(_ point: StatsTrendPoint) -> CGFloat {
        guard point.value > 0 else { return 3 }
        let ratio = point.value / maxValue
        return max(4, 88 * ratio)
    }

    private func barStyle(for point: StatsTrendPoint) -> LinearGradient {
        if point.isHighlighted {
            return LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.55)],
                                  startPoint: .top, endPoint: .bottom)
        }
        return LinearGradient(colors: [Color.accentColor.opacity(0.55), Color.accentColor.opacity(0.22)],
                              startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - 明细行

struct StatsDayRow: View {
    let day: Date
    let count: Int
    let total: Double
    let fraction: Double

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEE"
        return formatter
    }()

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.formatter.string(from: day))
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(Self.weekdayFormatter.string(from: day))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            // 「10月30日」是 6 个字，58pt 放不下会折行
            .frame(width: 76, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.tertiarySystemFill))
                    Capsule()
                        .fill(Color.accentColor.opacity(0.55))
                        .frame(width: max(4, proxy.size.width * fraction))
                }
            }
            .frame(height: 6)

            Text("\(count) 笔")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)

            Text(total.yuan)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 82, alignment: .trailing)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
