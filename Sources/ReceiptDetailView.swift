// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI
import UIKit

struct ReceiptDetailView: View {
    let receipt: Receipt
    @EnvironmentObject private var store: ReceiptStore
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    @State private var viewerItem: ImageViewerItem?
    @State private var pageIndex: Int?
    @State private var images: [UIImage] = []
    @State private var didLoadImages = false

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    /// 编辑后从 store 里取最新数据，避免显示旧值。
    private var live: Receipt {
        store.receipts.first { $0.id == receipt.id } ?? receipt
    }

    var body: some View {
        content
            .hidesFloatingTabBar()
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if images.isEmpty {
                    if didLoadImages {
                        Image(systemName: "doc.text.image")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)
                    }
                } else {
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: 0) {
                            ForEach(images.indices, id: \.self) { index in
                                Image(uiImage: images[index])
                                    .resizable()
                                    .scaledToFit()
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
                    .frame(height: 320)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(alignment: .bottom) {
                        if images.count > 1 {
                            pageIndicator
                        }
                    }
                }

                infoRow(title: "类型", value: live.type.displayName)
                infoRow(title: "日期", value: Self.formatter.string(from: live.date))
                infoRow(title: "金额", value: live.amount.map { $0.yuan } ?? "无金额（纪念收藏）")
                infoRow(title: "商家 / 抬头", value: live.merchant.isEmpty ? "—" : live.merchant)
                if !live.note.isEmpty {
                    infoRow(title: "备注", value: live.note)
                }
                if let location = live.location, !location.isEmpty {
                    infoRow(title: "地点", value: location)
                }
                if let address = live.address, !address.isEmpty {
                    infoRow(title: "详细地址", value: address)
                }
                if let mood = live.mood {
                    infoRow(title: "心情", value: mood.rawValue)
                }
                if !live.tags.isEmpty {
                    infoRow(title: "标签", value: live.tags.joined(separator: " · "))
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // 详情页是压在 Tab 里的子页面，悬浮 Tab 同样会盖住内容，这里留出高度
            Color.clear.frame(height: FloatingTabMetrics.reservedHeight)
        }
        .navigationTitle("票据详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                NavigationLink {
                    AddReceiptView(receipt: live)
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .confirmationDialog("删除票据", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                store.delete(live)
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后无法恢复。")
        }
        .fullScreenCover(item: $viewerItem) { item in
            FullScreenImageView(images: item.images, startIndex: item.startIndex)
        }
        .onAppear {
            loadImages()
        }
    }

    /// 多页时只在底部显示一排圆点：数量即图片张数，当前页高亮。
    private var pageIndicator: some View {
        let page = min(pageIndex ?? 0, images.count - 1)
        return HStack(spacing: 6) {
            ForEach(images.indices, id: \.self) { index in
                Circle()
                    .fill(index == page ? Color.white : Color.white.opacity(0.4))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.black.opacity(0.38), in: Capsule())
        .padding(.bottom, 10)
        .allowsHitTesting(false)
    }

    private func loadImages() {
        didLoadImages = false
        let target = live
        DispatchQueue.global(qos: .userInitiated).async {
            let imgs = ReceiptStore.shared.previewImages(for: target)
            DispatchQueue.main.async {
                self.images = imgs
                self.didLoadImages = true
            }
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
