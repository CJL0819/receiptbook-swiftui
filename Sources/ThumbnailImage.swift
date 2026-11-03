// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI
import UIKit

/// 列表 / 网格里的缩略图。
///
/// 关键点：**body 里绝不读盘解码**。缓存命中就同步显示，
/// 未命中则先占位、后台用 ImageIO 降采样，避免滚动时主线程被解码卡住。
struct ThumbnailImage: View {
    let receipt: Receipt
    var page: Int = 0
    var maxPixel: CGFloat = 512

    @EnvironmentObject private var store: ReceiptStore
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(.tertiarySystemFill)
                Image(systemName: "doc.text.image")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: receipt.id) {
            if let cached = store.cachedThumbnail(for: receipt, page: page) {
                image = cached
                return
            }
            let loaded = await store.loadThumbnail(for: receipt, page: page, maxPixel: maxPixel)
            guard !Task.isCancelled else { return }
            image = loaded
        }
    }
}
