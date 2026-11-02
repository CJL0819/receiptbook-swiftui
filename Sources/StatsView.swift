// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI

/// 统计页「分类」跳转路由（类型 + 月份）。
enum StatsRoute: Hashable {
    case typeInMonth(ReceiptType, Date)
}

enum StatsScope: String, CaseIterable, Identifiable {
    case month = "月"
    case year = "年"
    var id: String { rawValue }
}

struct StatsView: View {
    @EnvironmentObject private var store: ReceiptStore
    @State private var path = NavigationPath()
    @State private var referenceMonth = Date()
    @State private var scope: StatsScope = .month
    @State private var showPicker = false

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月"
        return f
    }()

    private static let yearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年"
        return f
    }()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    hero
                    metrics
                    if slices.isEmpty {
                        emptyCard
                    } else {
                        composition
                        trend
                        if scope == .month {
                            dayList
                        }
                    }
                    memorabiliaNote
                }
                .padding(.horizontal, StatsStyle.gutter)
                .padding(.top, 4)
                .padding(.bottom, 40)
            }
            .background(StatsStyle.pageBackground)
            .navigationTitle("统计")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(StatsStyle.pageBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationDestination(for: StatsRoute.self) { route in
                switch route {
                case .typeInMonth(let type, let month):
                    ReceiptListView(filter: .typeInMonth(type, month))
                }
            }
            .navigationDestination(for: Date.self) { day in
                ReceiptListView(filter: .day(day))
            }
            .sheet(isPresented: $showPicker) {
                DatePickerSheet(scope: scope, initialDate: referenceMonth) { date in
                    withAnimation(.snappy(duration: 0.3)) { referenceMonth = date }
                }
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - 头部

    private var header: some View {
        VStack(spacing: 12) {
            StatsScopeSwitch(scope: $scope)
                .frame(maxWidth: 200)

            StatsPeriodNavigator(
                title: scope == .month
                    ? Self.monthFormatter.string(from: referenceMonth)
                    : Self.yearFormatter.string(from: referenceMonth),
                canGoBackToNow: isOffCurrentPeriod,
                onPrevious: { changeScope(-1) },
                onNext: { changeScope(1) },
                onPick: { showPicker = true },
                onBackToNow: { withAnimation(.snappy(duration: 0.3)) { referenceMonth = Date() } }
            )
        }
        .padding(.top, 6)
    }

    // MARK: - Hero

    private var hero: some View {
        StatsHeroCard(
            caption: heroCaption,
            amount: totalAmount.yuan,
            countText: "共 \(totalCount) 笔 · \(scope == .month ? "日均" : "月均") \(averageAmount.yuan)",
            delta: previousDelta,
            deltaText: previousDelta.map { String(format: "%@%.1f%%", $0 >= 0 ? "+" : "", $0 * 100) },
            sparkline: scope == .month ? dailyTotals : monthlyTotals
        )
    }

    private var heroCaption: String {
        switch scope {
        case .month: return isCurrentMonth ? "本月支出" : "该月支出"
        case .year: return isCurrentYear ? "本年支出" : "该年支出"
        }
    }

    // MARK: - 指标

    private var metrics: some View {
        let countMetric = StatsMetric(title: "笔数", value: "\(totalCount)", symbol: "list.bullet")
        let averageMetric = StatsMetric(title: scope == .month ? "日均" : "月均",
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
                path.append(StatsRoute.typeInMonth(type, referenceMonth))
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
                if scope == .month {
                    if let day = dayDate(for: index) { path.append(day) }
                } else if let date = monthDate(for: index) {
                    path.append(date)
                }
            }
        }
    }

    // MARK: - 每日明细

    private var dayList: some View {
        VStack(alignment: .leading, spacing: 10) {
            StatsSectionTitle(text: "每日明细", trailing: "\(visibleDays.count) 天")
            VStack(spacing: 0) {
                ForEach(Array(visibleDays.enumerated()), id: \.element) { index, day in
                    let receipts = monthExpenseReceipts.filter {
                        Calendar.current.isDate($0.date, inSameDayAs: day)
                    }
                    let total = receipts.compactMap(\.amount).reduce(0, +)
                    let fraction = maxDayTotal > 0 ? total / maxDayTotal : 0
                    Button {
                        Haptics.selection()
                        path.append(day)
                    } label: {
                        StatsDayRow(day: day, count: receipts.count, total: total, fraction: fraction)
                    }
                    .buttonStyle(.plain)

                    if index < visibleDays.count - 1 {
                        Divider().padding(.leading, 70).opacity(0.5)
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

    private var monthExpenseReceipts: [Receipt] {
        store.receipts(inMonthOf: referenceMonth).filter { $0.amount != nil }
    }

    private var yearExpenseReceipts: [Receipt] {
        store.receipts(inYearOf: referenceMonth).filter { $0.amount != nil }
    }

    private var expenseReceipts: [Receipt] {
        scope == .month ? monthExpenseReceipts : yearExpenseReceipts
    }

    private var totalAmount: Double {
        expenseReceipts.compactMap(\.amount).reduce(0, +)
    }

    private var totalCount: Int { expenseReceipts.count }

    private var maxReceipt: Receipt? {
        expenseReceipts.max { ($0.amount ?? 0) < ($1.amount ?? 0) }
    }

    private var dailyTotals: [Double] { store.dailyTotals(inMonthOf: referenceMonth) }
    private var monthlyTotals: [Double] { store.monthlyTotals(inYearOf: referenceMonth) }
    private var totalMemorabiliaCount: Int { store.receipts.filter { $0.amount == nil }.count }

    private var averageAmount: Double {
        let calendar = Calendar.current
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
        let component: Calendar.Component = scope == .month ? .month : .year
        guard let previous = calendar.date(byAdding: component, value: -1, to: referenceMonth) else {
            return nil
        }
        let previousReceipts = scope == .month
            ? store.receipts(inMonthOf: previous)
            : store.receipts(inYearOf: previous)
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

    private var visibleDays: [Date] {
        Set(monthExpenseReceipts.map { Calendar.current.startOfDay(for: $0.date) }).sorted(by: >)
    }

    private var maxDayTotal: Double {
        visibleDays
            .map { day in
                monthExpenseReceipts
                    .filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
                    .compactMap(\.amount)
                    .reduce(0, +)
            }
            .max() ?? 1
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

    private var isOffCurrentPeriod: Bool {
        scope == .month ? !isCurrentMonth : !isCurrentYear
    }

    private func changeScope(_ delta: Int) {
        let component: Calendar.Component = scope == .month ? .month : .year
        guard let date = Calendar.current.date(byAdding: component, value: delta, to: referenceMonth) else {
            return
        }
        referenceMonth = date
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

    var body: some View {
        VStack(spacing: 10) {
            Text(scope == .month ? "选择月份" : "选择年份")
                .font(.system(size: 15, weight: .semibold))
                .padding(.top, 18)

            Group {
                if scope == .month {
                    DatePicker("", selection: $date, displayedComponents: [.date])
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                } else {
                    Picker("", selection: $year) {
                        ForEach((currentYear - 20)...(currentYear + 1), id: \.self) { y in
                            Text("\(y)年").tag(y)
                        }
                    }
                    .pickerStyle(.wheel)
                }
            }
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
        if scope == .month {
            var components = Calendar.current.dateComponents([.year, .month], from: date)
            components.day = 1
            onSelect(Calendar.current.date(from: components) ?? date)
        } else {
            var components = Calendar.current.dateComponents([.year, .month, .day], from: initialDate)
            components.year = year
            onSelect(Calendar.current.date(from: components) ?? initialDate)
        }
    }
}
