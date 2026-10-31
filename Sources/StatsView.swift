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
    @State private var pickerDate = Date()

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
            List {
                if store.receipts.isEmpty {
                    Text("还没有票据，去「扫描」页添加第一张吧。")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                        .listRowBackground(Color.clear)
                } else {
                    Section {
                        summarySection
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }

                    Section("分类") {
                        ForEach(visibleTypes, id: \.self) { type in
                            let receipts = expenseReceipts.filter { $0.type == type }
                            let total = receipts.compactMap(\.amount).reduce(0, +)
                            let fraction = totalAmount > 0 ? total / totalAmount : 0
                            NavigationLink(value: StatsRoute.typeInMonth(type, referenceMonth)) {
                                CategoryRow(type: type, count: receipts.count, total: total, fraction: fraction)
                            }
                        }
                    }

                    if scope == .month {
                        Section("按日期") {
                            ForEach(visibleDays, id: \.self) { day in
                                let receipts = monthExpenseReceipts.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
                                let total = receipts.compactMap(\.amount).reduce(0, +)
                                NavigationLink(value: day) {
                                    DayRow(day: day, count: receipts.count, total: total)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("统计")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: StatsRoute.self) { route in
                switch route {
                case .typeInMonth(let type, let month):
                    ReceiptListView(filter: .typeInMonth(type, month))
                }
            }
            .navigationDestination(for: Date.self) { day in
                ReceiptListView(filter: .day(day))
            }
        }
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
    private var totalAmount: Double { expenseReceipts.compactMap(\.amount).reduce(0, +) }
    private var totalCount: Int { expenseReceipts.count }
    private var dailyTotals: [Double] { store.dailyTotals(inMonthOf: referenceMonth) }
    private var monthlyTotals: [Double] { store.monthlyTotals(inYearOf: referenceMonth) }
    private var totalMemorabiliaCount: Int { store.receipts.filter { $0.amount == nil }.count }

    private var monthAverage: Double {
        let calendar = Calendar.current
        let days: Int
        if calendar.isDate(referenceMonth, equalTo: Date(), toGranularity: .month) {
            days = calendar.component(.day, from: Date())
        } else {
            days = calendar.range(of: .day, in: .month, for: referenceMonth)?.count ?? 30
        }
        return days > 0 ? totalAmount / Double(days) : 0
    }

    private var yearAverage: Double {
        let calendar = Calendar.current
        let months: Int
        if calendar.isDate(referenceMonth, equalTo: Date(), toGranularity: .year) {
            months = calendar.component(.month, from: Date())
        } else {
            months = 12
        }
        return months > 0 ? totalAmount / Double(months) : 0
    }

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(referenceMonth, equalTo: Date(), toGranularity: .month)
    }
    private var isCurrentYear: Bool {
        Calendar.current.isDate(referenceMonth, equalTo: Date(), toGranularity: .year)
    }

    private var visibleTypes: [ReceiptType] {
        let byType = Dictionary(grouping: expenseReceipts, by: { $0.type })
            .mapValues { $0.compactMap(\.amount).reduce(0, +) }
        return ReceiptType.allCases.filter { (byType[$0] ?? 0) > 0 }
    }

    private var visibleDays: [Date] {
        Set(monthExpenseReceipts.map { Calendar.current.startOfDay(for: $0.date) }).sorted(by: >)
    }

    // MARK: - 汇总

    private var summarySection: some View {
        VStack(spacing: 12) {
            Picker("", selection: $scope) {
                ForEach(StatsScope.allCases) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 240)
            .frame(maxWidth: .infinity)

            navigator
            heroCard
            if totalMemorabiliaCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "bookmark")
                    Text("已收藏纪念票据 \(totalMemorabiliaCount) 张（不计入统计）")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            metricCards
            chart
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    private var navigator: some View {
        HStack {
            Button { changeScope(-1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Button {
                    pickerDate = referenceMonth
                    showPicker = true
                } label: {
                    Text(scope == .month
                         ? Self.monthFormatter.string(from: referenceMonth)
                         : Self.yearFormatter.string(from: referenceMonth))
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)

                Button(scope == .month ? "回到本月" : "回到今年") {
                    referenceMonth = Date()
                }
                .buttonStyle(.borderless)
                .font(.footnote)
                .foregroundStyle(.blue)
                .opacity(shouldShowBackToCurrent ? 1 : 0)
                .disabled(!shouldShowBackToCurrent)
            }

            Spacer(minLength: 0)

            Button { changeScope(1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
        }
        .padding(.top, 4)
        .sheet(isPresented: $showPicker) {
            DatePickerSheet(scope: scope, initialDate: pickerDate) { date in
                referenceMonth = date
            }
            .presentationDetents([.height(300)])
        }
    }

    private var shouldShowBackToCurrent: Bool {
        (scope == .month && !isCurrentMonth) || (scope == .year && !isCurrentYear)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(scope == .month ? (isCurrentMonth ? "本月支出" : "该月支出") : "本年支出")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(totalAmount.yuan)
                .font(.system(size: 34, weight: .semibold, design: .monospaced))
            Text(scope == .month
                 ? "共 \(totalCount) 笔 · 日均 \(monthAverage.yuan)"
                 : "共 \(totalCount) 笔 · 月均 \(yearAverage.yuan)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(cardBackground)
    }

    @ViewBuilder
    private var metricCards: some View {
        if scope == .month {
            HStack(spacing: 12) {
                metricCard(title: "今日支出", value: store.totalAmount(on: Date()).yuan)
                metricCard(title: "累计支出", value: store.totalAmount.yuan)
            }
            HStack(spacing: 12) {
                metricCard(title: "本月日均", value: monthAverage.yuan)
                metricCard(title: "本月笔数", value: "\(totalCount)")
            }
        } else {
            HStack(spacing: 12) {
                metricCard(title: "本年笔数", value: "\(totalCount)")
                metricCard(title: "月均支出", value: yearAverage.yuan)
            }
            HStack(spacing: 12) {
                metricCard(title: "纪念收藏", value: "\(totalMemorabiliaCount) 张")
                metricCard(title: "累计支出", value: store.totalAmount.yuan)
            }
        }
    }

    @ViewBuilder
    private var chart: some View {
        if scope == .month {
            DailyBarChartView(values: dailyTotals) { day in
                var components = Calendar.current.dateComponents([.year, .month], from: referenceMonth)
                components.day = day
                if let date = Calendar.current.date(from: components) {
                    path.append(date)
                }
            }
        } else {
            yearChartCard
        }
    }

    private var yearChartCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("每月支出")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text((monthlyTotals.max() ?? 0).yuan)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            let maxValue = max(monthlyTotals.max() ?? 0, 1)
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<12, id: \.self) { i in
                    let h = monthlyTotals[i] <= 0 ? 0 : max(CGFloat(monthlyTotals[i] / maxValue) * 78, 2)
                    VStack(spacing: 3) {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.accentColor)
                            .frame(height: h)
                            .opacity(monthlyTotals[i] > 0 ? 1 : 0)
                        Text(yearMonthLabel(i))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 92)
                }
            }
        }
        .padding(12)
        .background(cardBackground)
    }

    private func yearMonthLabel(_ index: Int) -> String {
        "\(index + 1)月"
    }

    private func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        Color(.secondarySystemBackground).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func changeScope(_ delta: Int) {
        let component: Calendar.Component = scope == .month ? .month : .year
        guard let date = Calendar.current.date(byAdding: component, value: delta, to: referenceMonth) else { return }
        referenceMonth = date
    }
}

// MARK: - 分类行

struct CategoryRow: View {
    let type: ReceiptType
    let count: Int
    let total: Double
    let fraction: Double

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.symbolName)
                .foregroundStyle(type.tintColor)
                .frame(width: 26)
            VStack(spacing: 6) {
                HStack {
                    Text(type.displayName)
                    Spacer()
                    Text("\(count) 笔 · \(total.yuan)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: fraction)
                    .tint(type.tintColor)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 日期行

struct DayRow: View {
    let day: Date
    let count: Int
    let total: Double

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter
    }()

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .foregroundStyle(Color.accentColor)
                .frame(width: 26)
            Text(Self.formatter.string(from: day))
            Spacer()
            Text("\(count) 笔 · \(total.yuan)")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
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
        VStack(spacing: 8) {
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

            HStack {
                Button("取消") { dismiss() }
                    .buttonStyle(.bordered)
                Spacer()
                Button("确定") {
                    confirm()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 4)
        }
        .padding(.top, 16)
    }

    private func confirm() {
        if scope == .month {
            var comps = Calendar.current.dateComponents([.year, .month], from: date)
            comps.day = 1
            onSelect(Calendar.current.date(from: comps) ?? date)
        } else {
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: initialDate)
            comps.year = year
            onSelect(Calendar.current.date(from: comps) ?? initialDate)
        }
    }
}
