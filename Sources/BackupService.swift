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

/// iCloud 云端备份 / 恢复。
/// 备份文件通过系统的「存储到文件」保存到 iCloud Drive，恢复时从 iCloud Drive 选取。
enum BackupService {
    static func createBackup() throws -> URL {
        let store = ReceiptStore.shared
        var images: [String: [String]] = [:]
        for receipt in store.receipts {
            let pages = store.images(for: receipt)
            images[receipt.id] = pages.compactMap { image in
                image.jpegData(compressionQuality: 0.9)?.base64EncodedString()
            }
        }

        let document = BackupDocument(version: 1, exportedAt: Date(),
                                      receipts: store.receipts, images: images)
        let data = try JSONEncoder().encode(document)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let name = "小票收纳备份-\(formatter.string(from: Date())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }

    static func restore(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let document = try JSONDecoder().decode(BackupDocument.self, from: data)

        var imagesByReceipt: [String: [Data]] = [:]
        for (id, pages) in document.images {
            imagesByReceipt[id] = pages.compactMap { Data(base64Encoded: $0) }
        }

        try ReceiptStore.shared.replaceAll(receipts: document.receipts, imagesByReceipt: imagesByReceipt)
    }
}
