// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import UIKit
import Vision

/// 从票据扫描图里抽出来的信息。
struct ReceiptOCRResult {
    var amount: Double = 0          // 0 表示未识别到
    var merchant: String = ""
    var date: Date?                 // 可能为 nil
    var summary: String = ""        // 生成的备注摘要
    var rawText: String = ""        // 识别出的全部文本，供以后扩展
}

enum ReceiptOCR {
    /// 对若干张扫描图做 OCR，并用规则抽取金额/商家/日期，生成摘要。
    static func analyze(images: [UIImage]) -> ReceiptOCRResult {
        var allLines: [String] = []
        for image in images {
            allLines.append(contentsOf: recognizedLines(in: image))
        }

        var result = ReceiptOCRResult()
        result.rawText = allLines.joined(separator: "\n")
        result.amount = extractAmount(from: allLines)
        result.merchant = extractMerchant(from: allLines)
        result.date = extractDate(from: allLines)
        result.summary = buildSummary(amount: result.amount, merchant: result.merchant)
        return result
    }

    // MARK: - OCR

    private static func recognizedLines(in image: UIImage) -> [String] {
        guard let cgImage = image.cgImage else { return [] }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "en-US"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("ReceiptOCR error: \(error.localizedDescription)")
            return []
        }

        let observations = request.results ?? []
        // 按从上到下排序：Vision 的 boundingBox 原点在左下，y 越大越靠上。
        let sorted = observations.sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y }
        return sorted.compactMap { observation in
            observation.topCandidates(1).first?.string
        }
    }

    // MARK: - 抽取规则

    private static func extractAmount(from lines: [String]) -> Double {
        let keywords = [
            "合计", "总计", "应付", "应收", "实收", "实付",
            "消费金额", "应付金额", "实付金额", "金额",
            "total", "amount", "sum", "grand"
        ]
        for line in lines {
            let lower = line.lowercased()
            let hitKeyword = keywords.contains { lower.contains($0) }
            let hasSymbol = line.contains("¥") || line.contains("￥")
            guard hitKeyword || hasSymbol else { continue }
            if let number = lastNumber(in: line), number > 0 {
                return number
            }
        }
        return 0
    }

    private static func extractMerchant(from lines: [String]) -> String {
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && trimmed.count <= 30 {
                return trimmed
            }
        }
        return ""
    }

    private static func extractDate(from lines: [String]) -> Date? {
        for line in lines {
            if let date = parseDate(from: line) { return date }
        }
        return nil
    }

    private static func buildSummary(amount: Double, merchant: String) -> String {
        if amount > 0 && !merchant.isEmpty {
            return "\(merchant) 消费 ¥\(String(format: "%.2f", amount))"
        }
        if amount > 0 {
            return "消费 ¥\(String(format: "%.2f", amount))"
        }
        if !merchant.isEmpty {
            return merchant
        }
        return ""
    }

    // MARK: - Helpers

    private static func lastNumber(in string: String) -> Double? {
        let pattern = #"\d[\d,]*(?:\.\d+)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(string.startIndex..<string.endIndex, in: string)
        let matches = regex.matches(in: string, range: range)

        var value: Double?
        for match in matches {
            guard let matchedRange = Range(match.range, in: string) else { continue }
            var numberString = String(string[matchedRange])
            numberString = numberString.replacingOccurrences(of: ",", with: "")
            value = Double(numberString)
        }
        return value
    }

    private static func parseDate(from string: String) -> Date? {
        let calendar = Calendar.current
        var year = 0, month = 0, day = 0

        if let full = firstMatchGroups(pattern: #"(\d{4})[年/\-](\d{1,2})[月/\-](\d{1,2})"#, in: string) {
            year = full[0]
            month = full[1]
            day = full[2]
        } else {
            guard let md = firstMatchGroups(pattern: #"(\d{1,2})月(\d{1,2})日"#, in: string) else { return nil }
            year = calendar.component(.year, from: Date())
            month = md[0]
            day = md[1]
        }

        var hour = 0, minute = 0
        if let time = firstMatchGroups(pattern: #"(\d{1,2}):(\d{2})"#, in: string) {
            hour = time[0]
            minute = time[1]
        }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)
    }

    /// 返回第一个匹配的捕获组（转换为 Int）。
    private static func firstMatchGroups(pattern: String, in string: String) -> [Int]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(string.startIndex..<string.endIndex, in: string)
        guard let match = regex.firstMatch(in: string, range: range) else { return nil }

        var groups: [Int] = []
        for i in 1..<match.numberOfRanges {
            guard let matchedRange = Range(match.range(at: i), in: string) else {
                groups.append(0)
                continue
            }
            groups.append(Int(String(string[matchedRange])) ?? 0)
        }
        return groups
    }
}
