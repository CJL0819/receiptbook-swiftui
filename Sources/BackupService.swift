// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import UIKit

/// 备份文件的结构：所有票据 + 每张票据的图片（base64 内嵌），单文件可移植。
struct BackupDocument: Codable {
    var version: Int
    var exportedAt: Date
    var receipts: [Receipt]
    var images: [String: [String]]   // receiptID -> [base64 JPEG]
}

/// 解析出来的备份内容：写库由调用方在主线程执行。
struct BackupPayload {
    var receipts: [Receipt]
    var imagesByReceipt: [String: [Data]]
}

/// iCloud 云端备份 / 恢复。
/// 备份文件通过系统的「存储到文件」保存到 iCloud Drive，恢复时从 iCloud Drive 选取。
/// 注意：这里的方法都是**同步且较重**的（解码全尺寸图 + base64 + JSON），
/// 调用方必须放到后台队列执行，不要直接在主线程调。
enum BackupService {
    /// 创建备份；`includeImages` 为 false 时仅备份元数据（体积小、速度快）。
    /// `receipts` 由调用方在主线程取好快照再传进来，避免后台线程读 @Published 数组。
    static func createBackup(includeImages: Bool = true, receipts snapshot: [Receipt]? = nil) throws -> URL {
        let store = ReceiptStore.shared
        let source = snapshot ?? store.receipts
        var images: [String: [String]] = [:]
        if includeImages {
            for receipt in source {
                let pages = store.images(for: receipt)
                images[receipt.id] = pages.compactMap { image in
                    image.jpegData(compressionQuality: 0.7)?.base64EncodedString()
                }
            }
        }

        let document = BackupDocument(version: 1, exportedAt: Date(),
                                      receipts: source, images: images)
        let data = try JSONEncoder().encode(document)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let suffix = includeImages ? "" : "-数据"
        let name = "小票收纳备份\(suffix)-\(formatter.string(from: Date())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }

    /// 只解析备份文件、不碰数据库；写库请回到主线程调 `replaceAll`。
    static func loadBackup(from url: URL) throws -> BackupPayload {
        let data = try Data(contentsOf: url)
        let document = try JSONDecoder().decode(BackupDocument.self, from: data)

        var imagesByReceipt: [String: [Data]] = [:]
        for (id, pages) in document.images {
            imagesByReceipt[id] = pages.compactMap { Data(base64Encoded: $0) }
        }
        return BackupPayload(receipts: document.receipts, imagesByReceipt: imagesByReceipt)
    }
}
