// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI
import UIKit

/// 支持双指缩放 + 拖动的图片查看器（UIScrollView 桥接）。
struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage

    func makeCoordinator() -> Coordinator {
        Coordinator(image: image)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor = .black
        scrollView.contentInsetAdjustmentBehavior = .never

        let imageView = context.coordinator.imageView
        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: scrollView.contentLayoutGuide.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: scrollView.contentLayoutGuide.centerYAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
        ])
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.imageView.image = image
        scrollView.zoomScale = 1
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        let imageView = UIImageView()

        init(image: UIImage) {
            imageView.image = image
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }
    }
}

/// 全屏图片查看器。
struct FullScreenImageView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZoomableImageView(image: image)
                .ignoresSafeArea()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
                    .padding()
            }
        }
        .background(Color.black.ignoresSafeArea())
    }
}
