// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import UIKit

/// 震动反馈封装：集中管理生成器，并在动作真正发生的那一刻触发。
/// 模拟器没有 Taptic Engine，调用会被系统静默忽略，真机才有效果。
enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let success = UINotificationFeedbackGenerator()

    /// 轻量选择反馈（筛选、切换）
    static func selection() {
        light.prepare()
        light.impactOccurred(intensity: 0.55)
    }

    /// 删除区吸附出来（滑到阈值）
    static func swipeSnap() {
        light.prepare()
        light.impactOccurred(intensity: 0.7)
    }

    /// 触发删除，卡片开始碎化
    static func delete() {
        medium.prepare()
        medium.impactOccurred(intensity: 1.0)
    }

    /// 撤销删除成功
    static func undo() {
        success.prepare()
        success.notificationOccurred(.success)
    }
}
