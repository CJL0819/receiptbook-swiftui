// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI
import UIKit

/// 方案 B：拍照优先 + 底部信息卡片。
struct AddReceiptViewB: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: AddReceiptModel
    @State private var showSaved = false
    @State private var errorMessage = ""
    @State private var showError = false

    init(receipt: Receipt? = nil) {
        _model = StateObject(wrappedValue: AddReceiptModel(receipt: receipt))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                scanCard
                infoCard
                saveButton
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(model.isEditing ? "编辑票据" : "添加票据")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $model.showScanner) {
            DocumentScanner { images in
                model.scanFinished(images)
            }
            .ignoresSafeArea()
        }
        .alert("已保存", isPresented: $showSaved) {
            Button("好", role: .cancel) { dismiss() }
        } message: {
            Text("票据已加入收纳。")
        }
        .alert("提示", isPresented: $showError) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private var scanCard: some View {
        VStack(spacing: 10) {
            if model.scannedImages.isEmpty {
                Button {
                    model.showScanner = true
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 38))
                        Text("扫描票据")
                            .font(.headline)
                        Text("拍摄并裁剪票据，自动识别金额与商家")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 26)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(model.scannedImages.indices, id: \.self) { index in
                            Image(uiImage: model.scannedImages[index])
                                .resizable()
                                .scaledToFill()
                                .frame(width: 96, height: 124)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(alignment: .topTrailing) {
                                    Button { model.removePage(at: index) } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(.white, .black.opacity(0.45))
                                    }
                                    .padding(3)
                                }
                        }
                        Button {
                            model.showScanner = true
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill").font(.title)
                                Text("重扫").font(.caption)
                            }
                            .frame(width: 96, height: 124)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                Text(model.scanStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("金额（元）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("0.00（留空=纪念）", text: $model.amountText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 30, weight: .semibold, design: .monospaced))
            }

            Divider()

            Picker("类型", selection: $model.type) {
                ForEach(ReceiptType.allCases, id: \.self) { t in
                    Text(t.displayName).tag(t)
                }
            }
            .pickerStyle(.menu)

            DatePicker("日期", selection: $model.date)

            TextField("商家 / 抬头", text: $model.merchant)
                .textFieldStyle(.roundedBorder)
            TextField("备注（可选）", text: $model.note)
                .textFieldStyle(.roundedBorder)

            DisclosureGroup("更多（地点 / 心情 / 标签）") {
                TextField("地点", text: $model.location)
                    .textFieldStyle(.roundedBorder)
                Picker("心情", selection: $model.mood) {
                    Text("不选").tag(Mood?.none)
                    ForEach(Mood.allCases) { m in
                        Text(m.rawValue).tag(Mood?.some(m))
                    }
                }
                TextField("标签（逗号分隔）", text: $model.tagsText)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var saveButton: some View {
        Button(model.isEditing ? "保存修改" : "保存") {
            save()
        }
        .font(.headline)
        .frame(maxWidth: .infinity)
        .buttonStyle(.borderedProminent)
        .tint(.green)
    }

    private func save() {
        if let error = model.save() {
            errorMessage = error
            showError = true
        } else {
            showSaved = true
        }
    }
}
