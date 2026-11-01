// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI

/// 一次删除时的粒子爆发：快照 + 尺寸 + 在屏幕上的位置。
struct DissolveBurst: Identifiable {
    let id = UUID()
    let image: UIImage
    let size: CGSize
    /// 屏幕坐标
    let frame: CGRect
}

/// 全局的爆发队列：行删除时投递，由 `RootView` 的全屏图层播放。
/// 放在根视图是因为列表里的 overlay 可能被量成 0 尺寸，SpriteKit 就什么都不画。
final class BurstCenter: ObservableObject {
    static let shared = BurstCenter()

    @Published private(set) var bursts: [DissolveBurst] = []

    private init() {}

    func add(_ burst: DissolveBurst) {
        bursts.append(burst)
    }

    func remove(_ id: UUID) {
        bursts.removeAll { $0.id == id }
    }
}
