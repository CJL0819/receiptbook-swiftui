// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI
import UIKit

// MARK: - 本期精选

/// 首屏的大图：图在上、文字在下，不加遮罩标签，也不做票根形状。
struct CollectionFeaturedCard: View {
    let entry: CollectionEntry
    @EnvironmentObject private var store: ReceiptStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            image
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title)
                    .font(.system(size: 19, weight: .semibold))
                    .tracking(-0.2)
                    .foregroundStyle(CollectionColor.ink)
                    .lineLimit(1)

                Text(meta)
                    .font(.system(size: 12.5))
                    .foregroundStyle(CollectionColor.secondary)
                    .lineLimit(1)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.title)，\(CollectionDate.full.string(from: entry.receipt.date))")
    }

    private var image: some View {
        ZStack {
            CollectionColor.fill

            if let image = store.previewImage(for: entry.receipt, page: 0, maxPixel: 1200) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .shadow(color: Color.black.opacity(0.10), radius: 12, y: 6)
                    .padding(18)
            } else {
                Image(systemName: entry.receipt.type.symbolName)
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(CollectionColor.tertiary)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: CollectionMetrics.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: CollectionMetrics.cardRadius, style: .continuous)
                .strokeBorder(CollectionColor.hairline, lineWidth: 0.6)
        }
    }

    private var meta: String {
        var parts = [CollectionDate.dotted.string(from: entry.receipt.date)]
        if let place = entry.place { parts.append(place) }
        if let mood = entry.receipt.mood { parts.append(mood.label) }
        return parts.joined(separator: " · ")
    }
}

struct CollectionFeaturedCarousel: View {
    let entries: [CollectionEntry]
    @Binding var selection: String?

    private var cardWidth: CGFloat {
        min(UIScreen.main.bounds.width - CollectionMetrics.gutter * 2, 520)
    }

    private var currentIndex: Int {
        guard let selection, let index = entries.firstIndex(where: { $0.id == selection }) else { return 0 }
        return index
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 20) {
                    ForEach(entries) { entry in
                        NavigationLink(value: CollectionRoute.detail(entry.receipt)) {
                            CollectionFeaturedCard(entry: entry)
                                .frame(width: cardWidth)
                        }
                        .buttonStyle(CollectionPressStyle())
                        .id(entry.id)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, CollectionMetrics.gutter)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $selection)
            .scrollIndicators(.hidden)

            if entries.count > 1 {
                HStack(spacing: 5) {
                    ForEach(entries.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == currentIndex ? CollectionColor.ink : CollectionColor.hairline)
                            .frame(width: index == currentIndex ? 16 : 6, height: 6)
                            .animation(.snappy(duration: 0.22), value: currentIndex)
                    }
                }
                .padding(.horizontal, CollectionMetrics.gutter)
            }
        }
        .accessibilityIdentifier("collection.featured")
    }
}

// MARK: - 心情索引

/// 吸顶的心情筛选：只有文字和数量，选中项用一小段墨线标出来。
struct CollectionMoodBar: View {
    let moods: [CollectionMoodCount]
    let total: Int
    @Binding var selection: Mood?
    @Namespace private var underline

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 22) {
                tab(title: "全部", count: total, mood: nil)

                ForEach(moods) { item in
                    tab(title: item.mood.label, count: item.count, mood: item.mood)
                }
            }
            .padding(.horizontal, CollectionMetrics.gutter)
            .padding(.top, 12)
            .padding(.bottom, 11)
        }
        .background(CollectionColor.background)
        .overlay(alignment: .bottom) { CollectionHairline() }
        .accessibilityIdentifier("collection.moodBar")
    }

    private func tab(title: String, count: Int, mood: Mood?) -> some View {
        let selected = selection == mood
        return Button {
            Haptics.selection()
            withAnimation(.snappy(duration: 0.24)) { selection = mood }
        } label: {
            VStack(spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: selected ? .semibold : .regular))
                        .foregroundStyle(selected ? CollectionColor.ink : CollectionColor.secondary)
                    Text("\(count)")
                        .font(.system(size: 11))
                        .foregroundStyle(selected ? CollectionColor.ink.opacity(0.55) : CollectionColor.tertiary)
                }

                ZStack {
                    Capsule().fill(Color.clear).frame(height: 2)
                    if selected {
                        Capsule()
                            .fill(CollectionColor.ink)
                            .frame(height: 2)
                            .matchedGeometryEffect(id: "mood.underline", in: underline)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("collection.mood.\(mood?.label ?? "全部")")
    }
}

// MARK: - 已生效的筛选

struct CollectionActiveFilters: View {
    @Binding var filter: CollectionFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let year = filter.year {
                    token("\(year) 年") { filter.year = nil }
                }
                if let type = filter.type {
                    token(type.displayName) { filter.type = nil }
                }
                if let tag = filter.tag {
                    token("#\(tag)") { filter.tag = nil }
                }

                Button {
                    Haptics.selection()
                    withAnimation(.snappy(duration: 0.22)) { filter.reset() }
                } label: {
                    Text("清除")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(CollectionColor.secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 2)
            }
            .padding(.horizontal, CollectionMetrics.gutter)
        }
        .padding(.top, 10)
    }

    private func token(_ text: String, remove: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            withAnimation(.snappy(duration: 0.22)) { remove() }
        } label: {
            HStack(spacing: 5) {
                Text(text)
                    .font(.system(size: 12, weight: .medium))
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(CollectionColor.secondary)
            }
            .foregroundStyle(CollectionColor.ink)
            .padding(.horizontal, 11)
            .frame(height: 30)
            .background(CollectionColor.fill, in: Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("移除筛选 \(text)")
    }
}

