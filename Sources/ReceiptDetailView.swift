// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI
import UIKit

struct ReceiptDetailView: View {
    let receipt: Receipt
    @EnvironmentObject private var store: ReceiptStore
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    @State private var viewerImage: UIImage?
    @State private var showViewer = false

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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                let images = store.images(for: live)
                if images.isEmpty {
                    Image(systemName: "doc.text.image")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    ForEach(images.indices, id: \.self) { index in
                        Image(uiImage: images[index])
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewerImage = images[index]
                                showViewer = true
                            }
                    }
                }

                infoRow(title: "类型", value: live.type.displayName)
                infoRow(title: "日期", value: Self.formatter.string(from: live.date))
                infoRow(title: "金额", value: live.amount.map { String(format: "¥%.2f", $0) } ?? "无金额（纪念收藏）")
                infoRow(title: "商家 / 抬头", value: live.merchant.isEmpty ? "—" : live.merchant)
                if !live.note.isEmpty {
                    infoRow(title: "备注", value: live.note)
                }
                if let location = live.location, !location.isEmpty {
                    infoRow(title: "地点", value: location)
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
        .fullScreenCover(isPresented: $showViewer) {
            if let viewerImage {
                FullScreenImageView(image: viewerImage)
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
