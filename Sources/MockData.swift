// SPDX-License-Identifier: MIT
// Copyright (c) 2026
//
// 生成一批「看起来像真小票」的示例数据。
// 每条票据会现场绘制 1–2 张小票图片并写进 store，
// 这样列表缩略图、页数角标、详情大图、统计都有真实内容可看。
//
// 首次启动由 `SampleDataBootstrap` 自动灌入，Debug 下也可以用
//   xcrun simctl launch booted com.receiptbook -seedSampleData
// 手动触发（仅当库为空时生效）。

import UIKit

enum MockData {
    struct Spec {
        var type: ReceiptType
        var date: Date
        var amount: Double?
        var merchant: String
        var note: String
        var location: String?
        var address: String?
        var mood: Mood?
        var tags: [String]
        var pages: Int
        var items: [(String, String)]   // (名称, 金额文本)
    }

    // MARK: - 示例数据

    static func specs() -> [Spec] {
        let calendar = Calendar.current
        let now = Date()

        func at(days: Int = 0, months: Int = 0, years: Int = 0, hour: Int = 12) -> Date {
            var date = now
            if years != 0 { date = calendar.date(byAdding: .year, value: years, to: date) ?? date }
            if months != 0 { date = calendar.date(byAdding: .month, value: months, to: date) ?? date }
            if days != 0 { date = calendar.date(byAdding: .day, value: days, to: date) ?? date }
            return calendar.date(bySettingHour: hour, minute: 30, second: 0, of: date) ?? date
        }

        return [
            Spec(type: .receipt, date: at(hour: 9), amount: 28.5,
                 merchant: "全家便利店", note: "早餐",
                 location: nil, address: nil, mood: nil, tags: [], pages: 1,
                 items: [("关东煮组合", "12.00"), ("鸡蛋三明治", "9.50"), ("矿泉水", "7.00")]),

            Spec(type: .invoice, date: at(days: -1, hour: 19), amount: 468,
                 merchant: "海底捞火锅（望京店）", note: "聚餐",
                 location: "北京市朝阳区", address: "望京街 9 号", mood: .happy, tags: ["聚餐"], pages: 2,
                 items: [("麻辣锅底", "78.00"), ("毛肚", "68.00"), ("鲜切牛肉", "88.00"), ("酸梅汤", "36.00")]),

            Spec(type: .flight, date: at(days: -3, hour: 7), amount: 1280,
                 merchant: "中国国际航空 CA1831", note: "北京 → 上海",
                 location: "首都机场 T3", address: nil, mood: nil, tags: ["出差"], pages: 1,
                 items: [("经济舱 Y 舱", "1180.00"), ("机建燃油附加", "100.00")]),

            Spec(type: .toll, date: at(days: -5, hour: 16), amount: 45,
                 merchant: "京承高速收费站", note: "",
                 location: "京承高速", address: nil, mood: nil, tags: [], pages: 1,
                 items: [("一类客车 · 单程", "45.00")]),

            Spec(type: .ticket, date: at(days: -8, hour: 10), amount: 60,
                 merchant: "故宫博物院", note: "门票",
                 location: "北京市东城区", address: "景山前街 4 号", mood: .calm, tags: ["旅行"], pages: 2,
                 items: [("成人票", "60.00")]),

            Spec(type: .receipt, date: at(days: -2, months: -1, hour: 20), amount: 89.9,
                 merchant: "盒马鲜生", note: "",
                 location: nil, address: nil, mood: nil, tags: [], pages: 1,
                 items: [("有机蔬菜", "32.80"), ("鲜牛奶", "19.90"), ("全麦面包", "37.20")]),

            // 纪念收藏（金额为空）：带地点 / 地址 / 心情 / 标签
            Spec(type: .train, date: at(days: -10, hour: 21), amount: 553,
                 merchant: "京沪高铁 G2", note: "北京南 → 上海虹桥",
                 location: "北京市西城区", address: "西长安街 2 号", mood: .moved, tags: ["演出", "话剧"], pages: 2,
                 items: [("一楼池座 8 排", "380.00")]),

            Spec(type: .ticket, date: at(years: -1, hour: 15), amount: nil,
                 merchant: "上海迪士尼乐园", note: "第一次去",
                 location: "上海市浦东新区", address: nil, mood: .excited, tags: ["旅行"], pages: 1,
                 items: [("一日标准票", "599.00")]),
        ]
    }

    static func seed(into store: ReceiptStore) {
        for spec in specs() {
            let pages = max(1, spec.pages)
            let images = (0..<pages).map { image(for: spec, page: $0) }
            _ = try? store.add(type: spec.type, date: spec.date, amount: spec.amount,
                           merchant: spec.merchant, note: spec.note, images: images,
                           location: spec.location, address: spec.address,
                           mood: spec.mood, tags: spec.tags)
        }
    }

    // MARK: - 画小票

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    private static func items(for spec: Spec, page: Int) -> [(String, String)] {
        guard page > 0 else { return spec.items }
        let extras: [[(String, String)]] = [
            [("加菜 · 虾滑", "42.00"), ("加菜 · 豆皮", "18.00"), ("服务费", "12.00")],
            [("餐具包", "2.00"), ("打包盒", "3.00")],
        ]
        return extras[(page - 1) % extras.count]
    }

