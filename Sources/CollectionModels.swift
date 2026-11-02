// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import Foundation

// MARK: - 路由

/// 收藏馆内部的页面路由：详情与专题都走同一条 NavigationStack。
enum CollectionRoute: Hashable {
    case detail(Receipt)
    case album(String)
}

// MARK: - 排序

enum CollectionSortOrder: String, CaseIterable, Identifiable {
    case newest
    case oldest
    case place
    case type

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newest: return "最近收藏"
        case .oldest: return "最早收藏"
        case .place: return "按地点"
        case .type: return "按类型"
        }
    }

    var isDefault: Bool { self == .newest }
}

// MARK: - 筛选

struct CollectionFilter: Equatable {
    var year: Int?
    var type: ReceiptType?
    var mood: Mood?
    var tag: String?
    var sort: CollectionSortOrder = .newest

    var isActive: Bool {
        year != nil || type != nil || mood != nil || tag != nil
    }

    /// 「编目」里真正需要清除的条件数（排序不算条件）
    var activeCount: Int {
        [year != nil, type != nil, mood != nil, tag != nil].filter { $0 }.count
    }

    mutating func reset() {
        self = CollectionFilter()
    }

    func matches(_ receipt: Receipt) -> Bool {
        if let year,
           Calendar.current.component(.year, from: receipt.date) != year {
            return false
        }
        if let type, receipt.type != type { return false }
        if let mood, receipt.mood != mood { return false }
        if let tag, !receipt.tags.contains(tag) { return false }
        return true
    }
}

// MARK: - 编目数据

struct CollectionEntry: Identifiable, Hashable {
    let receipt: Receipt

    var id: String { receipt.id }

    var title: String {
        receipt.merchant.isEmpty ? receipt.type.displayName : receipt.merchant
    }

    var place: String? {
        guard let location = receipt.location?.trimmingCharacters(in: .whitespacesAndNewlines),
              !location.isEmpty else { return nil }
        return location
    }
}

struct CollectionYearGroup: Identifiable {
    let year: Int
    let items: [CollectionEntry]
    var id: Int { year }
}

struct CollectionTagCount: Identifiable {
    let tag: String
    let count: Int
    var id: String { tag }
}

struct CollectionMoodCount: Identifiable {
    let mood: Mood
    let count: Int
    var id: String { mood.rawValue }
}

struct CollectionTypeCount: Identifiable {
    let type: ReceiptType
    let count: Int
    var id: Int { type.rawValue }
}

/// 一次性的收藏编目：把 Receipts 收敛成页面需要的一切。
/// 数据量是个人票据级别（几百条），直接算即可，不做缓存以免状态不同步。
struct CollectionCatalog {
    let entries: [CollectionEntry]

    init(receipts: [Receipt]) {
        let memorabilia = receipts
            .filter { $0.amount == nil }
            .sorted { $0.date > $1.date }
        entries = memorabilia.map { CollectionEntry(receipt: $0) }
    }

    var isEmpty: Bool { entries.isEmpty }

    var count: Int { entries.count }

    var years: [Int] {
        Set(entries.map { Calendar.current.component(.year, from: $0.receipt.date) })
            .sorted(by: >)
    }

    var places: [String] {
        var seen = Set<String>()
        for entry in entries {
            if let place = entry.place { seen.insert(place) }
        }
        return seen.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var tags: [CollectionTagCount] {
        var counts: [String: Int] = [:]
        for entry in entries {
            for tag in entry.receipt.tags where !tag.isEmpty {
                counts[tag, default: 0] += 1
            }
        }
        return counts
            .map { CollectionTagCount(tag: $0.key, count: $0.value) }
            .sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                return $0.tag.localizedStandardCompare($1.tag) == .orderedAscending
            }
    }

    var moods: [CollectionMoodCount] {
        Mood.allCases.compactMap { mood in
            let count = entries.filter { $0.receipt.mood == mood }.count
            return count > 0 ? CollectionMoodCount(mood: mood, count: count) : nil
        }
    }

    var types: [CollectionTypeCount] {
        ReceiptType.allCases.compactMap { type in
            let count = entries.filter { $0.receipt.type == type }.count
            return count > 0 ? CollectionTypeCount(type: type, count: count) : nil
        }
    }

