// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import UIKit
import Combine
import ImageIO

enum ReceiptStoreError: Error {
    case receiptNotFound
}

/// 票据的持久化存储：JSON 索引 + 按页保存的 JPEG 图片。
/// 作为 ObservableObject，数据变化会自动驱动 SwiftUI 视图刷新。
/// 金额为 nil 的票据（纪念收藏）不参与任何支出统计。
final class ReceiptStore: ObservableObject {
    static let shared = ReceiptStore()

    @Published private(set) var receipts: [Receipt] = []

    private let indexURL: URL
    private let imagesRootURL: URL
    private let imageCache = NSCache<NSString, UIImage>()
    private let thumbnailCache = NSCache<NSString, UIImage>()

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        indexURL = docs.appendingPathComponent("receipts.json")
        imagesRootURL = docs.appendingPathComponent("Receipts", isDirectory: true)
        load()
    }

    // MARK: - 持久化

    private func load() {
        if let decoded = decodeIndex(at: indexURL) {
            receipts = decoded
        } else if let decoded = decodeIndex(at: indexURL.appendingPathExtension("bak")) {
            receipts = decoded
        }
        sort()
    }

    private func decodeIndex(at url: URL) -> [Receipt]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([Receipt].self, from: data)
    }

    private func sort() {
        receipts.sort { $0.date > $1.date }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(receipts) else { return }
        // 写入前备份旧索引，防止写入中断导致数据损坏
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: indexURL.path) {
            try? fileManager.removeItem(at: indexURL.appendingPathExtension("bak"))
            try? fileManager.copyItem(at: indexURL, to: indexURL.appendingPathExtension("bak"))
        }
        try? data.write(to: indexURL, options: .atomic)
        WidgetBridge.publish(store: self)
    }

    private func directory(for receipt: Receipt) -> URL {
        imagesRootURL.appendingPathComponent(receipt.id, isDirectory: true)
    }

    // MARK: - 图片

    /// 原图（用于详情页缩放 / 备份 / 编辑）。
    func image(for receipt: Receipt, page: Int) -> UIImage? {
        let key = "\(receipt.id)-\(page)" as NSString
        if let cached = imageCache.object(forKey: key) { return cached }

        let url = directory(for: receipt).appendingPathComponent("page\(page).jpg")
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let image = UIImage(data: data) else { return nil }
        imageCache.setObject(image, forKey: key)
        return image
    }

    func images(for receipt: Receipt) -> [UIImage] {
        (0..<receipt.pageCount).compactMap { image(for: receipt, page: $0) }
    }

    /// 详情页预览图：中等分辨率、方向已校正，避免全尺寸解码造成内存占用与方向异常。
    func previewImage(for receipt: Receipt, page: Int, maxPixel: CGFloat = 2048) -> UIImage? {
        let key = "\(receipt.id)-\(page)-preview-\(Int(maxPixel))" as NSString
        if let cached = imageCache.object(forKey: key) { return cached }
        let url = directory(for: receipt).appendingPathComponent("page\(page).jpg")
        guard let image = downsample(imageAt: url, maxPixel: maxPixel) else { return nil }
        imageCache.setObject(image, forKey: key)
        return image
    }

    func previewImages(for receipt: Receipt) -> [UIImage] {
        (0..<receipt.pageCount).compactMap { previewImage(for: receipt, page: $0) }
    }

    /// 降采样缩略图（用于列表 / 收藏卡片，避免解码全尺寸图占用内存）。
    func thumbnail(for receipt: Receipt, page: Int) -> UIImage? {
        let key = "\(receipt.id)-\(page)-thumb" as NSString
        if let cached = thumbnailCache.object(forKey: key) { return cached }

        let url = directory(for: receipt).appendingPathComponent("page\(page).jpg")
        guard let image = downsample(imageAt: url, maxPixel: 512) else { return nil }
        thumbnailCache.setObject(image, forKey: key)
        return image
    }

    private func downsample(imageAt url: URL, maxPixel: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    // MARK: - 备份 / 恢复

    func reload() {
        receipts = []
        imageCache.removeAllObjects()
        thumbnailCache.removeAllObjects()
        load()
    }

    func replaceAll(receipts newReceipts: [Receipt], imagesByReceipt: [String: [Data]]) throws {
        try? FileManager.default.removeItem(at: imagesRootURL)
        try FileManager.default.createDirectory(at: imagesRootURL, withIntermediateDirectories: true)

        for receipt in newReceipts {
            guard let pages = imagesByReceipt[receipt.id], !pages.isEmpty else { continue }
            let dir = directory(for: receipt)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            for (index, data) in pages.enumerated() {
                try data.write(to: dir.appendingPathComponent("page\(index).jpg"), options: .atomic)
            }
        }

        receipts = newReceipts
        sort()
        persist()
        imageCache.removeAllObjects()
        thumbnailCache.removeAllObjects()
    }

    // MARK: - 增删改

    @discardableResult
    func add(type: ReceiptType,
             date: Date,
             amount: Double?,
             merchant: String,
             note: String,
             images: [UIImage],
             location: String?,
             mood: Mood?,
             tags: [String]) throws -> Receipt {
        let receipt = Receipt(type: type, date: date, amount: amount,
                              merchant: merchant, note: note, pageCount: images.count,
                              location: location, mood: mood, tags: tags)
        let dir = directory(for: receipt)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        for (index, image) in images.enumerated() {
            if let data = image.jpegData(compressionQuality: 0.85) {
                try data.write(to: dir.appendingPathComponent("page\(index).jpg"), options: .atomic)
            }
        }

        receipts.append(receipt)
        sort()
        persist()
        return receipt
    }

    func delete(_ receipt: Receipt) {
        receipts.removeAll { $0.id == receipt.id }
        try? FileManager.default.removeItem(at: directory(for: receipt))
        imageCache.removeAllObjects()
        thumbnailCache.removeAllObjects()
        persist()
    }

    /// 更新票据；`images` 传 nil 表示保留原图（避免编辑元数据时重复压缩图片）。
    @discardableResult
    func update(_ receipt: Receipt,
                type: ReceiptType,
                date: Date,
                amount: Double?,
                merchant: String,
                note: String,
                images: [UIImage]?,
                location: String?,
                mood: Mood?,
                tags: [String]) throws -> Receipt {
        guard let index = receipts.firstIndex(where: { $0.id == receipt.id }) else {
            throw ReceiptStoreError.receiptNotFound
        }
        let old = receipts[index]
        let dir = directory(for: old)

        var pageCount = old.pageCount
        if let images {
            try? FileManager.default.removeItem(at: dir)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            for (page, image) in images.enumerated() {
                if let data = image.jpegData(compressionQuality: 0.85) {
                    try data.write(to: dir.appendingPathComponent("page\(page).jpg"), options: .atomic)
                }
            }
            pageCount = images.count
        }

        var updated = Receipt(type: type, date: date, amount: amount,
                              merchant: merchant, note: note, pageCount: pageCount,
                              location: location, mood: mood, tags: tags)
        updated.id = old.id
        updated.createdAt = old.createdAt
        receipts[index] = updated
        imageCache.removeAllObjects()
        thumbnailCache.removeAllObjects()
        sort()
        persist()
        return updated
    }

    // MARK: - 统计聚合（仅统计有金额的票据）

    var totalAmount: Double {
        receipts.reduce(0) { $0 + ($1.amount ?? 0) }
    }

    func totalAmount(on day: Date) -> Double {
        receipts
            .filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
            .reduce(0) { $0 + ($1.amount ?? 0) }
    }

    func totalAmount(inMonthOf day: Date) -> Double {
        receipts
            .filter { Calendar.current.isDate($0.date, equalTo: day, toGranularity: .month) }
            .reduce(0) { $0 + ($1.amount ?? 0) }
    }

    func totalByType() -> [ReceiptType: Double] {
        receipts.reduce(into: [ReceiptType: Double]()) { result, receipt in
            if let amount = receipt.amount {
                result[receipt.type, default: 0] += amount
            }
        }
    }

    func receipts(on day: Date) -> [Receipt] {
        receipts.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }

    func receipts(ofType type: ReceiptType) -> [Receipt] {
        receipts.filter { $0.type == type }
    }

    func receipts(inMonthOf day: Date) -> [Receipt] {
        receipts.filter { Calendar.current.isDate($0.date, equalTo: day, toGranularity: .month) }
    }

    func receipts(inYearOf day: Date) -> [Receipt] {
        receipts.filter { Calendar.current.isDate($0.date, equalTo: day, toGranularity: .year) }
    }

    /// 某年 12 个月的每月支出（index 0 = 1 月）。
    func monthlyTotals(inYearOf day: Date) -> [Double] {
        let calendar = Calendar.current
        var totals = [Double](repeating: 0, count: 12)
        for receipt in receipts where calendar.isDate(receipt.date, equalTo: day, toGranularity: .year) {
            if let amount = receipt.amount {
                let index = calendar.component(.month, from: receipt.date) - 1
                if index >= 0 && index < 12 {
                    totals[index] += amount
                }
            }
        }
        return totals
    }

    func distinctDaysWithReceipts() -> [Date] {
        Set(receipts.map { Calendar.current.startOfDay(for: $0.date) }).sorted(by: >)
    }

    func receiptCount(inMonthOf day: Date) -> Int {
        receipts.filter {
            Calendar.current.isDate($0.date, equalTo: day, toGranularity: .month) && $0.amount != nil
        }.count
    }

    /// 当月每日支出，index 0 = 当月 1 号（无金额票据不计入）。
    func dailyTotals(inMonthOf day: Date) -> [Double] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: day) else { return [] }
        var totals = [Double](repeating: 0, count: range.count)
        for receipt in receipts where calendar.isDate(receipt.date, equalTo: day, toGranularity: .month) {
            if let amount = receipt.amount {
                let index = calendar.component(.day, from: receipt.date) - 1
                if index >= 0 && index < totals.count {
                    totals[index] += amount
                }
            }
        }
        return totals
    }
}
