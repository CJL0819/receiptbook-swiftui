// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI
import UIKit

/// 添加/编辑票据的共享表单模型（OCR + 保存逻辑，供各布局复用）。
final class AddReceiptModel: ObservableObject {
    @Published var scannedImages: [UIImage] = []
    @Published var type: ReceiptType = .invoice
    @Published var date = Date()
    @Published var amountText = ""
    @Published var merchant = ""
    @Published var note = ""
    @Published var location = ""
    @Published var mood: Mood?
    @Published var tagsText = ""
    @Published var scanStatus = "尚未扫描。点击上方按钮，用相机拍摄并裁剪票据。"
    @Published var imagesChanged = false
    @Published var showScanner = false

    private let receipt: Receipt?

    var isEditing: Bool { receipt != nil }

    init(receipt: Receipt? = nil) {
        self.receipt = receipt
        type = receipt?.type ?? .invoice
        date = receipt?.date ?? Date()
        amountText = receipt?.amount.map { String(format: "%.2f", $0) } ?? ""
        merchant = receipt?.merchant ?? ""
        note = receipt?.note ?? ""
        location = receipt?.location ?? ""
        mood = receipt?.mood
        tagsText = receipt?.tags.joined(separator: ", ") ?? ""
        scannedImages = receipt.flatMap { ReceiptStore.shared.images(for: $0) } ?? []
        scanStatus = receipt == nil
            ? "尚未扫描。点击上方按钮，用相机拍摄并裁剪票据。"
            : "已有 \(receipt?.pageCount ?? 0) 页图片，可重新扫描替换。"
    }

    func scanFinished(_ images: [UIImage]) {
        scannedImages = images
        imagesChanged = true
        runOCR()
    }

    func removePage(at index: Int) {
        guard scannedImages.indices.contains(index) else { return }
        scannedImages.remove(at: index)
        imagesChanged = true
    }

    func runOCR() {
        guard !scannedImages.isEmpty else { return }
        scanStatus = "正在识别票据…"
        let images = scannedImages
        DispatchQueue.global(qos: .userInitiated).async {
            let result = ReceiptOCR.analyze(images: images)
            DispatchQueue.main.async {
                self.applyOCR(result)
            }
        }
    }

    private func applyOCR(_ result: ReceiptOCRResult) {
        var found = false
        if result.amount > 0 && amountText.isEmpty { amountText = String(format: "%.2f", result.amount); found = true }
        if !result.merchant.isEmpty && merchant.isEmpty { merchant = result.merchant; found = true }
        if let d = result.date { date = d; found = true }
        if !result.summary.isEmpty && note.isEmpty { note = result.summary; found = true }
        scanStatus = found ? "已识别，请核对信息后保存。" : "未能自动识别金额/商家，请手动填写。"
    }

    /// 保存，返回错误信息（nil 表示成功）。
    func save() -> String? {
        let trimmedAmount = amountText.trimmingCharacters(in: .whitespaces)
        let amount: Double?
        if trimmedAmount.isEmpty {
            amount = nil
        } else {
            guard let value = Double(trimmedAmount), value >= 0 else {
                return "请输入正确的金额（仅数字，或留空表示纪念收藏）"
            }
            amount = value
        }

        let merchantValue = merchant.trimmingCharacters(in: .whitespaces)
        let noteValue = note.trimmingCharacters(in: .whitespaces)
        let trimmedLocation = location.trimmingCharacters(in: .whitespaces)
        let locationValue = trimmedLocation.isEmpty ? nil : trimmedLocation
        let tags = tagsText.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

        do {
            if let receipt {
                try ReceiptStore.shared.update(receipt, type: type, date: date, amount: amount,
                                               merchant: merchantValue, note: noteValue,
                                               images: imagesChanged ? scannedImages : nil,
                                               location: locationValue, mood: mood, tags: tags)
            } else {
                try ReceiptStore.shared.add(type: type, date: date, amount: amount,
                                            merchant: merchantValue, note: noteValue, images: scannedImages,
                                            location: locationValue, mood: mood, tags: tags)
            }
            return nil
        } catch {
            return "保存失败：\(error.localizedDescription)"
        }
    }
}
