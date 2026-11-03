// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI

/// 统计页「分类」跳转路由（类型 + 月份）。
enum StatsRoute: Hashable {
    /// 某类型 + 当前维度（日/月/年）对应的期间
    case typeIn(ReceiptType, Date, StatsScope)
}

/// 统计页内可以推入的下一级页面（统计本身是被推入的页面，不再自带导航栈）。
enum StatsPush: Hashable {
    case typeIn(ReceiptType, Date, StatsScope)
    case day(Date)
    case month(Date)
}

enum StatsScope: String, CaseIterable, Identifiable {
    case day = "日"
    case month = "月"
    case year = "年"
    var id: String { rawValue }
}

struct StatsView: View {
    @EnvironmentObject private var store: ReceiptStore
    @State private var pushed: StatsPush?
    @State private var referenceMonth = Date()
    @State private var scope: StatsScope = .month
    @State private var showPicker = false

    /// 统计结果缓存：数据量大时，避免每次 body 重算都重新过滤/分组（每日明细尤其重）
    private final class StatsCache {
        var key = ""
        var day: [Receipt] = []
        var month: [Receipt] = []
        var year: [Receipt] = []
        /// 每天的（笔数, 金额, 占当月最大值比例）
        var dayRows: [(day: Date, count: Int, total: Double, fraction: Double)] = []
        var dailyTotals: [Double] = []
        var monthlyTotals: [Double] = []
    }
    @State private var cache = StatsCache()

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月"
        return f
    }()

    private static let dayFullFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月d日"
        return f
    }()

    private static let yearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
                // 期间切换条固定在滚动区域之外：
                // 放在 ScrollView 里会被滚动手势抢走点击（表现为「点了没反应」）
                header
                    .padding(.horizontal, StatsStyle.gutter)
                    .padding(.top, 2)
                    .padding(.bottom, 10)
                    .background(StatsStyle.pageBackground)

                ScrollView {
                    VStack(spacing: 18) {
                        hero
                        metrics
                        modulesBlock
                        memorabiliaNote
                    }
                    .padding(.horizontal, StatsStyle.gutter)
                    .padding(.top, 4)
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
                .background(StatsStyle.pageBackground)
            }
            .background(StatsStyle.pageBackground.ignoresSafeArea())
            .navigationTitle("统计")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(StatsStyle.pageBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationDestination(item: $pushed) { push in
                switch push {
                case .typeIn(let type, let date, let scope):
                    switch scope {
                    case .day: ReceiptListView(filter: .typeInDay(type, date), alwaysShowSearchBar: true)
                    case .month: ReceiptListView(filter: .typeInMonth(type, date), alwaysShowSearchBar: true)
                    case .year: ReceiptListView(filter: .typeInYear(type, date), alwaysShowSearchBar: true)
                    }
                case .day(let day):
                    ReceiptListView(filter: .day(day), alwaysShowSearchBar: true)
                case .month(let month):
                    ReceiptListView(filter: .month(month), alwaysShowSearchBar: true)
                }
            }
            .hidesFloatingTabBar()
            .sheet(isPresented: $showPicker) {
                DatePickerSheet(scope: scope, initialDate: referenceMonth) { date in
                    withAnimation(.easeInOut(duration: 0.3)) { referenceMonth = date }
                }
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
            }
    }

    // MARK: - 头部

    private var header: some View {
        VStack(spacing: 12) {
            StatsScopeSwitch(scope: $scope)
                .frame(maxWidth: 210)

            // 「回到今天/本月/今年」做成导航条里常驻的按钮：
            // 不再条件插入，页面高度恒定，切换期间不会有布局跳动。
            StatsPeriodNavigator(
                title: periodTitle,
                isCurrentPeriod: isCurrentPeriod,
                onPrevious: { changePeriod(-1) },
                onNext: { changePeriod(1) },
                onPick: { showPicker = true },
                onReturnToNow: {
                    withAnimation(.easeInOut(duration: 0.3)) { referenceMonth = Date() }
                }
            )
        }
        .padding(.top, 6)
    }

    private var periodTitle: String {
        switch scope {
        case .day:
            // 单日始终带上年份，避免跨年时看不出是哪一年
            return Self.dayFullFormatter.string(from: referenceMonth)
        case .month:
            return Self.monthFormatter.string(from: referenceMonth)
        case .year:
            return Self.yearFormatter.string(from: referenceMonth)
        }
    }

    // MARK: - Hero

    @ViewBuilder
    private var modulesBlock: some View {
        VStack(spacing: 18) {
            if slices.isEmpty {
                emptyCard
            } else {
                composition
                if scope == .day {
                    dayReceiptList
                } else {
                    trend
                    if scope == .month {
                        dayList
                    }
                }
            }
        }
    }

    private var hero: some View {
        StatsHeroCard(
            caption: heroCaption,
            amount: totalAmount.yuan,
            countText: "共 \(totalCount) 笔 · \(scope == .day ? "单均" : (scope == .month ? "日均" : "月均")) \(averageAmount.yuan)",
            delta: totalAmount > 0 ? previousDelta : nil,
            deltaText: previousDelta.map { String(format: "%@%.1f%%", $0 >= 0 ? "+" : "", $0 * 100) },
            sparkline: sparklineSeries
        )
    }

    private var heroCaption: String {
        switch scope {
        case .day: return isCurrentPeriod ? "本日支出" : "该日支出"
        case .month: return isCurrentMonth ? "本月支出" : "该月支出"
        case .year: return isCurrentYear ? "本年支出" : "该年支出"
        }
    }

    // MARK: - 指标

    private var metrics: some View {
        let countMetric = StatsMetric(title: "笔数", value: "\(totalCount)", symbol: "list.bullet")
        let averageMetric = StatsMetric(title: scope == .day ? "单均" : (scope == .month ? "日均" : "月均"),
                                        value: averageAmount.yuan,
                                        symbol: "chart.line.uptrend.xyaxis")
        let maxMetric = StatsMetric(title: "最大单笔",
                                    value: (maxReceipt?.amount ?? 0).yuan,
                                    symbol: "crown")
        return StatsMetricRow(metrics: [countMetric, averageMetric, maxMetric])
    }

    // MARK: - 分类构成

    private var composition: some View {
        VStack(alignment: .leading, spacing: 10) {
            StatsSectionTitle(text: "分类构成", trailing: "\(slices.count) 类")
            StatsCompositionCard(slices: slices) { type in
                pushed = .typeIn(type, referenceMonth, scope)
            }
        }
    }

    // MARK: - 趋势

    private var trend: some View {
        VStack(alignment: .leading, spacing: 10) {
            StatsSectionTitle(text: scope == .month ? "每日支出" : "每月支出",
                              trailing: scope == .month ? "点柱看明细" : nil)
            StatsTrendCard(title: scope == .month ? "本期间走势" : "全年走势",
                           subtitle: "最高 \(maxTrendValue.yuan)",
                           points: trendPoints) { index in
                if scope == .day || scope == .month {
                    if let day = dayDate(for: index) { pushed = .day(day) }
                } else if let date = monthDate(for: index) {
                    // 年模式点柱状图：进入「该月」页，标题只显示月份
                    pushed = .month(date)
                }
            }
        }
    }

    // MARK: - 每日明细

    private var dayList: some View {
        VStack(alignment: .leading, spacing: 10) {
            StatsSectionTitle(text: "每日明细", trailing: "\(stats.dayRows.count) 天")
            VStack(spacing: 0) {
                ForEach(Array(stats.dayRows.enumerated()), id: \.element.day) { index, row in
                    let day = row.day
                    let total = row.total
                    let fraction = row.fraction
                    Button {
                        Haptics.selection()
                        pushed = .day(day)
                    } label: {
                        StatsDayRow(day: day, count: row.count, total: total, fraction: fraction)
                    }
                    .buttonStyle(.plain)

                    if index < stats.dayRows.count - 1 {
                        Divider().padding(.leading, 70).opacity(0.5)
                    }
                }
            }
            .statsCard(padding: 14)
        }
    }

    // MARK: - 当日票据

    private var dayReceiptList: some View {
        VStack(alignment: .leading, spacing: 10) {
            StatsSectionTitle(text: "当日票据", trailing: "\(dayExpenseReceipts.count) 笔")
            VStack(spacing: 0) {
                ForEach(Array(dayExpenseReceipts.enumerated()), id: \.element.id) { index, receipt in
                    HStack(spacing: 12) {
                        Image(systemName: receipt.type.symbolName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(receipt.type.tintColor)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(receipt.type.tintColor.opacity(0.12)))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(receipt.merchant)
                                .font(.system(size: 14, weight: .medium))
                                .lineLimit(1)
                            Text(receipt.type.displayName)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 8)

                        Text((receipt.amount ?? 0).yuan)
                            .font(.system(size: 14, weight: .semibold))
                            .monospacedDigit()
                    }
                    .padding(.vertical, 9)

                    if index < dayExpenseReceipts.count - 1 {
                        Divider().opacity(0.5)
                    }
                }
            }
            .statsCard(padding: 14)
        }
    }

    // MARK: - 收藏提示

    @ViewBuilder
    private var memorabiliaNote: some View {
        if totalMemorabiliaCount > 0 {
            HStack(spacing: 8) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.accentColor)
                Text("另有 \(totalMemorabiliaCount) 张纪念票据，不计入支出统计")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Capsule().fill(Color(.tertiarySystemFill).opacity(0.7)))
            .padding(.top, 2)
        }
    }

    private var emptyCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.pie")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.tertiary)
            Text("这个期间还没有支出")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            Text("换个期间看看，或去添加一张小票")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .statsCard()
    }

    // MARK: - 数据

    private var cacheKey: String {
        "\(store.version)|\(Calendar.current.startOfDay(for: referenceMonth).timeIntervalSince1970)"
    }

    /// 一次按键计算全部统计输入，之后整段 body 复用
    private var stats: StatsCache {
        if cache.key == cacheKey { return cache }
        let calendar = Calendar.current
        let month = store.receipts(inMonthOf: referenceMonth).filter { $0.amount != nil }
        let year = store.receipts(inYearOf: referenceMonth).filter { $0.amount != nil }
        let day = store.receipts(on: referenceMonth).filter { $0.amount != nil }

        var grouped: [Date: (count: Int, total: Double)] = [:]
        for receipt in month {
            let key = calendar.startOfDay(for: receipt.date)
            var current = grouped[key] ?? (0, 0)
            current.count += 1
            current.total += receipt.amount ?? 0
            grouped[key] = current
        }
        let peak = max(grouped.values.map(\.total).max() ?? 0, 0.0001)
        let rows = grouped.keys.sorted(by: >).map { day -> (Date, Int, Double, Double) in
            let value = grouped[day] ?? (0, 0)
            return (day, value.count, value.total, value.total / peak)
        }

        cache.key = cacheKey
        cache.day = day
        cache.month = month
        cache.year = year
        cache.dayRows = rows
        cache.dailyTotals = store.dailyTotals(inMonthOf: referenceMonth)
        cache.monthlyTotals = store.monthlyTotals(inYearOf: referenceMonth)
        return cache
    }

    private var monthExpenseReceipts: [Receipt] { stats.month }

    private var yearExpenseReceipts: [Receipt] { stats.year }

    private var dayExpenseReceipts: [Receipt] { stats.day }

    private var expenseReceipts: [Receipt] {
        switch scope {
        case .day: return dayExpenseReceipts
        case .month: return monthExpenseReceipts
        case .year: return yearExpenseReceipts
        }
    }

    private var sparklineSeries: [Double] {
        switch scope {
        case .day: return []
        case .month: return dailyTotals
        case .year: return monthlyTotals
        }
    }

    private var totalAmount: Double {
        expenseReceipts.compactMap(\.amount).reduce(0, +)
    }

    private var totalCount: Int { expenseReceipts.count }

    private var maxReceipt: Receipt? {
        expenseReceipts.max { ($0.amount ?? 0) < ($1.amount ?? 0) }
    }

    private var dailyTotals: [Double] { stats.dailyTotals }
    private var monthlyTotals: [Double] { stats.monthlyTotals }
    private var totalMemorabiliaCount: Int { store.receipts.filter { $0.amount == nil }.count }

    private var averageAmount: Double {
        let calendar = Calendar.current
        if scope == .day {
            return totalCount > 0 ? totalAmount / Double(totalCount) : 0
        }
        if scope == .month {
            let days: Int
            if isCurrentMonth {
                days = calendar.component(.day, from: Date())
            } else {
                days = calendar.range(of: .day, in: .month, for: referenceMonth)?.count ?? 30
            }
            return days > 0 ? totalAmount / Double(days) : 0
        } else {
            let months = isCurrentYear ? calendar.component(.month, from: Date()) : 12
            return months > 0 ? totalAmount / Double(months) : 0
        }
    }

    /// 与上一期间对比的变化率
    private var previousDelta: Double? {
        let calendar = Calendar.current
        let component: Calendar.Component = scope == .day ? .day : (scope == .month ? .month : .year)
        guard let previous = calendar.date(byAdding: component, value: -1, to: referenceMonth) else {
            return nil
        }
        let previousReceipts: [Receipt]
        switch scope {
        case .day: previousReceipts = store.receipts(on: previous)
        case .month: previousReceipts = store.receipts(inMonthOf: previous)
        case .year: previousReceipts = store.receipts(inYearOf: previous)
        }
        let previousTotal = previousReceipts.compactMap(\.amount).reduce(0, +)
        guard previousTotal > 0 else { return nil }
        return (totalAmount - previousTotal) / previousTotal
    }

    private var slices: [StatsCategorySlice] {
        let grouped = Dictionary(grouping: expenseReceipts, by: \.type)
        let total = max(totalAmount, 0.0001)
        return grouped.compactMap { type, receipts -> StatsCategorySlice? in
            let sum = receipts.compactMap(\.amount).reduce(0, +)
            guard sum > 0 else { return nil }
            return StatsCategorySlice(type: type,
                                      count: receipts.count,
                                      total: sum,
                                      fraction: sum / total)
        }
        .sorted { $0.total > $1.total }
    }

    private var maxTrendValue: Double {
        max((scope == .month ? dailyTotals : monthlyTotals).max() ?? 0, 0)
    }

    private var trendPoints: [StatsTrendPoint] {
        let calendar = Calendar.current
        if scope == .month {
            let count = dailyTotals.count
            let todayDay = calendar.isDate(referenceMonth, equalTo: Date(), toGranularity: .month)
                ? calendar.component(.day, from: Date())
                : -1
            return (0..<count).map { index in
                let day = index + 1
                let showLabel = day == 1 || day % 5 == 0
                return StatsTrendPoint(id: day,
                                       label: showLabel ? "\(day)" : "",
                                       value: dailyTotals[index],
                                       isHighlighted: day == todayDay)
            }
        } else {
            let currentMonth = isCurrentYear ? calendar.component(.month, from: Date()) : -1
            return (0..<12).map { index in
                let month = index + 1
                return StatsTrendPoint(id: month,
                                       label: "\(month)",
                                       value: monthlyTotals[index],
                                       isHighlighted: month == currentMonth)
            }
        }
    }

    private func dayDate(for day: Int) -> Date? {
        var components = Calendar.current.dateComponents([.year, .month], from: referenceMonth)
        components.day = day
        return Calendar.current.date(from: components)
    }

    private func monthDate(for month: Int) -> Date? {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: referenceMonth)
        components.month = month
        components.day = 1
        return Calendar.current.date(from: components)
    }

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(referenceMonth, equalTo: Date(), toGranularity: .month)
    }

    private var isCurrentYear: Bool {
        Calendar.current.isDate(referenceMonth, equalTo: Date(), toGranularity: .year)
    }

    private var isCurrentPeriod: Bool {
        let calendar = Calendar.current
        switch scope {
        case .day: return calendar.isDate(referenceMonth, inSameDayAs: Date())
        case .month: return isCurrentMonth
        case .year: return isCurrentYear
        }
    }

    private func changePeriod(_ delta: Int) {
        let component: Calendar.Component = scope == .day ? .day : (scope == .month ? .month : .year)
        guard let date = Calendar.current.date(byAdding: component, value: delta, to: referenceMonth) else {
            return
        }
        withAnimation(.easeInOut(duration: 0.3)) { referenceMonth = date }
    }
}

