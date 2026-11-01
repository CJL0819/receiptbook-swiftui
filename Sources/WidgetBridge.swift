// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import Foundation
import WidgetKit

/// 主 App 与桌面小组件共享的概览数据。
struct WidgetSummary: Codable {
    var monthlyTotal: Double
    var monthCount: Int
    var memorabiliaCount: Int
}

/// 把概览数据写入 App Group 的共享 UserDefaults，供桌面小组件读取。
enum WidgetBridge {
    static let appGroupID = "group.com.receiptbook"

    static func publish(store: ReceiptStore) {
        let now = Date()
        let summary = WidgetSummary(
            monthlyTotal: store.totalAmount(inMonthOf: now),
            monthCount: store.receiptCount(inMonthOf: now),
            memorabiliaCount: store.receipts.filter { $0.amount == nil }.count
        )
        guard let data = try? JSONEncoder().encode(summary) else { return }
        UserDefaults(suiteName: appGroupID)?.set(data, forKey: "widgetSummary")
        // 主 App 每次持久化就立即刷新时间线，否则要等最多 30 分钟才会更新
        WidgetCenter.shared.reloadAllTimelines()
    }
}
