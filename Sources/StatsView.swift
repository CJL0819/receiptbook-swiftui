// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI

/// 统计页「分类」跳转路由（类型 + 月份）。
enum StatsRoute: Hashable {
    case typeInMonth(ReceiptType, Date)
}

struct StatsView: View {
    @EnvironmentObject private var store: ReceiptStore
    @State private var path = NavigationPath()
    @State private var referenceMonth = Date()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        return formatter
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
                            let receipts = monthExpenseReceipts.filter { $0.type == type }
                            let total = receipts.compactMap(\.amount).reduce(0, +)
                            let fraction = monthTotal > 0 ? total / monthTotal : 0
                            NavigationLink(value: StatsRoute.typeInMonth(type, referenceMonth)) {
                                CategoryRow(type: type, count: receipts.count, total: total, fraction: fraction)
                            }
                        }
                    }

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
            .navigationTitle("统计")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !store.receipts.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        ExportButton()
                    }
                }
            }
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

    // MARK: - 数据（统计仅包含有金额的票据）

    private var monthExpenseReceipts: [Receipt] {
        store.receipts(inMonthOf: referenceMonth).filter { $0.amount != nil }
    }
    private var monthTotal: Double { monthExpenseReceipts.compactMap(\.amount).reduce(0, +) }
    private var monthCount: Int { monthExpenseReceipts.count }
    private var dailyTotals: [Double] { store.dailyTotals(inMonthOf: referenceMonth) }

    private var totalMemorabiliaCount: Int {
        store.receipts.filter { $0.amount == nil }.count
    }

    private var monthAverage: Double {
        let calendar = Calendar.current
        let days: Int
        if calendar.isDate(referenceMonth, equalTo: Date(), toGranularity: .month) {
            days = calendar.component(.day, from: Date())
        } else {
            days = calendar.range(of: .day, in: .month, for: referenceMonth)?.count ?? 30
        }
        return days > 0 ? monthTotal / Double(days) : 0
    }

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(referenceMonth, equalTo: Date(), toGranularity: .month)
    }

    private var visibleTypes: [ReceiptType] {
        let byType = Dictionary(grouping: monthExpenseReceipts, by: { $0.type })
            .mapValues { $0.compactMap(\.amount).reduce(0, +) }
        return ReceiptType.allCases.filter { (byType[$0] ?? 0) > 0 }
    }

    private var visibleDays: [Date] {
        Set(monthExpenseReceipts.map { Calendar.current.startOfDay(for: $0.date) }).sorted(by: >)
    }

    // MARK: - 汇总卡片

    private var summarySection: some View {
        VStack(spacing: 12) {
            monthNavigator
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
            HStack(spacing: 12) {
                metricCard(title: "今日支出", value: money(store.totalAmount(on: Date())))
                metricCard(title: "累计支出", value: money(store.totalAmount))
            }
            HStack(spacing: 12) {
                metricCard(title: "本月日均", value: money(monthAverage))
                metricCard(title: "本月笔数", value: "\(monthCount)")
            }
            DailyBarChartView(values: dailyTotals) { day in
                var components = Calendar.current.dateComponents([.year, .month], from: referenceMonth)
                components.day = day
                if let date = Calendar.current.date(from: components) {
                    path.append(date)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private var monthNavigator: some View {
        VStack(spacing: 6) {
            HStack {
                Button { changeMonth(-1) } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 36, height: 32)
                }
                Spacer()
                Text(Self.monthFormatter.string(from: referenceMonth))
                    .font(.headline)
                Spacer()
                Button { changeMonth(1) } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 36, height: 32)
                }
            }
            if !isCurrentMonth {
                Button("回到本月") {
                    referenceMonth = Date()
                }
                .font(.footnote)
                .foregroundStyle(.blue)
            }
        }
        .padding(.top, 4)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(isCurrentMonth ? "本月支出" : "该月支出")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(money(monthTotal))
                .font(.system(size: 34, weight: .semibold, design: .monospaced))
            Text("共 \(monthCount) 笔 · 日均 \(money(monthAverage))")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(cardBackground)
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

    private func money(_ value: Double) -> String {
        String(format: "¥%.2f", value)
    }

    private func changeMonth(_ delta: Int) {
        guard let date = Calendar.current.date(byAdding: .month, value: delta, to: referenceMonth) else { return }
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
                    Text("\(count) 笔 · \(String(format: "¥%.2f", total))")
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
        HStack {
            Text(Self.formatter.string(from: day))
            Spacer()
            Text("\(count) 笔 · \(String(format: "¥%.2f", total))")
                .foregroundStyle(.secondary)
        }
    }
}
