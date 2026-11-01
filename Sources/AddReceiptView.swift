// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI
import UIKit

struct AddReceiptView: View {
    @EnvironmentObject private var store: ReceiptStore
    @Environment(\.dismiss) private var dismiss

    private let receipt: Receipt?   // 非 nil 表示「编辑」模式

    @State private var scannedImages: [UIImage]
    @State private var type: ReceiptType
    @State private var date: Date
    @State private var amountText: String
    @State private var merchant: String
    @State private var note: String
    @State private var location: String
    @State private var address: String
    @State private var mood: Mood?
    @State private var tagsText: String

    @State private var scanStatus: String
    @State private var showScanner = false
    @State private var showSavedAlert = false
    @State private var errorMessage = ""
    @State private var showErrorAlert = false
    @State private var imagesChanged = false

    init(receipt: Receipt? = nil) {
        self.receipt = receipt
        _type = State(initialValue: receipt?.type ?? .invoice)
        _date = State(initialValue: receipt?.date ?? Date())
        _amountText = State(initialValue: receipt?.amount.map { String(format: "%.2f", $0) } ?? "")
        _merchant = State(initialValue: receipt?.merchant ?? "")
        _note = State(initialValue: receipt?.note ?? "")
        _location = State(initialValue: receipt?.location ?? "")
        _address = State(initialValue: receipt?.address ?? "")
        _mood = State(initialValue: receipt?.mood)
        _tagsText = State(initialValue: receipt?.tags.joined(separator: ", ") ?? "")
        // 用降采样预览图，避免编辑多页票据时在主线程解码全尺寸图（3 页 12MP ≈ 150MB）
        _scannedImages = State(initialValue: receipt.flatMap { ReceiptStore.shared.previewImages(for: $0) } ?? [])
        _scanStatus = State(initialValue: receipt == nil
            ? "尚未扫描。点击上方按钮，用相机拍摄并裁剪票据。"
            : "已有 \(receipt?.pageCount ?? 0) 页图片，可重新扫描替换。")
    }

    var body: some View {
        Form {
            Section {
                Button {
                    showScanner = true
                } label: {
                    Label("扫描票据", systemImage: "camera.viewfinder")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)

                Text(scanStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if !scannedImages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(scannedImages.indices, id: \.self) { index in
                                Image(uiImage: scannedImages[index])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 90, height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .overlay(alignment: .topTrailing) {
                                        Button {
                                            guard scannedImages.indices.contains(index) else { return }
                                            scannedImages.remove(at: index)
                                            imagesChanged = true
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.title3)
                                                .foregroundStyle(.white, .black.opacity(0.45))
                                        }
                                        .padding(3)
                                    }
                            }
                        }
                    }
                }
            }

            Section("类型") {
                TypeCapsulePicker(selection: $type)
            }

            Section("日期") {
                DatePicker("日期", selection: $date)
            }

            Section {
                TextField("0.00", text: $amountText)
                    .keyboardType(.decimalPad)
            } header: {
                Text("金额（元）")
            } footer: {
                Text("留空表示纪念收藏，不计入统计。")
            }

            Section("商家 / 抬头") {
                TextField("例如：全家便利店", text: $merchant)
            }

            Section("备注") {
                TextField("可选", text: $note)
            }

            Section("地点（可选）") {
                LocationSection(location: $location, address: $address)
            }

            Section("心情（可选）") {
                MoodCapsulePicker(selection: $mood)
            }

            Section {
                TextField("用逗号分隔，如：演出, 旅行", text: $tagsText)
            } header: {
                Text("标签（可选）")
            } footer: {
                Text("收藏页可以按标签筛选。")
            }

            Section {
                Button(receipt == nil ? "保存" : "保存修改") {
                    save()
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .navigationTitle(receipt == nil ? "添加票据" : "编辑票据")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showScanner) {
            DocumentScanner { images in
                scannedImages = images
                imagesChanged = true
                runOCR()
            }
            .ignoresSafeArea()
        }
        .alert("已保存", isPresented: $showSavedAlert) {
            Button("好", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("票据已加入收纳。")
        }
        .alert("提示", isPresented: $showErrorAlert) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - OCR

    private func runOCR() {
        guard !scannedImages.isEmpty else { return }
        scanStatus = "正在识别票据…"
        let images = scannedImages

        DispatchQueue.global(qos: .userInitiated).async {
            let result = ReceiptOCR.analyze(images: images)
            DispatchQueue.main.async {
                apply(result)
            }
        }
    }

    private func apply(_ result: ReceiptOCRResult) {
        var foundAny = false
        if result.amount > 0 && amountText.isEmpty {
            amountText = String(format: "%.2f", result.amount)
            foundAny = true
        }
        if !result.merchant.isEmpty && merchant.isEmpty {
            merchant = result.merchant
            foundAny = true
        }
        if let recognizedDate = result.date {
            date = recognizedDate
            foundAny = true
        }
        if !result.summary.isEmpty && note.isEmpty {
            note = result.summary
            foundAny = true
        }
        scanStatus = foundAny
            ? "已识别，请核对下方信息后保存。"
            : "未能自动识别金额/商家，请手动填写。"
    }

    // MARK: - 保存

    private func save() {
        let trimmedAmount = amountText.trimmingCharacters(in: .whitespaces)
        let amount: Double?
        if trimmedAmount.isEmpty {
            amount = nil
        } else {
            guard let value = Double(trimmedAmount), value >= 0 else {
                errorMessage = "请输入正确的金额（仅数字，或留空表示纪念收藏）"
                showErrorAlert = true
                return
            }
            amount = value
        }

        let trimmedMerchant = merchant.trimmingCharacters(in: .whitespaces)
        let trimmedNote = note.trimmingCharacters(in: .whitespaces)
        let trimmedLocation = location.trimmingCharacters(in: .whitespaces)
        let locationValue = trimmedLocation.isEmpty ? nil : trimmedLocation
        let trimmedAddress = address.trimmingCharacters(in: .whitespaces)
        let addressValue = trimmedAddress.isEmpty ? nil : trimmedAddress
        let tagValues = tagsText.parsedTags

        do {
            if let receipt {
                try store.update(receipt, type: type, date: date, amount: amount,
                                 merchant: trimmedMerchant, note: trimmedNote,
                                 images: imagesChanged ? scannedImages : nil,
                                 location: locationValue, address: addressValue, mood: mood, tags: tagValues)
            } else {
                try store.add(type: type, date: date, amount: amount,
                              merchant: trimmedMerchant, note: trimmedNote, images: scannedImages,
                              location: locationValue, address: addressValue, mood: mood, tags: tagValues)
            }
        } catch {
            errorMessage = "保存失败：\(error.localizedDescription)"
            showErrorAlert = true
            return
        }

        resetForm()
        showSavedAlert = true
    }

    private func resetForm() {
        scannedImages = []
        imagesChanged = false
        type = .invoice
        date = Date()
        amountText = ""
        merchant = ""
        note = ""
        location = ""
        address = ""
        mood = nil
        tagsText = ""
        scanStatus = "尚未扫描。点击上方按钮，用相机拍摄并裁剪票据。"
    }
}
