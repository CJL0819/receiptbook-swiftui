// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI

/// 筛选：一张干净的纸页，改动先落在草稿上，「查看 N 件藏品」才生效。
struct CollectionFilterSheet: View {
    @Binding var filter: CollectionFilter
    let catalog: CollectionCatalog
    var onApply: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: CollectionFilter

    init(filter: Binding<CollectionFilter>,
         catalog: CollectionCatalog,
         onApply: @escaping () -> Void) {
        _filter = filter
        self.catalog = catalog
        self.onApply = onApply
        _draft = State(initialValue: filter.wrappedValue)
    }

    private var resultCount: Int {
        catalog.filtered(by: draft).count
    }

    private var hasChanges: Bool {
        draft.isActive || draft.sort != .newest
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    section("排序") {
                        FlowLayout(spacing: 8) {
                            ForEach(CollectionSortOrder.allCases) { order in
                                CollectionPill(title: order.title,
                                               selected: draft.sort == order) {
                                    draft.sort = order
                                }
                                .accessibilityIdentifier("collection.filter.sort.\(order.rawValue)")
                            }
                        }
                    }

                    if !catalog.years.isEmpty {
                        section("年份") {
                            FlowLayout(spacing: 8) {
                                CollectionPill(title: "全部",
                                               count: catalog.count,
                                               selected: draft.year == nil) {
                                    draft.year = nil
                                }
                                ForEach(catalog.years, id: \.self) { year in
                                    let count = catalog.entries.filter {
                                        Calendar.current.component(.year, from: $0.receipt.date) == year
                                    }.count
                                    CollectionPill(title: "\(year)",
                                                   count: count,
                                                   selected: draft.year == year) {
                                        draft.year = draft.year == year ? nil : year
                                    }
                                    .accessibilityIdentifier("collection.filter.year.\(year)")
                                }
                            }
                        }
                    }

                    if catalog.types.count > 1 {
                        section("类型") {
                            FlowLayout(spacing: 8) {
                                ForEach(catalog.types) { item in
                                    CollectionPill(title: item.type.displayName,
                                                   count: item.count,
                                                   selected: draft.type == item.type) {
                                        draft.type = draft.type == item.type ? nil : item.type
                                    }
                                    .accessibilityIdentifier("collection.filter.type.\(item.type.displayName)")
                                }
                            }
                        }
                    }

                    if !catalog.moods.isEmpty {
                        section("心情") {
                            FlowLayout(spacing: 8) {
                                ForEach(catalog.moods) { item in
                                    CollectionPill(title: item.mood.label,
                                                   count: item.count,
                                                   selected: draft.mood == item.mood) {
                                        draft.mood = draft.mood == item.mood ? nil : item.mood
                                    }
                                    .accessibilityIdentifier("collection.filter.mood.\(item.mood.label)")
                                }
                            }
                        }
                    }

                    if !catalog.tags.isEmpty {
                        section("标签") {
                            FlowLayout(spacing: 8) {
                                ForEach(catalog.tags) { item in
                                    CollectionPill(title: item.tag,
                                                   count: item.count,
                                                   selected: draft.tag == item.tag) {
                                        draft.tag = draft.tag == item.tag ? nil : item.tag
                                    }
                                    .accessibilityIdentifier("collection.filter.tag.\(item.tag)")
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, CollectionMetrics.gutter)
                .padding(.top, 20)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            footer
        }
        .background(CollectionColor.surface)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(CollectionColor.surface)
        .presentationCornerRadius(24)
    }

    // MARK: - 顶栏

    private var header: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Text("筛选")
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-0.5)
                    .foregroundStyle(CollectionColor.ink)

                Spacer()

                if hasChanges {
                    Button {
                        Haptics.selection()
                        withAnimation(.snappy(duration: 0.2)) { draft.reset() }
                    } label: {
                        Text("重置")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(CollectionColor.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("collection.filter.reset")
                }

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CollectionColor.ink)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭筛选")
            }
            .padding(.leading, CollectionMetrics.gutter)
            .padding(.trailing, 10)
            .padding(.top, 18)
            .padding(.bottom, 12)

            CollectionHairline()
        }
    }

    private func section<Content: View>(_ title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(CollectionColor.secondary)
            content()
        }
    }

    // MARK: - 底栏

    private var footer: some View {
        VStack(spacing: 0) {
            CollectionHairline()
            Button {
                Haptics.done()
                filter = draft
                onApply()
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Text("查看")
                        .font(.system(size: 14, weight: .medium))
                    Text("\(resultCount)")
                        .font(.system(size: 14, weight: .semibold))
                    Text("件藏品")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(CollectionColor.background)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(CollectionColor.ink,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .opacity(resultCount == 0 ? 0.35 : 1)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(resultCount == 0)
            .padding(.horizontal, CollectionMetrics.gutter)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .accessibilityIdentifier("collection.filter.apply")
        }
    }
}
