// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI
import SpriteKit

/// 整行卡片「化成细色彩粒、向上飘散」的过渡。
///
/// - 画布 = 列表可视区域（不是卡片）：粒子可以飘出卡片、飘到别的行甚至屏幕外；
/// - 每个圆点取该位置像素的颜色，几千个点共用一张圆形纹理，由 SpriteKit 在 GPU 批量绘制；
/// - 寿命较长（约 1.4–2.0s），前段实心、后段渐隐。
struct ParticleDissolve: View {
    let image: UIImage
    /// 卡片在画布中的位置
    let cardRect: CGRect
    /// 画布尺寸（= 列表可视区域）
    let canvas: CGSize
    var onFinished: () -> Void

    @State private var scene: DissolveScene?

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let scene {
                SpriteKitHost(scene: scene)
                    .frame(width: canvas.width, height: canvas.height)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
        .onAppear {
            guard scene == nil else { return }
            let scene = DissolveScene(canvas: canvas, cardRect: cardRect, image: image)
            scene.onFinished = onFinished
            self.scene = scene
        }
    }
}

/// 自建 SKView 包装：`SpriteView` 首次出现时有一帧不透明黑底，这里从创建起就设成透明。
private struct SpriteKitHost: UIViewRepresentable {
    let scene: SKScene

    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.allowsTransparency = true
        view.isOpaque = false
        view.backgroundColor = .clear
        view.ignoresSiblingOrder = true
        view.presentScene(scene)
        return view
    }

    func updateUIView(_ view: SKView, context: Context) {
        if view.scene !== scene { view.presentScene(scene) }
    }
}

/// 只负责「铺彩色圆点 + 跑动作」的场景。
final class DissolveScene: SKScene {
    var onFinished: (() -> Void)?

    private let snapshot: UIImage
    private let cardRect: CGRect
    /// 画布高度：用它把卡片坐标翻成 SpriteKit 的左下原点坐标系，
    /// 不依赖 `size`（场景首次布局时可能还是 0）
    private let canvasHeight: CGFloat
    private var didBuild = false

    init(canvas: CGSize, cardRect: CGRect, image: UIImage) {
        self.snapshot = image
        self.cardRect = cardRect
        self.canvasHeight = canvas.height
        super.init(size: canvas)
        backgroundColor = .clear
        scaleMode = .resizeFill
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        guard !didBuild else { return }
        didBuild = true
        buildDots()
    }

    // MARK: - 圆点

    private static let dotTexture: SKTexture = {
        let side: CGFloat = 16
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: side, height: side))
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }()

    private func buildDots() {
        guard cardRect.width > 1, cardRect.height > 1,
              let cgImage = snapshot.cgImage,
              let bitmap = CGContext(data: nil,
                                     width: cgImage.width,
                                     height: cgImage.height,
                                     bitsPerComponent: 8,
                                     bytesPerRow: cgImage.width * 4,
                                     space: CGColorSpaceCreateDeviceRGB(),
                                     bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else {
            onFinished?()
            return
        }
        bitmap.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        guard let pixels = bitmap.data?.bindMemory(to: UInt8.self,
                                                   capacity: cgImage.width * cgImage.height * 4) else {
            onFinished?()
            return
        }

        let pixelScale = CGFloat(cgImage.width) / cardRect.width
        let grid: CGFloat = 5
        let dotSide: CGFloat = 3.2
        let columns = max(1, Int((cardRect.width / grid).rounded(.up)))
        let rows = max(1, Int((cardRect.height / grid).rounded(.up)))

        var maxDuration: TimeInterval = 0
        var index = 0

        for row in 0..<rows {
            for column in 0..<columns {
                defer { index += 1 }

                let x = CGFloat(column) * grid
                let y = CGFloat(row) * grid
                guard x + grid <= cardRect.width + 0.01, y + grid <= cardRect.height + 0.01 else { continue }

                let centerX = x + grid / 2
                let centerY = y + grid / 2
                let px = min(cgImage.width - 1, max(0, Int(centerX * pixelScale)))
                let py = min(cgImage.height - 1, max(0, Int(centerY * pixelScale)))
                let offset = (py * cgImage.width + px) * 4
                let alpha = CGFloat(pixels[offset + 3]) / 255
                guard alpha > 0.3 else { continue }

                // 卡片主体是白色，直接画在浅色背景上几乎不可见；
                // 统一压暗到 86%，让它读起来像「灰尘」，文字/配色仍保留色相
                let tone: CGFloat = 0.86
                let color = UIColor(red: CGFloat(pixels[offset]) / 255 * tone,
                                    green: CGFloat(pixels[offset + 1]) / 255 * tone,
                                    blue: CGFloat(pixels[offset + 2]) / 255 * tone,
                                    alpha: 1)

                let random = { (salt: Int) in Self.random(index, salt) }
                // 起步即动：只保留极短的错峰，避免整片同时起跳显得生硬
                let delay = random(1) * 0.06
                let life = 1.4 + random(2) * 0.6
                maxDuration = max(maxDuration, delay + life)

                let node = SKSpriteNode(texture: Self.dotTexture,
                                        size: CGSize(width: dotSide, height: dotSide))
                node.color = color
                node.colorBlendFactor = 1
                // 画布坐标：卡片矩形 + 卡片内坐标；SpriteKit 原点在左下，需要翻转 y
                // 初始就带一点随机位移和抬升，第一帧看过去已经是「散开的尘埃」，
                // 而不是一张静止的网格图
                let jitterX = (random(6) - 0.5) * 6
                let jitterY = 1 + random(7) * 7
                node.position = CGPoint(x: cardRect.minX + centerX + jitterX,
                                        y: canvasHeight - (cardRect.minY + centerY) + jitterY)
                node.alpha = 1 - random(3) * 0.2
                addChild(node)

                let driftX = (random(4) - 0.5) * 220
                let rise = 80 + random(5) * 160
                let move = SKAction.moveBy(x: driftX, y: rise, duration: life)
                move.timingMode = .easeOut
                let fade = SKAction.sequence([
                    .wait(forDuration: life * 0.35),
                    .fadeOut(withDuration: life * 0.65),
                ])
                let shrink = SKAction.scale(to: 0.45, duration: life)

                node.run(.sequence([
                    .wait(forDuration: delay),
                    .group([move, fade, shrink]),
                    .removeFromParent(),
                ]))
            }
        }
        run(.sequence([
            .wait(forDuration: maxDuration + 0.12),
            .run { [weak self] in self?.onFinished?() },
        ]))
    }

    private static func random(_ index: Int, _ salt: Int) -> Double {
        var x = UInt64(bitPattern: Int64(index &* 2_654_435_761 &+ salt &* 40_503))
        x ^= x >> 33
        x = x &* 0xff51_afd7_ed55_8ccd
        x ^= x >> 33
        return Double(x % 1000) / 1000
    }
}
