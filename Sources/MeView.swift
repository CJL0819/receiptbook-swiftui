// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI

/// 「我的」页：数据操作（备份/导出）与关于信息。
struct MeView: View {
    @EnvironmentObject private var store: ReceiptStore
    @AppStorage("addReceiptStyle") private var style: AddReceiptStyle = .plain
    @State private var exportURL: URL?
    @State private var showShare = false
    @State private var showRestoreConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Section("数据") {
                    NavigationLink {
                        BackupView()
                    } label: {
                        Label("备份与恢复", systemImage: "icloud.and.arrow.up")
                    }
                    Button {
                        exportAll()
                    } label: {
                        Label("导出全部 CSV", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        showRestoreConfirm = true
                    } label: {
                        Label("恢复默认数据", systemImage: "arrow.counterclockwise")
                    }
                    .accessibilityIdentifier("me.restoreDefaults")
                }

                Section("开发者模式") {
                    Picker("添加页样式", selection: $style) {
                        ForEach(AddReceiptStyle.allCases) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                }

                if let lastError = store.lastError {
                    Section("存储状态") {
                        Label(lastError, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }

                Section("关于") {
                    LabeledContent("版本", value: "1.0.0")
                    LabeledContent("票据总数", value: "\(store.receipts.count)")
                    LabeledContent("纪念收藏", value: "\(store.receipts.filter { $0.amount == nil }.count) 张")
                }
            }
            .navigationTitle("我的")
            .confirmationDialog("恢复默认数据？",
                                isPresented: $showRestoreConfirm,
                                titleVisibility: .visible) {
                Button("恢复", role: .destructive) {
                    SampleDataBootstrap.restoreDefaults()
                    Haptics.done()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text(store.receipts.isEmpty
                     ? "将写入 20 条示例票据，方便直接体验列表、统计与收藏。"
                     : "将清空当前 \(store.receipts.count) 条票据，并重新写入 20 条示例票据。")
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: FloatingTabMetrics.reservedHeight)
            }
        }
        .sheet(isPresented: $showShare) {
            if let exportURL {
                ShareSheet(items: [exportURL])
            }
        }
    }

    private func exportAll() {
        exportURL = CSVExporter.write(store.receipts)
        showShare = exportURL != nil
    }
}
