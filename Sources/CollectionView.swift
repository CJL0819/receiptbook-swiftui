// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI
import UIKit

/// 收藏夹：展示所有「纪念收藏」票据（无金额），网格卡片布局。
struct CollectionView: View {
    @EnvironmentObject private var store: ReceiptStore
    @State private var searchText = ""

    private var memorabilia: [Receipt] {
        store.receipts.filter { $0.amount == nil }
    }

    private var visible: [Receipt] {
        guard !searchText.isEmpty else { return memorabilia }
        return memorabilia.filter {
            $0.merchant.localizedCaseInsensitiveContains(searchText)
                || $0.note.localizedCaseInsensitiveContains(searchText)
                || ($0.location?.localizedCaseInsensitiveContains(searchText) ?? false)
                || $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
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
            .background(Color(.systemGroupedBackground))
            .navigationTitle("收藏")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "搜索收藏")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        AddReceiptView()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .overlay {
                if visible.isEmpty {
                    emptyState
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bookmark")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text(searchText.isEmpty
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
            if let image = store.image(for: receipt, page: 0) {
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