    static func image(for spec: Spec, page: Int) -> UIImage {
        let size = CGSize(width: 620, height: 840)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let ink = UIColor(white: 0.16, alpha: 1)
            let faint = UIColor(white: 0.48, alpha: 1)
            let paper = UIColor(red: 0.995, green: 0.988, blue: 0.962, alpha: 1)
            paper.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let margin: CGFloat = 44
            let width = size.width - margin * 2
            var y: CGFloat = 46

            draw("小票收纳 · 示例票据", x: margin, y: y, width: width,
                 font: .systemFont(ofSize: 14, weight: .semibold), color: faint, alignment: .center)
            y += 30
            draw(spec.merchant, x: margin, y: y, width: width,
                 font: .systemFont(ofSize: 27, weight: .bold), color: ink, alignment: .center)
            y += 38
            draw(dateFormatter.string(from: spec.date), x: margin, y: y, width: width,
                 font: .systemFont(ofSize: 15, weight: .medium), color: faint, alignment: .center)
            y += 32

            dashedLine(from: margin, to: size.width - margin, y: y, color: faint.withAlphaComponent(0.55))
            y += 22

            draw("商品", x: margin, y: y, width: width * 0.62,
                 font: .systemFont(ofSize: 13, weight: .medium), color: faint, alignment: .left)
            draw("金额", x: margin + width * 0.62, y: y, width: width * 0.38,
                 font: .systemFont(ofSize: 13, weight: .medium), color: faint, alignment: .right)
            y += 28

            for (name, price) in items(for: spec, page: page) {
                draw(name, x: margin, y: y, width: width * 0.64,
                     font: .systemFont(ofSize: 17), color: ink, alignment: .left)
                draw(price, x: margin + width * 0.64, y: y, width: width * 0.36,
                     font: .systemFont(ofSize: 17), color: ink, alignment: .right)
                y += 33
            }

            y += 8
            dashedLine(from: margin, to: size.width - margin, y: y, color: faint.withAlphaComponent(0.55))
            y += 20

            let totalLabel = page == 0 ? "合计" : "第 \(page + 1) 页 小计"
            let total = spec.amount ?? spec.items.reduce(0) { $0 + (Double($1.1) ?? 0) }
            draw(totalLabel, x: margin, y: y, width: width * 0.5,
                 font: .systemFont(ofSize: 18, weight: .semibold), color: ink, alignment: .left)
            draw(String(format: "¥%.2f", total), x: margin + width * 0.5, y: y, width: width * 0.5,
                 font: .systemFont(ofSize: 24, weight: .bold), color: ink, alignment: .right)
            y += 52

            draw("感谢惠顾 · 请妥善保管", x: margin, y: y, width: width,
                 font: .systemFont(ofSize: 14), color: faint, alignment: .center)
            y += 34

            // 交易信息：真实小票都会有，顺便把单页留白填掉
            let orderNo = String(format: "%04d%02d%02d%03d", 2600, page + 1,
                                 abs(spec.merchant.hashValue) % 28 + 1,
                                 abs(spec.merchant.hashValue) % 900 + 100)
            let pieces = items(for: spec, page: page).count
            let meta: [(String, String)] = [
                ("商品件数", "\(pieces) 件"),
                ("支付方式", spec.amount == nil ? "留念收藏" : "微信支付"),
                ("订单号", orderNo),
                ("收银员", String(format: "%04d", abs(spec.merchant.hashValue) % 9000 + 1000)),
            ]
            for (key, value) in meta {
                draw(key, x: margin, y: y, width: width * 0.42,
                     font: .systemFont(ofSize: 14), color: faint, alignment: .left)
                draw(value, x: margin + width * 0.42, y: y, width: width * 0.58,
                     font: .systemFont(ofSize: 14), color: ink, alignment: .right)
                y += 27
            }

            barcode(context, in: CGRect(x: margin + 70, y: size.height - 108,
                                        width: width - 140, height: 36), seed: abs(spec.merchant.hashValue) + page)
            draw("MOCK-\(abs(spec.merchant.hashValue) % 90000 + 10000)", x: margin,
                 y: size.height - 62, width: width,
                 font: .systemFont(ofSize: 11), color: faint, alignment: .center)
        }
    }

    // MARK: - 绘制辅助

    private static func draw(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat,
                             font: UIFont, color: UIColor, alignment: NSTextAlignment) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        let rect = CGRect(x: x, y: y, width: width, height: font.lineHeight + 4)
        (text as NSString).draw(in: rect, withAttributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ])
    }

    private static func dashedLine(from x0: CGFloat, to x1: CGFloat, y: CGFloat, color: UIColor) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: x0, y: y))
        path.addLine(to: CGPoint(x: x1, y: y))
        path.setLineDash([6, 6], count: 2, phase: 0)
        path.lineWidth = 1.2
        color.setStroke()
        path.stroke()
    }

    private static func barcode(_ context: UIGraphicsImageRendererContext, in rect: CGRect, seed: Int) {
        UIColor(white: 0.12, alpha: 1).setFill()
        var x = rect.minX
        var state = UInt32(truncatingIfNeeded: seed) | 1
        while x < rect.maxX - 2 {
            state = state &* 1_103_515_245 &+ 12_345
            let barWidth = CGFloat(1 + Int(state % 4))
            let gap = CGFloat(1 + Int((state >> 5) % 3))
            guard x + barWidth <= rect.maxX else { break }
            context.fill(CGRect(x: x, y: rect.minY, width: barWidth, height: rect.height))
            x += barWidth + gap
        }
    }
}
