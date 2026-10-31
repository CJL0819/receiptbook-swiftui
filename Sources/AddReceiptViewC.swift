// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI
import UIKit

/// 方案 C：沉浸式（票据图背景）+ 浮动玻璃信息卡。
struct AddReceiptViewC: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: AddReceiptModel
    @State private var showSaved = false
    @State private var errorMessage = ""
    @State private var showError = false

    init(receipt: Receipt? = nil) {
        _model = StateObject(wrappedValue: AddReceiptModel(receipt: receipt))
    }

    var body: some View {
        ZStack {
            background

            VStack {
                Spacer()
                glassCard
            }
            .padding(16)
        }
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

    private var background: some View {
        Group {
            if let first = model.scannedImages.first {
                Image(uiImage: first)
                    .resizable()
                    .scaledToFill()
                    .overlay(Color.black.opacity(0.55))
            } else {
                Color(.systemGroupedBackground)
            }
        }
        .ignoresSafeArea()
    }

    private var glassCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                model.showScanner = true
            } label: {
                Label(model.scannedImages.isEmpty ? "扫描票据" : "重新扫描", systemImage: "camera.viewfinder")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)

            if !model.scannedImages.isEmpty {
                Text(model.scanStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextField("0.00（留空=纪念）", text: $model.amountText)
                .keyboardType(.decimalPad)
                .font(.system(size: 30, weight: .semibold, design: .monospaced))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ReceiptType.allCases, id: \.self) { t in
                        Button {
                            model.type = t
                        } label: {
                            Text(t.displayName)
                                .font(.subheadline)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(model.type == t ? t.tintColor : Color(.systemBackground))
                                .foregroundStyle(model.type == t ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

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

            Button(model.isEditing ? "保存修改" : "保存") {
                save()
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
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