// MARK: - 年份与网格

struct CollectionYearHeader: View {
    let year: Int
    let count: Int

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(year))
                    .font(.system(size: 22, weight: .semibold))
                    .tracking(-0.3)
                    .foregroundStyle(CollectionColor.ink)
                Spacer()
                Text("\(count) 件")
                    .font(.system(size: 12))
                    .foregroundStyle(CollectionColor.secondary)
            }
            CollectionHairline()
        }
        .padding(.horizontal, CollectionMetrics.gutter)
        .accessibilityAddTraits(.isHeader)
    }
}

struct CollectionGrid: View {
    let entries: [CollectionEntry]

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 22) {
            ForEach(entries) { entry in
                CollectionCard(entry: entry)
            }
        }
        .padding(.horizontal, CollectionMetrics.gutter)
    }
}

/// 网格单件：圆角图片 + 两行说明，没有编号、没有彩色圆点。
struct CollectionCard: View {
    let entry: CollectionEntry
    @EnvironmentObject private var store: ReceiptStore

    var body: some View {
        NavigationLink(value: CollectionRoute.detail(entry.receipt)) {
            VStack(alignment: .leading, spacing: 8) {
                image
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(CollectionColor.ink)
                        .lineLimit(1)
                    Text(meta)
                        .font(.system(size: 11.5))
                        .foregroundStyle(CollectionColor.secondary)
                        .lineLimit(1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(CollectionPressStyle())
        .accessibilityIdentifier("collection.card.\(entry.id)")
    }

    private var image: some View {
        Rectangle()
            .fill(CollectionColor.fill)
            .aspectRatio(0.78, contentMode: .fit)
            .overlay {
                if let image = store.thumbnail(for: entry.receipt, page: 0) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: entry.receipt.type.symbolName)
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(CollectionColor.tertiary)
                }
            }
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: CollectionMetrics.imageRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: CollectionMetrics.imageRadius, style: .continuous)
                    .strokeBorder(CollectionColor.hairline, lineWidth: 0.6)
            }
            .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
    }

    private var meta: String {
        var parts = [CollectionDate.dotted.string(from: entry.receipt.date)]
        if let place = entry.place { parts.append(place) }
        return parts.joined(separator: " · ")
    }
}

// MARK: - 标签

struct CollectionTagRow: View {
    let tags: [CollectionTagCount]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("标签")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(CollectionColor.secondary)

            FlowLayout(spacing: 8) {
                ForEach(tags) { item in
                    NavigationLink(value: CollectionRoute.album(item.tag)) {
                        CollectionTagPill(tag: item.tag, count: item.count)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("collection.tag.\(item.tag)")
                }
            }
        }
        .padding(.horizontal, CollectionMetrics.gutter)
    }
}

// MARK: - 搜索框

struct CollectionSearchField: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(CollectionColor.secondary)

            TextField("搜索商家、地点或标签", text: $text)
                .font(.system(size: 14))
                .foregroundStyle(CollectionColor.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isFocused)
                .submitLabel(.search)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(CollectionColor.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清除搜索")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background(CollectionColor.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isFocused ? CollectionColor.ink.opacity(0.18) : .clear, lineWidth: 1)
        }
        .animation(.easeOut(duration: 0.16), value: isFocused)
        .accessibilityIdentifier("collection.searchField")
    }
}

// MARK: - 空状态

enum CollectionEmptyKind {
    case empty
    case noResults

    var title: String {
        switch self {
        case .empty: return "还没有收藏"
        case .noResults: return "没有相关藏品"
        }
    }

    var message: String {
        switch self {
        case .empty:
            return "在扫描票据时把金额留空，它就会作为纪念收藏出现在这里。"
        case .noResults:
            return "换一个年份、类型或心情试试。"
        }
    }
}

struct CollectionEmptyState: View {
    let kind: CollectionEmptyKind
    var onAdd: (() -> Void)?
    var onClear: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: kind == .empty ? "doc.text.image" : "magnifyingglass")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(CollectionColor.tertiary)
                .padding(.bottom, 2)

            Text(kind.title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(CollectionColor.ink)

            Text(kind.message)
                .font(.system(size: 13))
                .foregroundStyle(CollectionColor.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: 280)

            if let onAdd, kind == .empty {
                Button {
                    Haptics.selection()
                    onAdd()
                } label: {
                    Text("去添加一张")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CollectionColor.background)
                        .padding(.horizontal, 22)
                        .frame(height: 44)
                        .background(CollectionColor.ink, in: Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }

            if let onClear, kind == .noResults {
                Button {
                    Haptics.selection()
                    onClear()
                } label: {
                    Text("清除筛选")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(CollectionColor.secondary)
                        .underline()
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, CollectionMetrics.gutter)
        .padding(.top, 56)
        .padding(.bottom, 40)
    }
}

// MARK: - 页脚

struct CollectionFooter: View {
    let count: Int

    var body: some View {
        Text("共 \(count) 件藏品")
            .font(.system(size: 11))
            .foregroundStyle(CollectionColor.tertiary)
            .frame(maxWidth: .infinity)
            .padding(.top, 30)
            .padding(.bottom, 8)
    }
}
