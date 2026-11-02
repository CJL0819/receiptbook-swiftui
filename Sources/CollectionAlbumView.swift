// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI

/// 专题：从一个标签进去，看同一主题下的全部藏品。
struct CollectionAlbumView: View {
    let tag: String

    @EnvironmentObject private var store: ReceiptStore
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    private var catalog: CollectionCatalog {
        CollectionCatalog(receipts: store.receipts)
    }

    private var entries: [CollectionEntry] {
        catalog.entries.filter { $0.receipt.tags.contains(tag) }
    }

    private var groups: [CollectionYearGroup] {
        catalog.groupedByYear(entries)
    }

    private var summary: String {
        guard !entries.isEmpty else { return "这个专题还没有藏品。" }
        let places = Set(entries.compactMap(\.place)).count
        var parts = ["\(entries.count) 件藏品"]
        if places > 0 { parts.append("来自 \(places) 个地方") }
        return parts.joined(separator: "，") + "。"
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                topBar
                header

                if entries.isEmpty {
                    CollectionEmptyState(kind: .noResults)
                } else {
                    ForEach(groups) { group in
                        VStack(spacing: 14) {
                            CollectionYearHeader(year: group.year, count: group.items.count)
                            CollectionGrid(entries: group.items)
                        }
                        .padding(.top, 30)
                    }

                    CollectionFooter(count: entries.count)
                }
            }
        }
        .background(CollectionColor.background)
        .overlay(alignment: .top) {
            CollectionStatusBarScrim()
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: 24)
        }
        .onAppear {
            appState.hidesTabBar = true
        }
        .onDisappear {
            appState.hidesTabBar = false
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(CollectionColor.ink)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("返回收藏")

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.top, 2)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(tag)
                .font(.system(size: 32, weight: .bold))
                .tracking(-0.6)
                .foregroundStyle(CollectionColor.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            Text(summary)
                .font(.system(size: 13))
                .foregroundStyle(CollectionColor.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, CollectionMetrics.gutter)
        .padding(.top, 10)
    }
}
