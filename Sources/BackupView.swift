// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI

/// 备份与恢复界面。
/// 备份/恢复都很重（解码全部图片 + base64 + 单个大 JSON），因此放到后台队列，
/// 界面上用遮罩提示进度；恢复是破坏性操作，执行前必须二次确认。
struct BackupView: View {
    @EnvironmentObject private var store: ReceiptStore
    @Environment(\.dismiss) private var dismiss

    @State private var exportURL: URL?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var alertMessage: String?
    @State private var showAlert = false
    @State private var isWorking = false
    @State private var workingText = ""
    @State private var pendingRestoreURL: URL?
    @State private var showRestoreConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        createAndExport(includeImages: true)
                    } label: {
                        Label("备份到 iCloud Drive（含图片）", systemImage: "icloud.and.arrow.up")
                    }
                    Button {
                        createAndExport(includeImages: false)
                    } label: {
                        Label("仅备份数据（不含图片）", systemImage: "icloud")
                    }
                    Button {
                        showImporter = true
                    } label: {
                        Label("从备份恢复", systemImage: "icloud.and.arrow.down")
                    }
                } header: {
                    Text("iCloud 云端备份")
                } footer: {
                    Text("含图片的备份较大；仅备份数据体积小、速度快。备份文件保存到 iCloud Drive 或「文件」App，换机或误删后可随时恢复。")
                }
            }
            .disabled(isWorking)
            .navigationTitle("备份与恢复")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                        .disabled(isWorking)
                }
            }
            .overlay {
                if isWorking {
                    ProgressView(workingText)
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .sheet(isPresented: $showExporter) {
                if let exportURL {
                    FileExporter(url: exportURL)
                }
            }
            .sheet(isPresented: $showImporter) {
                FileImporter { url in
                    // 选文件后不直接覆盖，先确认
                    pendingRestoreURL = url
                    showRestoreConfirm = true
                }
            }
            .confirmationDialog("从备份恢复", isPresented: $showRestoreConfirm, titleVisibility: .visible) {
                Button("覆盖当前数据并恢复", role: .destructive) {
                    if let url = pendingRestoreURL {
                        restore(from: url)
                    }
                }
                Button("取消", role: .cancel) { pendingRestoreURL = nil }
            } message: {
                Text("当前 \(store.receipts.count) 条票据及其图片会被备份文件替换，此操作无法撤销。")
            }
            .alert("提示", isPresented: $showAlert) {
                Button("好", role: .cancel) {}
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    private func createAndExport(includeImages: Bool) {
        isWorking = true
        workingText = includeImages ? "正在打包图片…" : "正在导出数据…"
        let snapshot = store.receipts   // 主线程取快照，后台只读快照
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let url = try BackupService.createBackup(includeImages: includeImages, receipts: snapshot)
                DispatchQueue.main.async {
                    isWorking = false
                    exportURL = url
                    showExporter = true
                }
            } catch {
                DispatchQueue.main.async {
                    isWorking = false
                    alertMessage = "备份失败：\(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }

    private func restore(from url: URL) {
        isWorking = true
        workingText = "正在读取备份…"
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let payload = try BackupService.loadBackup(from: url)
                DispatchQueue.main.async {
                    workingText = "正在写入…"
                    do {
                        try store.replaceAll(receipts: payload.receipts,
                                             imagesByReceipt: payload.imagesByReceipt)
                        isWorking = false
                        pendingRestoreURL = nil
                        alertMessage = "恢复成功，共 \(payload.receipts.count) 条票据。"
                    } catch {
                        isWorking = false
                        alertMessage = "恢复失败：\(error.localizedDescription)"
                    }
                    showAlert = true
                }
            } catch {
                DispatchQueue.main.async {
                    isWorking = false
                    alertMessage = "读取备份失败：\(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
}