// MARK: - 年月选择弹窗

struct DatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let scope: StatsScope
    let initialDate: Date
    let onSelect: (Date) -> Void

    @State private var date: Date
    @State private var year: Int

    init(scope: StatsScope, initialDate: Date, onSelect: @escaping (Date) -> Void) {
        self.scope = scope
        self.initialDate = initialDate
        self.onSelect = onSelect
        _date = State(initialValue: initialDate)
        _year = State(initialValue: Calendar.current.component(.year, from: initialDate))
    }

    private var currentYear: Int { Calendar.current.component(.year, from: Date()) }

    /// 三个维度共用的年份范围（日/月/年一致）
    static var yearBounds: ClosedRange<Int> {
        1990...(Calendar.current.component(.year, from: Date()) + 5)
    }

    private var dayDateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let lower = calendar.date(from: DateComponents(year: Self.yearBounds.lowerBound, month: 1, day: 1)) ?? Date()
        let upper = calendar.date(from: DateComponents(year: Self.yearBounds.upperBound, month: 12, day: 31)) ?? Date()
        return lower...upper
    }


    /// 三个维度分别对应 年 / 年月 / 年月日
    @ViewBuilder
    private var pickerContent: some View {

                if scope == .day {
                    // 日：年 + 月 + 日
                    DatePicker("", selection: $date, in: dayDateRange, displayedComponents: [.date])
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                } else if scope == .month {
                    // 月：两列（年 | 月），用 UIPickerView 实现 ——
                    // SwiftUI 的 Picker 每列各有一条胶囊高亮，拼起来是两截；
                    // UIPickerView 的选中条是整条贯穿所有列，和日期轮一致。
                    MonthYearWheel(date: $date, yearBounds: Self.yearBounds)
                        .frame(maxWidth: .infinity)
                } else {
                    Picker("", selection: $year) {
                        ForEach(Array(Self.yearBounds), id: \.self) { y in
                            Text(verbatim: String(y) + "年").tag(y)
                        }
                    }
                    .pickerStyle(.wheel)
                }
    }


    var body: some View {
        VStack(spacing: 10) {
            Text(scope == .day ? "选择日期" : (scope == .month ? "选择月份" : "选择年份"))
                .font(.system(size: 15, weight: .semibold))
                .padding(.top, 18)

            pickerContent
            .frame(maxHeight: 180)

            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Text("取消")
                        .font(.system(size: 15, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color(.tertiarySystemFill)))
                }
                .buttonStyle(.plain)

                Button {
                    confirm()
                    dismiss()
                } label: {
                    Text("确定")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.accentColor))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    private func confirm() {
        let calendar = Calendar.current
        switch scope {
        case .day:
            // 年月日都来自滚轮选中的日期
            onSelect(date)
        case .month:
            var components = calendar.dateComponents([.year, .month], from: date)
            components.day = 1
            onSelect(calendar.date(from: components) ?? date)
        case .year:
            var components = calendar.dateComponents([.year, .month, .day], from: initialDate)
            components.year = year
            onSelect(calendar.date(from: components) ?? initialDate)
        }
    }
}


