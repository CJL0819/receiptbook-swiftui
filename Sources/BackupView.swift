// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI

/// 备份与恢复界面。
struct BackupView: View {
    @EnvironmentObject private var store: ReceiptStore
    @Environment(\.dismiss) private var dismiss

    @State private var exportURL: URL?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var alertMessage: String?
    @State private var showAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        createAndExport()
                    } label: {
                        Label("备份到 iCloud Drive", systemImage: "icloud.and.arrow.up")
                    }
                    Button {
                        showImporter = true
                    } label: {
                        Label("从备份恢复", systemImage: "icloud.and.arrow.down")
                    }
                } header: {
                    Text("iCloud 云端备份")
                } footer: {
                    Text("备份文件保存到 iCloud Drive 或「文件」App，换机或误删后可随时恢复。")
                }
            }
            .navigationTitle("备份与恢复")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(isPresented: $showExporter) {
                if let exportURL {
                    FileExporter(url: exportURL)
                }
            }
            .sheet(isPresented: $showImporter) {
                FileImporter { url in
                    restore(from: url)
                }
            }
            .alert("提示", isPresented: $showAlert) {
                Button("好", role: .cancel) {}
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    private func createAndExport() {
        do {
            exportURL = try BackupService.createBackup()
            showExporter = true
        } catch {
            alertMessage = "备份失败：\(error.localizedDescription)"
            showAlert = true
        }
    }

    private func restore(from url: URL) {
        do {
            try BackupService.restore(from: url)
            alertMessage = "恢复成功，数据已更新。"
        } catch {
            alertMessage = "恢复失败：\(error.localizedDescription)"
        }
        showAlert = true
    }
}
