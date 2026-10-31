// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI
import UIKit

/// 收藏夹：展示所有「纪念收藏」票据（无金额），网格卡片布局，支持标签筛选。
struct CollectionView: View {
    @EnvironmentObject private var store: ReceiptStore
    @EnvironmentObject private var appState: AppState
    @State private var searchText = ""
    @State private var selectedTag: String?

    private var memorabilia: [Receipt] {
        store.receipts.filter { $0.amount == nil }
    }

    private var allTags: [String] {
        var seen = Set<String>()
        for receipt in memorabilia {
            for tag in receipt.tags where !tag.isEmpty {
                seen.insert(tag)
            }
        }
        return seen.sorted()
    }

    private var visible: [Receipt] {
        var list = memorabilia
        if let tag = selectedTag {
            list = list.filter { $0.tags.contains(tag) }
        }
        guard !searchText.isEmpty else { return list }
        return list.filter {
            $0.merchant.localizedCaseInsensitiveContains(searchText)
                || $0.note.localizedCaseInsensitiveContains(searchText)
                || ($0.location?.localizedCaseInsensitiveContains(searchText) ?? false)
                || $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if !allTags.isEmpty {
                        tagFilter
                    }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                        ForEach(visible) { receipt in
                            NavigationLink {
                                ReceiptDetailView(receipt: receipt)
                            } label: {
                                CollectionCard(receipt: receipt)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("收藏")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, isPresented: $appState.isSearching, prompt: "搜索收藏")
            .overlay {
                if visible.isEmpty {
                    emptyState
                }
            }
        }
    }

    private var tagFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                tagChip("全部", selected: selectedTag == nil) { selectedTag = nil }
                ForEach(allTags, id: \.self) { tag in
                    tagChip(tag, selected: selectedTag == tag) { selectedTag = tag }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
    }

    private func tagChip(_ text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(selected ? Color.accentColor : Color(.secondarySystemGroupedBackground))
                .foregroundStyle(selected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bookmark")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text(searchText.isEmpty && selectedTag == nil
                 ? "还没有收藏\n在「扫描」页添加票据时，金额留空即进入收藏"
                 : "没有匹配的收藏")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - 收藏卡片

struct CollectionCard: View {
    let receipt: Receipt
    @EnvironmentObject private var store: ReceiptStore

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            thumbnail
            VStack(alignment: .leading, spacing: 3) {
                Text(receipt.merchant.isEmpty ? receipt.type.displayName : receipt.merchant)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(Self.dateFormatter.string(from: receipt.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    if let mood = receipt.mood {
                        Text(mood.rawValue)
                            .font(.caption)
                    }
                    if let location = receipt.location {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(location)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(10)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var thumbnail: some View {
        Group {
            if let image = store.thumbnail(for: receipt, page: 0) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color(.tertiarySystemFill)
                    Image(systemName: receipt.type.symbolName)
                        .font(.title)
                        .foregroundStyle(receipt.type.tintColor)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .clipped()
    }
}
