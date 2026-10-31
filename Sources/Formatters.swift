// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import Foundation

extension Double {
    private static let yuanFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","
        return formatter
    }()

    /// 金额字符串，带千分位，如 ¥12,345.67
    var yuan: String {
        "¥" + (Self.yuanFormatter.string(from: NSNumber(value: self)) ?? String(format: "%.2f", self))
    }
}
