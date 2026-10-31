// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI
import UIKit

/// 票据类型
enum ReceiptType: Int, Codable, CaseIterable {
    case invoice = 0
    case receipt = 1
    case flight = 2
    case toll = 3
    case ticket = 5    // 门票
    case stub = 6      // 票根
    case other = 4     // 其他（保持 rawValue=4，兼容旧数据）

    var displayName: String {
        switch self {
        case .invoice: return "发票"
        case .receipt: return "小票"
        case .flight: return "机票"
        case .toll: return "收费条"
        case .ticket: return "门票"
        case .stub: return "票根"
        case .other: return "其他"
        }
    }

    var symbolName: String {
        switch self {
        case .invoice: return "doc.text"
        case .receipt: return "doc.text.image"
        case .flight: return "airplane"
        case .toll: return "car.fill"
        case .ticket: return "ticket"
        case .stub: return "ticket.fill"
        case .other: return "square.grid.2x2"
        }
    }

    var tintColor: Color {
        switch self {
        case .invoice: return Color(uiColor: .systemBlue)
        case .receipt: return Color(uiColor: .systemGreen)
        case .flight: return Color(uiColor: .systemPurple)
        case .toll: return Color(uiColor: .systemOrange)
        case .ticket: return Color(uiColor: .systemPink)
        case .stub: return Color(uiColor: .systemTeal)
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
struct Receipt: Codable, Identifiable, Equatable {
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
        date = Date(timeIntervalSince1970: try container.decodeIfPresent(Double.self, forKey: .date) ?? 0)
        amount = try container.decodeIfPresent(Double.self, forKey: .amount)
        merchant = try container.decodeIfPresent(String.self, forKey: .merchant) ?? ""
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        pageCount = try container.decodeIfPresent(Int.self, forKey: .pageCount) ?? 0
        location = try container.decodeIfPresent(String.self, forKey: .location)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        mood = try container.decodeIfPresent(Mood.self, forKey: .mood)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        createdAt = Date(timeIntervalSince1970: try container.decodeIfPresent(Double.self, forKey: .createdAt) ?? 0)
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
