// SPDX-License-Identifier: MIT
// Copyright (c) 2026
//
// SwiftUI 预览（只在 Debug 编译，不进 Release 包）。
// 打开方式：Xcode 里按 ⌥⌘↩ 显示 Canvas，或在文件里选中某个 #Preview 单独运行。
//
// 说明：预览用独立临时目录 + MockData 生成的示例数据（含小票图片），
// 不会读写模拟器里真实 App 的 Documents，随便点、随便删都不影响你的数据。

#if DEBUG
import SwiftUI

// MARK: - 预览环境

private enum PreviewEnv {
    /// static let：整个预览进程只建一次，避免每次刷新重置状态
    static let sample: ReceiptStore = {
        let store = ReceiptStore.preview([])
        MockData.seed(into: store)      // 含真实绘制的小票图片
        return store
    }()
    static let empty = ReceiptStore.preview([])

    /// 详情页预览用：优先挑一张纪念收藏
    static var detailReceipt: Receipt {
        sample.receipts.first { $0.amount == nil }
            ?? sample.receipts.first
            ?? Receipt(type: .receipt, amount: nil)
    }
}

// MARK: - 整页预览

#Preview("① 整体 · 四 Tab") {
    RootView()
        .environmentObject(PreviewEnv.sample)
        .environmentObject(AppState())
}

#Preview("② 记账列表") {
    NavigationStack { ReceiptListView() }
        .environmentObject(PreviewEnv.sample)
        .environmentObject(AppState())
}

#Preview("③ 记账列表 · 空数据") {
    NavigationStack { ReceiptListView() }
        .environmentObject(PreviewEnv.empty)
        .environmentObject(AppState())
}

#Preview("④ 收藏夹") {
    CollectionView()
        .environmentObject(PreviewEnv.sample)
        .environmentObject(AppState())
}

#Preview("⑤ 统计 · 月") {
    StatsView()
        .environmentObject(PreviewEnv.sample)
}

#Preview("⑥ 票据详情 · 纪念收藏") {
    NavigationStack {
        ReceiptDetailView(receipt: PreviewEnv.detailReceipt)
    }
    .environmentObject(PreviewEnv.sample)
}

#Preview("⑦ 添加票据 · 标准表单") {
    NavigationStack { AddReceiptView() }
        .environmentObject(PreviewEnv.sample)
}

#Preview("⑧ 添加票据 · 拍照优先 B") {
    NavigationStack { AddReceiptViewB() }
        .environmentObject(PreviewEnv.sample)
}

#Preview("⑨ 旅行导图") {
    TravelMapView(plan: .sample)
}

// MARK: - 组件预览（调 UI 时最常用）

#Preview("⑩ 列表行") {
    ScrollView {
        LazyVStack(spacing: 0) {
            ForEach(PreviewEnv.sample.receipts) { receipt in
                ReceiptRow(receipt: receipt)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }
        }
        .padding(.vertical, 6)
    }
    .background(Color(.systemGroupedBackground))
    .environmentObject(PreviewEnv.sample)
}

#Preview("⑪ 收藏卡片") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(PreviewEnv.sample.receipts.filter { $0.amount == nil }) { receipt in
                CollectionCard(receipt: receipt)
            }
        }
        .padding()
    }
    .environmentObject(PreviewEnv.sample)
}

private struct CapsulePickersPreview: View {
    @State private var type: ReceiptType = .flight
    @State private var mood: Mood? = .calm

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("类型（可换行）").font(.caption).foregroundStyle(.secondary)
            TypeCapsulePicker(selection: $type)
            Text("心情（再点一次取消）").font(.caption).foregroundStyle(.secondary)
            MoodCapsulePicker(selection: $mood)
        }
        .padding()
    }
}

#Preview("⑫ 类型 / 心情胶囊") {
    CapsulePickersPreview()
}

#Preview("⑬ 每日柱状图") {
    DailyBarChartView(values: (0..<31).map { $0 % 5 == 0 ? Double($0) * 12.5 : 0 })
        .padding()
}
#endif
