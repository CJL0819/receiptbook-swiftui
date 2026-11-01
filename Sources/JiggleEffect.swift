// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI

/// 编辑态卡片的轻微摇摆（类似 iOS 主屏图标进入编辑时那种晃动）。
/// 幅度很小（±0.55°），只用于提示「当前处于编辑态」，不影响阅读。
struct JiggleEffect: ViewModifier {
    let active: Bool
    let seed: Int

    @State private var angle: Double = 0

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(angle))
            .onAppear { if active { start() } }
            .onChange(of: active) { _, isActive in
                if isActive { start() } else { stop() }
            }
    }

    private func start() {
        // 用 seed 决定初始方向，避免整列同相位摆动
        let base = seed % 2 == 0 ? 0.55 : -0.55
        angle = base
        withAnimation(.easeInOut(duration: 0.13).repeatForever(autoreverses: true)) {
            angle = -base
        }
    }

    private func stop() {
        withAnimation(.easeOut(duration: 0.18)) { angle = 0 }
    }
}

extension View {
    /// - Parameters:
    ///   - active: 是否处于编辑态
    ///   - seed: 用于打散摆动相位
    func jiggle(_ active: Bool, seed: Int) -> some View {
        modifier(JiggleEffect(active: active, seed: seed))
    }
}
