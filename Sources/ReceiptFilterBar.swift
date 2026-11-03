// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI

/// 排序方式：日期/金额 各两个方向。
enum ReceiptSortOrder: String, CaseIterable, Identifiable {
    case dateNewest
    case dateOldest
    case amountHigh
    case amountLow

    var id: String { rawValue }

    /// 菜单里的完整描述
    var menuTitle: String {
        switch self {
        case .dateNewest: return "日期 · 新到旧"
        case .dateOldest: return "日期 · 旧到新"
        case .amountHigh: return "金额 · 高到低"
        case .amountLow: return "金额 · 低到高"
        }
    }

    /// 胶囊上显示的精简文案
    var compactTitle: String {
        switch self {
        case .dateNewest: return "最新"
        case .dateOldest: return "最早"
        case .amountHigh: return "金额 ↓"
        case .amountLow: return "金额 ↑"
        }
    }

    var symbolName: String {
        switch self {
        case .dateNewest, .dateOldest: return "calendar"
        case .amountHigh, .amountLow: return "yensign"
        }
    }

    var isDefault: Bool { self == .dateNewest }

    func areInIncreasingOrder(_ lhs: Receipt, _ rhs: Receipt) -> Bool {
        switch self {
        case .dateNewest: return lhs.date > rhs.date
        case .dateOldest: return lhs.date < rhs.date
        case .amountHigh: return (lhs.amount ?? 0) > (rhs.amount ?? 0)
        case .amountLow: return (lhs.amount ?? 0) < (rhs.amount ?? 0)
        }
    }
}

/// 列表上方的筛选 + 排序条：横向滚动的类型胶囊 + 固定在右侧的排序入口。
struct ReceiptFilterBar: View {
    @Binding var selectedType: ReceiptType?
    @Binding var sortOrder: ReceiptSortOrder
    let availableTypes: [ReceiptType]
    let resultCount: Int
    /// 类型已经固定时（从统计页进入），只保留排序，平铺一行
    var showsTypeChips: Bool = true

    private var barBackground: Color { Color(uiColor: .systemGroupedBackground) }

    var body: some View {
        if showsTypeChips {
            // 没有结果时胶囊条也收起来，和「类型子页面」的空态保持同一套表现
            if resultCount > 0 {
                chipsBar
            } else {
                Color.clear.frame(height: 0)
            }
        } else {
            flatSortBar
        }
    }

    /// 只有排序的平铺一行（无胶囊、无底色块）
    private var flatSortBar: some View {
        Group {
            if resultCount > 0 {
                flatSortContent
            } else {
                Color.clear.frame(height: 0)
            }
        }
    }

    private var flatSortContent: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            Menu {
                Picker("排序", selection: $sortOrder) {
                    ForEach(ReceiptSortOrder.allCases) { order in
                        Text(order.menuTitle).tag(order)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 10, weight: .bold))
                    Text(sortOrder.compactTitle)
                        .font(.system(size: 13, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(sortOrder.isDefault ? Color.secondary : Color.accentColor)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("filter.sort")
            .onChange(of: sortOrder) { Haptics.selection() }
            .padding(.trailing, 16)
        }
        .frame(height: 34)
        .padding(.vertical, 8)
        .background(barBackground)
    }

    private var chipsBar: some View {
        HStack(spacing: 0) {
            // 类型胶囊：横向滚动，右端用渐变淡出（滚动区在排序按钮之前结束，不会互相压住）
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip(title: "全部",
                         symbol: "square.grid.2x2",
                         tint: Color(uiColor: .label),
                         isSelected: selectedType == nil,
                         identifier: "filter.type.all") {
                        select(nil)
                    }

                    ForEach(availableTypes, id: \.rawValue) { type in
                        chip(title: type.displayName,
                             symbol: type.symbolName,
                             tint: type.tintColor,
                             isSelected: selectedType == type,
                             identifier: "filter.type.\(type.displayName)") {
                            select(selectedType == type ? nil : type)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 2)
            }
            .frame(height: 34)
            .mask(
                LinearGradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.02),
                    .init(color: .black, location: 0.965),
                    .init(color: .clear, location: 1),
                ], startPoint: .leading, endPoint: .trailing)
            )

            if resultCount > 0 {
                sortMenu
                    .padding(.leading, 10)
                    .padding(.trailing, 16)
                    .frame(height: 34)
            } else {
                Color.clear.frame(width: 16)
            }
        }
        .padding(.vertical, 8)
        .background(barBackground)
    }

    // MARK: - 类型胶囊

    private func chip(title: String,
                      symbol: String,
                      tint: Color,
                      isSelected: Bool,
                      identifier: String,
                      action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            withAnimation(.snappy(duration: 0.24)) { action() }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.72))
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background {
                Capsule(style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(Color(uiColor: .secondarySystemGroupedBackground)))
                    .shadow(color: .black.opacity(isSelected ? 0.10 : 0.04),
                            radius: isSelected ? 5 : 3, y: 1)
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(isSelected ? Color.white.opacity(0.16) : Color.primary.opacity(0.06),
                                  lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - 排序

    private var sortMenu: some View {
        Menu {
            Picker("排序", selection: $sortOrder) {
                ForEach(ReceiptSortOrder.allCases) { order in
                    Text(order.menuTitle)
                        .tag(order)
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 11, weight: .bold))
                Text(sortOrder.compactTitle)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(sortOrder.isDefault ? Color.primary.opacity(0.72) : Color.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                Capsule(style: .continuous)
                    .fill(sortOrder.isDefault
                          ? AnyShapeStyle(Color(uiColor: .secondarySystemGroupedBackground))
                          : AnyShapeStyle(Color.accentColor))
                    .shadow(color: .black.opacity(sortOrder.isDefault ? 0.04 : 0.10), radius: 3, y: 1)
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(sortOrder.isDefault ? Color.primary.opacity(0.06) : Color.white.opacity(0.16),
                                  lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("filter.sort")
        .onChange(of: sortOrder) { Haptics.selection() }
    }

    private func select(_ type: ReceiptType?) {
        selectedType = type
    }
}
