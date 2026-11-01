// SPDX-License-Identifier: MIT
// Copyright (c) 2026
//
// 仅 Debug：用启动参数往空库里灌示例数据，方便零输入验证
// 列表 / 统计 / 收藏 / 小组件数据链路。
//
//   make seed                       # 复用 Makefile 里的模拟器
//   xcrun simctl launch booted com.receiptbook -seedSampleData
//
// 只在库为空时写入，重复启动不会叠加。Release 编译时整个文件不参与构建。

#if DEBUG
import Foundation

enum DebugSeed {
    static func applyIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-seedSampleData") else { return }
        let store = ReceiptStore.shared
        guard store.receipts.isEmpty else {
            print("[DebugSeed] 库里已有 \(store.receipts.count) 条数据，跳过")
            return
        }
        MockData.seed(into: store)
        print("[DebugSeed] 已写入 \(store.receipts.count) 条示例票据")
    }
}
#endif
