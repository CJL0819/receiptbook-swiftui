// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI
import UIKit

/// 票据类型
///
/// 声明顺序即 `allCases` 顺序，也就是筛选条里胶囊的排列顺序：
/// 小票、门票、车票、机票、发票、收费条、其他。
/// rawValue 保持不变以兼容已有数据（6 号位由「票根」改为「车票」）。
enum ReceiptType: Int, Codable, CaseIterable {
    case receipt = 1    // 小票
    case ticket = 5     // 门票
    case train = 6      // 车票
    case flight = 2     // 机票
    case invoice = 0    // 发票
    case toll = 3       // 收费条
    case other = 4      // 其他

    var displayName: String {
        switch self {
        case .receipt: return "小票"
        case .ticket: return "门票"
        case .train: return "车票"
        case .flight: return "机票"
        case .invoice: return "发票"
        case .toll: return "收费条"
        case .other: return "其他"
        }
    }

    var symbolName: String {
        switch self {
        case .receipt: return "doc.text.image"
        case .ticket: return "ticket"
        case .train: return "train.side.front.car"
        case .flight: return "airplane"
        case .invoice: return "doc.text"
        case .toll: return "car.fill"
        case .other: return "square.grid.2x2"
        }
    }

    var tintColor: Color {
        switch self {
        case .receipt: return Color(uiColor: .systemGreen)
        case .ticket: return Color(uiColor: .systemPink)
        case .train: return Color(uiColor: .systemTeal)
        case .flight: return Color(uiColor: .systemPurple)
        case .invoice: return Color(uiColor: .systemBlue)
        case .toll: return Color(uiColor: .systemOrange)
        case .other: return Color(uiColor: .systemGray)
        }
    }
}

/// 收藏心情
enum Mood: String, Codable, CaseIterable, Identifiable {
    case happy = "😄 开心"
    case excited = "🤩 惊喜"
    case moved = "🥹 感动"
    case calm = "😌 平静"
    case regret = "😢 遗憾"
    var id: String { rawValue }

    var color: Color {
        switch self {
        case .happy: return Color(uiColor: .systemYellow)
        case .excited: return Color(uiColor: .systemOrange)
        case .moved: return Color(uiColor: .systemPink)
        case .calm: return Color(uiColor: .systemTeal)
        case .regret: return Color(uiColor: .systemIndigo)
        }
    }
}

/// 一张票据。
/// 金额（amount）为 nil 表示「纪念收藏」，有值才参与记账与统计。
/// 地点 / 心情 / 标签主要服务于收藏票据，均为可选。
struct Receipt: Codable, Identifiable, Equatable, Hashable {
    var id: String
    var type: ReceiptType
    var date: Date
    var amount: Double?
    var merchant: String
    var note: String
    var pageCount: Int
    var createdAt: Date

    var location: String?   // 地点
    var address: String?    // 具体地址
    var mood: Mood?         // 心情
    var tags: [String]      // 标签

    var isMemorabilia: Bool { amount == nil }
    var isExpense: Bool { amount != nil }

    init(type: ReceiptType,
         date: Date = Date(),
         amount: Double?,
         merchant: String = "",
         note: String = "",
         pageCount: Int = 0,
         location: String? = nil,
         address: String? = nil,
         mood: Mood? = nil,
         tags: [String] = []) {
        self.id = UUID().uuidString
        self.type = type
        self.date = date
        self.amount = amount
        self.merchant = merchant
        self.note = note
        self.pageCount = pageCount
        self.location = location
        self.address = address
        self.mood = mood
        self.tags = tags
        self.createdAt = Date()
    }

    private enum CodingKeys: String, CodingKey {
        case id, type, amount, merchant, note, pageCount
        case date, createdAt, location, address, mood, tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        let rawType = try container.decodeIfPresent(Int.self, forKey: .type) ?? ReceiptType.other.rawValue
        type = ReceiptType(rawValue: rawType) ?? .other
        date = Self.decodeDate(container, forKey: .date)
        amount = try container.decodeIfPresent(Double.self, forKey: .amount)
        merchant = try container.decodeIfPresent(String.self, forKey: .merchant) ?? ""
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        pageCount = try container.decodeIfPresent(Int.self, forKey: .pageCount) ?? 0
        location = try container.decodeIfPresent(String.self, forKey: .location)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        // 未知心情按「无」处理：不能让一条脏数据把整个索引解崩（否则会静默回退旧备份）
        mood = (try container.decodeIfPresent(String.self, forKey: .mood)).flatMap(Mood.init(rawValue:))
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        createdAt = Self.decodeDate(container, forKey: .createdAt)
    }

    /// 兼容「Unix 时间戳」与「ISO8601 字符串」两种历史写法；缺失时保持原行为（1970）。
    private static func decodeDate(_ container: KeyedDecodingContainer<CodingKeys>,
                                   forKey key: CodingKeys) -> Date {
        if let timestamp = try? container.decodeIfPresent(Double.self, forKey: key) {
            return Date(timeIntervalSince1970: timestamp)
        }
        if let raw = try? container.decodeIfPresent(String.self, forKey: key),
           let date = ISO8601DateFormatter().date(from: raw) {
            return date
        }
        return Date(timeIntervalSince1970: 0)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type.rawValue, forKey: .type)
        try container.encodeIfPresent(amount, forKey: .amount)
        try container.encode(date.timeIntervalSince1970, forKey: .date)
        try container.encode(merchant, forKey: .merchant)
        try container.encode(note, forKey: .note)
        try container.encode(pageCount, forKey: .pageCount)
        try container.encode(createdAt.timeIntervalSince1970, forKey: .createdAt)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encodeIfPresent(address, forKey: .address)
        try container.encodeIfPresent(mood, forKey: .mood)
        if !tags.isEmpty {
            try container.encode(tags, forKey: .tags)
        }
    }
}

extension String {
    /// 把「逗号 / 顿号 / 分号 / 空白」分隔的输入解析成标签：去空、去重、保持顺序。
    var parsedTags: [String] {
        var seen = Set<String>()
        return split { " ,，、;；\n\t".contains($0) }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}
