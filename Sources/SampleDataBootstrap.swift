// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import Foundation

/// 首次启动时往空库里灌一份示例数据，装到真机上就能直接看到完整效果。
///
/// 用 UserDefaults 记一个标记：只在**第一次**启动灌一次，
/// 之后用户把票据删光也不会再自动补数据（否则删除会「删不干净」）。
enum SampleDataBootstrap {
    private static let flagKey = "didSeedSampleData"

    static func prepare() {
        let defaults = UserDefaults.standard
        let store = ReceiptStore.shared

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-seedLargeData") {
            MockData.seedLarge(into: store, count: 2000)
            return
        }
        // 显式要求重置（make seed / make reset-data / UI 测试）
        if ProcessInfo.processInfo.arguments.contains("-seedSampleData") {
            defaults.removeObject(forKey: flagKey)
        }
        #endif

        guard !defaults.bool(forKey: flagKey), store.receipts.isEmpty else { return }
        MockData.seed(into: store)
        defaults.set(true, forKey: flagKey)
    }

    /// 「我的」页里手动恢复默认数据：清空现有票据后重新写入示例。
    static func restoreDefaults() {
        let store = ReceiptStore.shared
        if !store.receipts.isEmpty {
            store.delete(store.receipts)
        }
        MockData.seed(into: store)
        UserDefaults.standard.set(true, forKey: flagKey)
    }
}