// MARK: - 年月两列滚轮（整条选中高亮）

/// 用 `UIPickerView` 画「年 | 月」两列：选中条贯穿两列，
/// 和 `DatePicker` 日期轮的观感一致（SwiftUI 的两个 Picker 会出现两段胶囊）。
struct MonthYearWheel: UIViewRepresentable {
    @Binding var date: Date
    let yearBounds: ClosedRange<Int>

    private var startYear: Int { yearBounds.lowerBound }
    private var endYear: Int { yearBounds.upperBound }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UIPickerView {
        let picker = UIPickerView()
        picker.dataSource = context.coordinator
        picker.delegate = context.coordinator
        picker.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        syncSelection(picker)
        return picker
    }

    func updateUIView(_ picker: UIPickerView, context: Context) {
        context.coordinator.parent = self
        syncSelection(picker)
    }

    private func syncSelection(_ picker: UIPickerView) {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        if let year = components.year {
            let row = min(max(year - startYear, 0), endYear - startYear)
            if picker.selectedRow(inComponent: 0) != row {
                picker.selectRow(row, inComponent: 0, animated: false)
            }
        }
        if let month = components.month, picker.selectedRow(inComponent: 1) != month - 1 {
            picker.selectRow(month - 1, inComponent: 1, animated: false)
        }
    }

    final class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
        var parent: MonthYearWheel

        init(_ parent: MonthYearWheel) {
            self.parent = parent
        }

        func numberOfComponents(in pickerView: UIPickerView) -> Int { 2 }

        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            component == 0 ? (parent.endYear - parent.startYear + 1) : 12
        }

        func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
            component == 0 ? "\(parent.startYear + row)年" : "\(row + 1)月"
        }

        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            let year = parent.startYear + pickerView.selectedRow(inComponent: 0)
            let month = pickerView.selectedRow(inComponent: 1) + 1
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = 1
            if let newDate = Calendar.current.date(from: components) {
                parent.date = newDate
            }
        }
    }
}
