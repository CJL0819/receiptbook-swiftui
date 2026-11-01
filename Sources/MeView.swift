// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI

/// 「我的」页：数据操作（备份/导出）与关于信息。
struct MeView: View {
    @EnvironmentObject private var store: ReceiptStore
    @AppStorage("addReceiptStyle") private var style: AddReceiptStyle = .plain
    @State private var exportURL: URL?
    @State private var showShare = false

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