    /// 标题下的一句话：件数与地方数，保持一行可读。
    var summary: String {
        guard !entries.isEmpty else { return "还没有藏品。" }
        var parts = ["\(count) 件藏品"]
        let placeCount = places.count
        if placeCount > 0 { parts.append("来自 \(placeCount) 个地方") }
        return parts.joined(separator: "，") + "。"
    }

    /// 本期典藏：有心情、有地点、有标签的优先，再按时间。
    var featured: [CollectionEntry] {
        featured(from: entries)
    }

    /// 本期典藏：可以只看某一筛选结果里的藏品，避免头图与下方的编目对不上。
    func featured(from pool: [CollectionEntry], limit: Int = 5) -> [CollectionEntry] {
        pool
            .sorted { lhs, rhs in
                let left = score(lhs)
                let right = score(rhs)
                if left != right { return left > right }
                return lhs.receipt.date > rhs.receipt.date
            }
            .prefix(limit)
            .sorted { $0.receipt.date > $1.receipt.date }
    }

    private func score(_ entry: CollectionEntry) -> Int {
        var score = 0
        if entry.receipt.mood != nil { score += 4 }
        if entry.place != nil { score += 2 }
        if !entry.receipt.tags.isEmpty { score += 2 }
        if entry.receipt.pageCount > 0 { score += 1 }
        return score
    }

    /// 应用筛选与搜索，并按当前排序返回。
    func filtered(by filter: CollectionFilter, search text: String = "") -> [CollectionEntry] {
        var result = entries.filter { filter.matches($0.receipt) }
        let keyword = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !keyword.isEmpty {
            result = result.filter { entry in
                let receipt = entry.receipt
                return receipt.merchant.localizedCaseInsensitiveContains(keyword)
                    || receipt.note.localizedCaseInsensitiveContains(keyword)
                    || receipt.type.displayName.localizedCaseInsensitiveContains(keyword)
                    || (receipt.location?.localizedCaseInsensitiveContains(keyword) ?? false)
                    || (receipt.address?.localizedCaseInsensitiveContains(keyword) ?? false)
                    || receipt.tags.contains { $0.localizedCaseInsensitiveContains(keyword) }
            }
        }
        return sorted(result, by: filter.sort)
    }

    func sorted(_ items: [CollectionEntry], by order: CollectionSortOrder) -> [CollectionEntry] {
        switch order {
        case .newest:
            return items.sorted { $0.receipt.date > $1.receipt.date }
        case .oldest:
            return items.sorted { $0.receipt.date < $1.receipt.date }
        case .place:
            return items.sorted {
                let lhs = $0.place ?? "\u{FFFF}"
                let rhs = $1.place ?? "\u{FFFF}"
                if lhs == rhs { return $0.receipt.date > $1.receipt.date }
                return lhs.localizedStandardCompare(rhs) == .orderedAscending
            }
        case .type:
            return items.sorted {
                if $0.receipt.type.rawValue == $1.receipt.type.rawValue {
                    return $0.receipt.date > $1.receipt.date
                }
                return $0.receipt.type.rawValue < $1.receipt.type.rawValue
            }
        }
    }

    func groupedByYear(_ items: [CollectionEntry]) -> [CollectionYearGroup] {
        let groups = Dictionary(grouping: items) {
            Calendar.current.component(.year, from: $0.receipt.date)
        }
        return groups
            .map { CollectionYearGroup(year: $0.key, items: $0.value) }
            .sorted { $0.year > $1.year }
    }

    /// 同系列：心情相同，或至少共享一个标签。
    func related(to receipt: Receipt, limit: Int = 6) -> [CollectionEntry] {
        entries
            .filter { $0.receipt.id != receipt.id }
            .filter { entry in
                if let mood = receipt.mood, entry.receipt.mood == mood { return true }
                return !Set(entry.receipt.tags).isDisjoint(with: Set(receipt.tags))
            }
            .sorted { $0.receipt.date > $1.receipt.date }
            .prefix(limit)
            .map { $0 }
    }
}
