// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI
import UIKit

/// 全屏图片查看器要展示的内容。
/// 用 `.fullScreenCover(item:)` 展示，避免「先置 true 再赋值」导致内容为空的白屏。
struct ImageViewerItem: Identifiable {
    let id = UUID()
    let images: [UIImage]
    let startIndex: Int
}

/// 全屏图片查看器：左右翻页 + 双指缩放 + 放大后拖动 + 双击放大/还原。
/// 纯 SwiftUI 实现，避免 UIScrollView + AutoLayout 在 fullScreenCover 里尺寸为 0 造成的白屏。
struct FullScreenImageView: View {
    let images: [UIImage]
    var startIndex: Int = 0

    @Environment(\.dismiss) private var dismiss

    @State private var currentIndex: Int?
    @State private var isZoomed = false

    private var resolvedIndex: Int {
        guard !images.isEmpty else { return 0 }
        return min(max(currentIndex ?? startIndex, 0), images.count - 1)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                        ZoomablePage(image: image,
                                     isActive: resolvedIndex == index,
                                     isZoomed: $isZoomed)
                            .containerRelativeFrame(.horizontal)
                            .id(index)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $currentIndex)
            .scrollIndicators(.hidden)
            // 放大时禁掉翻页，让拖动手势用于平移图片
            .scrollDisabled(isZoomed)
            .ignoresSafeArea()

            if images.count > 1 {
                pageBadge
            }

            closeButton
        }
        .background(Color.black)
        .onAppear {
            currentIndex = min(max(startIndex, 0), max(images.count - 1, 0))
        }
        .onChange(of: currentIndex) { _, _ in
            // 翻页后新页面默认是原始比例
            isZoomed = false
        }
    }

    // MARK: - 子视图

    private var pageBadge: some View {
        Text("\(resolvedIndex + 1) / \(images.count)")
            .font(.system(size: 12, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.black.opacity(0.55), in: Capsule())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 26)
            .allowsHitTesting(false)
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.black.opacity(0.45), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
        }
        .accessibilityLabel("关闭")
        .padding(.trailing, 16)
        .padding(.top, 12)
    }
}

// MARK: - 单张可缩放图片

private struct ZoomablePage: View {
    let image: UIImage
    let isActive: Bool
    @Binding var isZoomed: Bool

    @State private var scale: CGFloat = 1
    @State private var baseScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero

    private let maxScale: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .scaleEffect(scale)
                .offset(offset)
                .contentShape(Rectangle())
                .gesture(magnification)
                .simultaneousGesture(drag(in: proxy.size))
                .onTapGesture(count: 2) { toggleZoom() }
        }
        .onChange(of: scale) { _, newValue in
            if isActive { isZoomed = newValue > 1.01 }
        }
        .onChange(of: isActive) { _, active in
            guard !active else { return }
            reset()
            isZoomed = false
        }
    }

    private var magnification: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = min(max(baseScale * value.magnification, 1), maxScale)
            }
            .onEnded { _ in
                baseScale = scale
                if scale <= 1.01 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        reset()
                    }
                }
            }
    }

    private func drag(in size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1 else { return }
                offset = clamped(CGSize(width: baseOffset.width + value.translation.width,
                                        height: baseOffset.height + value.translation.height),
                                 in: size)
            }
            .onEnded { _ in baseOffset = offset }
    }

    private func toggleZoom() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            if scale > 1 {
                reset()
            } else {
                scale = 2.5
                baseScale = 2.5
            }
        }
    }

    private func reset() {
        scale = 1
        baseScale = 1
        offset = .zero
        baseOffset = .zero
    }

    private func clamped(_ offset: CGSize, in size: CGSize) -> CGSize {
        let maxX = max(0, size.width * (scale - 1) / 2)
        let maxY = max(0, size.height * (scale - 1) / 2)
        return CGSize(width: min(max(offset.width, -maxX), maxX),
                      height: min(max(offset.height, -maxY), maxY))
    }
}
