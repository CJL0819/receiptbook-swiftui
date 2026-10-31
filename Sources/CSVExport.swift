// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI
import UIKit

/// 把票据导出为 CSV 文件。
enum CSVExporter {
    static func write(_ receipts: [Receipt]) -> URL? {
        var lines: [String] = []
        lines.append("类型,日期,金额,商家/抬头,备注,地点,心情,标签,页数")

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"

        for receipt in receipts {
            let row = [
                receipt.type.displayName,
                formatter.string(from: receipt.date),
                receipt.amount.map { String(format: "%.2f", $0) } ?? "",
                receipt.merchant,
                receipt.note,
                receipt.location ?? "",
                receipt.mood?.rawValue ?? "",
                receipt.tags.joined(separator: "、"),
                "\(receipt.pageCount)"
            ]
            lines.append(row.map(escape).joined(separator: ","))
        }

        // 加 UTF-8 BOM，Excel / Numbers 打开中文不乱码
        let csv = "\u{FEFF}" + lines.joined(separator: "\n") + "\n"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("receipts-\(timestamp()).csv")
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private static func escape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}

/// UIActivityViewController 的 SwiftUI 桥接（分享文件）。
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// 导出按钮：点击生成 CSV 并弹出系统分享面板。
/// 传 `receipts` 可只导出某个子集（如某分类/某天），不传则导出全部。
struct ExportButton: View {
    var receipts: [Receipt]? = nil
    @EnvironmentObject private var store: ReceiptStore

    @State private var exportURL: URL?
    @State private var showShare = false

    var body: some View {
        Button {
            exportURL = CSVExporter.write(receipts ?? store.receipts)
            showShare = exportURL != nil
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .sheet(isPresented: $showShare) {
            if let exportURL {
                ShareSheet(items: [exportURL])
            }
        }
    }
}
