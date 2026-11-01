// SPDX-License-Identifier: MIT
// Copyright (c) 2026
//
// 桌面小组件（WidgetKit）
//
// 注意：小组件是独立的 App Extension 目标，由 project.yml 里的 ReceiptWidget target 编译。
//
// 在 Xcode 工程中使用：
//   1. 新建一个 Widget Extension target（勾选 WidgetKit）。
//   2. 把本文件加入该 target。
//   3. 主 App 与小组件都开启 App Group，并填写相同 ID：group.com.receiptbook。
//   4. 主 App 已在每次持久化后通过 WidgetBridge 把概览写入共享 UserDefaults。
//
import WidgetKit
import SwiftUI

struct ReceiptEntry: TimelineEntry {
    let date: Date
    let monthlyTotal: Double
    let monthCount: Int
    let memorabiliaCount: Int
}

struct ReceiptProvider: TimelineProvider {
    struct Summary: Codable {
        var monthlyTotal: Double
        var monthCount: Int
        var memorabiliaCount: Int
    }

    func placeholder(in context: Context) -> ReceiptEntry {
        ReceiptEntry(date: Date(), monthlyTotal: 0, monthCount: 0, memorabiliaCount: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (ReceiptEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReceiptEntry>) -> Void) {
        let entry = Self.loadEntry()
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    static func loadEntry() -> ReceiptEntry {
        guard let data = UserDefaults(suiteName: "group.com.receiptbook")?.data(forKey: "widgetSummary"),
              let summary = try? JSONDecoder().decode(Summary.self, from: data) else {
            return ReceiptEntry(date: Date(), monthlyTotal: 0, monthCount: 0, memorabiliaCount: 0)
        }
        return ReceiptEntry(date: Date(),
                            monthlyTotal: summary.monthlyTotal,
                            monthCount: summary.monthCount,
                            memorabiliaCount: summary.memorabiliaCount)
    }
}

struct ReceiptWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: ReceiptEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("小票收纳", systemImage: "doc.text.image")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                if family != .systemSmall {
                    Text("本月")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
            Text(String(format: "¥%.2f", entry.monthlyTotal))
                .font(.system(.title2, design: .rounded).bold())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            HStack(spacing: 10) {
                Text("\(entry.monthCount) 笔")
                Text("收藏 \(entry.memorabiliaCount)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
    }
}

struct ReceiptWidget: Widget {
    let kind = "ReceiptWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReceiptProvider()) { entry in
            ReceiptWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) { Color(.systemBackground) }
        }
        .configurationDisplayName("小票收纳")
        .description("本月支出与收藏概览")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct ReceiptWidgetBundle: WidgetBundle {
    var body: some Widget {
        ReceiptWidget()
    }
}
