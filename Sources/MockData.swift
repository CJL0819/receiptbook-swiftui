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
                 location: "上海", address: "浦东新区川沙新镇", mood: .excited, tags: ["旅行"], pages: 1,
                 items: [("一日标准票", "599.00")]),

            // —— 更多纪念收藏：收藏馆需要足够的内容，才看得出编目、专题与年份的层次 ——

            Spec(type: .ticket, date: at(days: -18, hour: 19), amount: nil,
                 merchant: "阿那亚戏剧节", note: "海边剧场，风很大",
                 location: "秦皇岛", address: "阿那亚 · 黄金海岸", mood: .excited, tags: ["演出", "旅行"], pages: 1,
                 items: [("《海边的卡夫卡》", "280.00"), ("场刊", "40.00")]),

            Spec(type: .train, date: at(days: -9, hour: 21), amount: nil,
                 merchant: "JR 嵯峨野线", note: "岚山 到 京都",
                 location: "京都", address: "嵯峨野观光铁道", mood: .calm, tags: ["旅行", "铁道"], pages: 1,
                 items: [("乘车券", "240.00")]),

            Spec(type: .ticket, date: at(months: -3, hour: 10), amount: nil,
                 merchant: "清水寺", note: "夏天的清水舞台",
                 location: "京都", address: "京都府京都市东山区", mood: .calm, tags: ["旅行", "古寺"], pages: 2,
                 items: [("拝観料", "400.00"), ("御守", "800.00")]),

            Spec(type: .ticket, date: at(days: -6, months: -4, hour: 19), amount: nil,
                 merchant: "国家大剧院", note: "《玩偶之家》池座",
                 location: "北京", address: "西城区西长安街 2 号", mood: .moved, tags: ["演出", "话剧"], pages: 1,
                 items: [("一楼池座 8 排", "380.00")]),

            Spec(type: .ticket, date: at(months: -6, hour: 14), amount: nil,
                 merchant: "中国美术学院毕业展", note: "象山校区，逛了一下午",
                 location: "杭州", address: "西湖区转塘", mood: .happy, tags: ["展览", "旅行"], pages: 1,
                 items: [("毕业展通票", "30.00")]),

            Spec(type: .flight, date: at(months: -2, years: -1, hour: 8), amount: nil,
                 merchant: "上海航空 FM815", note: "上海 到 东京",
                 location: "上海", address: "浦东机场 T1", mood: .excited, tags: ["旅行", "飞行"], pages: 1,
                 items: [("经济舱", "1980.00"), ("机建燃油附加", "120.00")]),

            Spec(type: .ticket, date: at(months: -10, hour: 15), amount: nil,
                 merchant: "哈尔滨冰雪大世界", note: "零下二十六度",
                 location: "哈尔滨", address: nil, mood: .excited, tags: ["旅行", "冰雪"], pages: 2,
                 items: [("成人票", "328.00")]),

            Spec(type: .ticket, date: at(months: -13, hour: 11), amount: nil,
                 merchant: "成都大熊猫繁育研究基地", note: "早上七点排队",
                 location: "成都", address: "成华区熊猫大道", mood: .happy, tags: ["旅行", "动物"], pages: 1,
                 items: [("门票", "55.00")]),

            Spec(type: .ticket, date: at(months: -17, hour: 16), amount: nil,
                 merchant: "草莓音乐节", note: "痛仰压轴",
                 location: "北京", address: "温榆河公园", mood: .excited, tags: ["音乐节", "演出"], pages: 1,
                 items: [("单日票", "480.00")]),

            Spec(type: .ticket, date: at(months: -27, hour: 9), amount: nil,
                 merchant: "鼓浪屿", note: "轮渡上看见海",
                 location: "厦门", address: "思明区鼓浪屿", mood: .calm, tags: ["旅行", "海岛"], pages: 1,
                 items: [("往返船票", "70.00")]),

            Spec(type: .ticket, date: at(months: -1, years: -3, hour: 10), amount: nil,
                 merchant: "拙政园", note: "雨天，园子很安静",
                 location: "苏州", address: "姑苏区东北街 178 号", mood: .moved, tags: ["旅行", "园林"], pages: 2,
                 items: [("门票", "80.00")]),

            Spec(type: .receipt, date: at(months: -8, hour: 20), amount: nil,
                 merchant: "老吉士酒家", note: "红烧肉和油爆虾",
                 location: "上海", address: "天平路 41 号", mood: .happy, tags: ["美食", "旅行"], pages: 1,
                 items: [("红烧肉", "58.00"), ("油爆虾", "88.00"), ("酒酿圆子", "28.00")]),
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
        // 纪念收藏里的门票 / 车票 / 机票画成有设计感的票根，
        // 让收藏馆在浅色页面上有真正的颜色，而不是一片白纸。
        if spec.amount == nil, spec.type == .ticket || spec.type == .train || spec.type == .flight {
            return ticketImage(for: spec, page: page)
        }
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

    // MARK: - 画纪念票根

    private static let ticketPalettes: [(UInt32, UInt32)] = [
        (0x1F3B33, 0x101E1A),   // 墨绿
        (0x2C2F4C, 0x15172B),   // 靛蓝
        (0x3C2C37, 0x1E161B),   // 梅子
        (0x303539, 0x181C1F),   // 石墨
        (0x3B3327, 0x1F1A12),   // 栗棕
    ]

    private static func ticketImage(for spec: Spec, page: Int) -> UIImage {
        let size = CGSize(width: 620, height: 840)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            let seed = stableHash(spec.merchant)
            let palette = ticketPalettes[seed % ticketPalettes.count]
            let top = color(hex: palette.0)
            let bottom = color(hex: palette.1)
            let space = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: space,
                                      colors: [top.cgColor, bottom.cgColor] as CFArray,
                                      locations: [0, 1])!
            cg.drawLinearGradient(gradient,
                                  start: .zero,
                                  end: CGPoint(x: 0, y: size.height),
                                  options: [])

            let glow = CGGradient(colorsSpace: space,
                                  colors: [UIColor.white.withAlphaComponent(0.10).cgColor,
                                           UIColor.clear.cgColor] as CFArray,
                                  locations: [0, 1])!
            cg.drawRadialGradient(glow,
                                  startCenter: CGPoint(x: 150, y: 40), startRadius: 0,
                                  endCenter: CGPoint(x: 150, y: 40), endRadius: 460,
                                  options: [])

            let white = UIColor.white
            let faint = white.withAlphaComponent(0.62)
            let line = white.withAlphaComponent(0.22)

            let year = Calendar.current.component(.year, from: spec.date)
            drawTracking("\(year)", x: 210, y: 438, width: 350,
                         font: .systemFont(ofSize: 118, weight: .bold),
                         color: white.withAlphaComponent(0.05),
                         kern: -2, alignment: .right)

            let frame = UIBezierPath(roundedRect: CGRect(x: 26, y: 26, width: 568, height: 788),
                                     cornerRadius: 3)
            frame.lineWidth = 0.8
            line.setStroke()
            frame.stroke()

            drawTracking(typeLabel(for: spec.type), x: 48, y: 56, width: 300,
                         font: .systemFont(ofSize: 11, weight: .semibold),
                         color: faint, kern: 3)
            drawTracking("纪念收藏", x: 348, y: 56, width: 224,
                         font: .systemFont(ofSize: 11),
                         color: white.withAlphaComponent(0.42),
                         kern: 1.6, alignment: .right)

            drawWrapped(spec.merchant,
                        in: CGRect(x: 48, y: 96, width: 520, height: 132),
                        font: .systemFont(ofSize: 46, weight: .bold),
                        color: white, lineHeight: 56, maxLines: 2)

            if !spec.note.isEmpty {
                drawWrapped(spec.note,
                            in: CGRect(x: 48, y: 242, width: 460, height: 30),
                            font: .systemFont(ofSize: 20),
                            color: faint, lineHeight: 26, maxLines: 1)
            }

            let dateString = String(dateFormatter.string(from: spec.date).prefix(10))
            drawTracking(dateString, x: 48, y: 304, width: 240,
                         font: .systemFont(ofSize: 23, weight: .semibold),
                         color: white.withAlphaComponent(0.92), kern: 0.8)

            var placeParts: [String] = []
            if let location = spec.location { placeParts.append(location) }
            if let address = spec.address, address != spec.location { placeParts.append(address) }
            if !placeParts.isEmpty {
                drawWrapped(placeParts.joined(separator: " · "),
                            in: CGRect(x: 48, y: 342, width: 480, height: 26),
                            font: .systemFont(ofSize: 14),
                            color: faint, lineHeight: 20, maxLines: 1)
            }

            let rule = UIBezierPath()
            rule.move(to: CGPoint(x: 48, y: 400))
            rule.addLine(to: CGPoint(x: 572, y: 400))
            rule.lineWidth = 0.8
            line.setStroke()
            rule.stroke()

            drawTracking("ITEM", x: 48, y: 428, width: 100,
                         font: .systemFont(ofSize: 9, weight: .semibold),
                         color: white.withAlphaComponent(0.38), kern: 1.8)
            drawWrapped(spec.items.first?.0 ?? "",
                        in: CGRect(x: 48, y: 450, width: 400, height: 30),
                        font: .systemFont(ofSize: 17),
                        color: white.withAlphaComponent(0.9), lineHeight: 22, maxLines: 1)

            if spec.items.count > 1 {
                drawTracking("NOTE", x: 48, y: 496, width: 100,
                             font: .systemFont(ofSize: 9, weight: .semibold),
                             color: white.withAlphaComponent(0.38), kern: 1.8)
                drawWrapped(spec.items[1].0,
                            in: CGRect(x: 48, y: 518, width: 400, height: 28),
                            font: .systemFont(ofSize: 17),
                            color: white.withAlphaComponent(0.9), lineHeight: 22, maxLines: 1)
            }

            dashedLine(from: 48, to: 572, y: 602, color: white.withAlphaComponent(0.3))

            drawTracking("ADMIT ONE", x: 48, y: 630, width: 220,
                         font: .systemFont(ofSize: 10, weight: .semibold),
                         color: faint, kern: 3)
            let serial = String(format: "NO. %03d", seed % 900 + 100)
            drawTracking(serial, x: 348, y: 630, width: 224,
                         font: .systemFont(ofSize: 10),
                         color: white.withAlphaComponent(0.45),
                         kern: 1.4, alignment: .right)

            barcode(context,
                    in: CGRect(x: 48, y: 690, width: 524, height: 44),
                    seed: seed + page,
                    color: white.withAlphaComponent(0.82))
            drawTracking("MOCK-\(seed % 90000 + 10000)",
                         x: 48, y: 748, width: 524,
                         font: .systemFont(ofSize: 10),
                         color: white.withAlphaComponent(0.38),
                         kern: 1.2, alignment: .center)
        }
    }

    /// 稳定哈希：Swift 的 hashValue 每次启动都会加盐，票根颜色和编号不能跟着变。
    private static func stableHash(_ text: String) -> Int {
        var hash: UInt64 = 5381
        for byte in text.utf8 {
            hash = (hash &* 33) ^ UInt64(byte)
        }
        return Int(hash % UInt64(Int.max))
    }

    private static func color(hex: UInt32) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1)
    }

    private static func typeLabel(for type: ReceiptType) -> String {
        switch type {
        case .ticket: return "ADMISSION"
        case .train: return "RAIL"
        case .flight: return "BOARDING PASS"
        case .receipt: return "RECEIPT"
        case .invoice: return "INVOICE"
        case .toll: return "TOLL"
        case .other: return "MEMORABILIA"
        }
    }

    private static func drawWrapped(_ text: String, in rect: CGRect,
                                    font: UIFont, color: UIColor,
                                    lineHeight: CGFloat, maxLines: Int,
                                    alignment: NSTextAlignment = .left) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        paragraph.minimumLineHeight = lineHeight
        paragraph.maximumLineHeight = lineHeight
        let attributed = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ])
        attributed.draw(with: rect,
                        options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                        context: nil)
    }

    private static func drawTracking(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat,
                                     font: UIFont, color: UIColor, kern: CGFloat,
                                     alignment: NSTextAlignment = .left) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        let attributed = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color,
            .kern: kern,
            .paragraphStyle: paragraph,
        ])
        attributed.draw(in: CGRect(x: x, y: y, width: width, height: font.lineHeight + 8))
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

    private static func barcode(_ context: UIGraphicsImageRendererContext, in rect: CGRect, seed: Int,
                                color: UIColor = UIColor(white: 0.12, alpha: 1)) {
        color.setFill()
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
