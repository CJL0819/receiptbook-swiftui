// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI
import UIKit

/// 藏品详情：白色画页、圆角图片、克制的信息。
struct CollectionDetailView: View {
    let receipt: Receipt

    @EnvironmentObject private var store: ReceiptStore
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var images: [UIImage] = []
    @State private var didLoadImages = false
    @State private var pageIndex: Int?
    @State private var viewerItem: ImageViewerItem?
    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var showShare = false
    @State private var shareItems: [Any] = []

    private var live: Receipt {
        store.receipts.first { $0.id == receipt.id } ?? receipt
    }

    private var catalog: CollectionCatalog {
        CollectionCatalog(receipts: store.receipts)
    }

    private var related: [CollectionEntry] {
        catalog.related(to: live, limit: 6)
    }

    private var title: String {
        live.merchant.isEmpty ? live.type.displayName : live.merchant
    }

    private var meta: String {
        var parts = [live.type.displayName, CollectionDate.full.string(from: live.date)]
        if let place = live.location, !place.isEmpty { parts.append(place) }
        if let mood = live.mood { parts.append(mood.label) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                imageSection

                VStack(alignment: .leading, spacing: 20) {
                    titleBlock

                    if !live.note.isEmpty {
                        Text(live.note)
                            .font(.system(size: 15))
                            .lineSpacing(6)
                            .foregroundStyle(CollectionColor.ink.opacity(0.85))
                    }

                    if !live.tags.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(live.tags, id: \.self) { tag in
                                NavigationLink(value: CollectionRoute.album(tag)) {
                                    CollectionTagPill(tag: tag)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !related.isEmpty {
                        relatedSection
                    }
                }
                .padding(.horizontal, CollectionMetrics.gutter)
                .padding(.top, 24)
                .padding(.bottom, 28)
            }
        }
        .background(CollectionColor.background)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            topBar
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: 24)
        }
        .navigationDestination(isPresented: $showEdit) {
            AddReceiptView(receipt: live)
        }
        .confirmationDialog("删除这件藏品？",
                            isPresented: $showDeleteConfirm,
                            titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                Haptics.delete()
                store.delete(live)
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("图片和记录会一起删除，无法恢复。")
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(items: shareItems)
        }
        .fullScreenCover(item: $viewerItem) { item in
            FullScreenImageView(images: item.images, startIndex: item.startIndex)
        }
        .onAppear {
            appState.hidesTabBar = true
            if !didLoadImages { loadImages() }
        }
        .onDisappear {
            appState.hidesTabBar = false
        }
        .onChange(of: live) { _, _ in
            loadImages()
        }
    }

    // MARK: - 顶栏

    private var topBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
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
                .accessibilityLabel("返回")

                Spacer()

                Button {
                    share()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(CollectionColor.ink)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("分享")

                Menu {
                    Button {
                        showEdit = true
                    } label: {
                        Label("编辑", systemImage: "square.and.pencil")
                    }
                    Button {
                        share()
                    } label: {
                        Label("分享", systemImage: "square.and.arrow.up")
                    }
                    Divider()
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(CollectionColor.ink)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("更多操作")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 2)
            .background(CollectionColor.background)

            CollectionHairline()
        }
    }

    // MARK: - 图片

    private var imageSection: some View {
        VStack(spacing: 10) {
            ZStack {
                CollectionColor.fill

                if images.isEmpty {
                    if didLoadImages {
                        Image(systemName: live.type.symbolName)
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(CollectionColor.tertiary)
                    } else {
                        ProgressView()
                            .tint(CollectionColor.secondary)
                    }
                } else {
                    imagePager
                }
            }
            .aspectRatio(0.8, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: CollectionMetrics.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: CollectionMetrics.cardRadius, style: .continuous)
                    .strokeBorder(CollectionColor.hairline, lineWidth: 0.6)
            }
            .padding(.horizontal, CollectionMetrics.gutter)

            if images.count > 1 {
                HStack(spacing: 5) {
                    ForEach(images.indices, id: \.self) { index in
                        Circle()
                            .fill(index == (pageIndex ?? 0) ? CollectionColor.ink : CollectionColor.hairline)
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.top, 14)
    }

    private var imagePager: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(images.indices, id: \.self) { index in
                    Image(uiImage: images[index])
                        .resizable()
                        .scaledToFit()
                        .shadow(color: Color.black.opacity(0.12), radius: 14, y: 6)
                        .padding(12)
                        .containerRelativeFrame(.horizontal)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewerItem = ImageViewerItem(images: images, startIndex: index)
                        }
                        .id(index)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $pageIndex)
        .scrollIndicators(.hidden)
    }

    // MARK: - 文字

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 26, weight: .bold))
                .tracking(-0.5)
                .lineSpacing(3)
                .foregroundStyle(CollectionColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(meta)
                .font(.system(size: 13))
                .foregroundStyle(CollectionColor.secondary)

            if let address = live.address, !address.isEmpty, address != live.location {
                Text(address)
                    .font(.system(size: 12.5))
                    .foregroundStyle(CollectionColor.tertiary)
            }
        }
    }

    private var relatedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("同系列")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CollectionColor.ink)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(related) { entry in
                        NavigationLink(value: CollectionRoute.detail(entry.receipt)) {
                            VStack(alignment: .leading, spacing: 6) {
                                Rectangle()
                                    .fill(CollectionColor.fill)
                                    .frame(width: 104, height: 132)
                                    .overlay {
                                        if let image = store.thumbnail(for: entry.receipt, page: 0) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFill()
                                        } else {
                                            Image(systemName: entry.receipt.type.symbolName)
                                                .font(.system(size: 20, weight: .light))
                                                .foregroundStyle(CollectionColor.tertiary)
                                        }
                                    }
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(CollectionColor.hairline, lineWidth: 0.6)
                                    }

                                Text(entry.title)
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundStyle(CollectionColor.ink)
                                    .lineLimit(1)
                                    .frame(width: 104, alignment: .leading)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(CollectionPressStyle())
                    }
                }
            }
        }
    }

    // MARK: - 数据

    private func loadImages() {
        didLoadImages = false
        let target = live
        DispatchQueue.global(qos: .userInitiated).async {
            let loaded = ReceiptStore.shared.previewImages(for: target)
            DispatchQueue.main.async {
                self.images = loaded
                self.didLoadImages = true
                if self.pageIndex == nil || (self.pageIndex ?? 0) >= loaded.count {
                    self.pageIndex = loaded.isEmpty ? nil : 0
                }
            }
        }
    }

    private func share() {
        var items: [Any] = images
        var lines = [title, meta]
        if !live.tags.isEmpty { lines.append(live.tags.map { "#\($0)" }.joined(separator: " ")) }
        if !live.note.isEmpty { lines.append(live.note) }
        items.append(lines.joined(separator: "\n"))
        shareItems = items
        showShare = true
    }
}
