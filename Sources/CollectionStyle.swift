// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI
import UIKit

// MARK: - 设计语言

/// 收藏馆：克制的现代画廊。
///
/// - 底色是中性近白，不铺米色/纸纹；
/// - 文字只有黑白灰三级，强调靠字重与留白；
/// - 圆角只用于图片容器（18 / 14），不再给每个元素套框；
/// - 颜色全部来自票据照片本身，界面不额外加红、金、印章。
enum CollectionMetrics {
    static let gutter: CGFloat = 20
    static let cardRadius: CGFloat = 18
    static let imageRadius: CGFloat = 14
}

enum CollectionColor {
    static let background = dynamic(light: 0xF6F6F4, dark: 0x0F0F10)
    static let surface = dynamic(light: 0xFFFFFF, dark: 0x1A1A1C)
    static let fill = dynamic(light: 0xF0F0ED, dark: 0x262628)
    static let ink = dynamic(light: 0x111111, dark: 0xF3F3F1)
    static let secondary = dynamic(light: 0x8A8A86, dark: 0x9B9B98)
    static let tertiary = dynamic(light: 0xB6B6B1, dark: 0x6B6B69)
    static let hairline = dynamic(light: 0xE9E9E5, dark: 0x2B2B2D)

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light)
        })
    }
}

extension UIColor {
    fileprivate convenience init(rgb: UInt32) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255,
                  green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255,
                  alpha: 1)
    }
}

enum CollectionDate {
    static let dotted: DateFormatter = formatter("yyyy.MM.dd")
    static let full: DateFormatter = formatter("yyyy年M月d日")
    static let year: DateFormatter = formatter("yyyy")

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = format
        return formatter
    }
}

// MARK: - 基础零件

struct CollectionHairline: View {
    var color: Color = CollectionColor.hairline
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: 0.6)
    }
}

/// 状态栏遮罩：收藏馆没有系统导航栏，滚动时别让内容穿到时间后面。
struct CollectionStatusBarScrim: View {
    private var topInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .safeAreaInsets.top ?? 0
    }

    var body: some View {
        CollectionColor.background
            .frame(height: topInset + 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
    }
}

/// 轻按压反馈：只缩一点点。
struct CollectionPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// 顶栏图标按钮：无底色、44pt 点击区，右侧可带一个小圆点表示筛选已生效。
struct CollectionIconButton: View {
    let icon: String
    var isActive: Bool = false
    var accessibilityText: String = ""
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(CollectionColor.ink)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .overlay(alignment: .topTrailing) {
                    if isActive {
                        Circle()
                            .fill(CollectionColor.ink)
                            .frame(width: 6, height: 6)
                            .padding(.top, 10)
                            .padding(.trailing, 10)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText.isEmpty ? icon : accessibilityText)
    }
}

/// 筛选 / 编目用的胶囊：选中时反白，未选中是浅灰底。
struct CollectionPill: View {
    let title: String
    var count: Int?
    var selected: Bool = false
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: selected ? .semibold : .medium))
                if let count {
                    Text("\(count)")
                        .font(.system(size: 11))
                        .opacity(selected ? 0.6 : 0.75)
                }
            }
            .foregroundStyle(selected ? CollectionColor.background : CollectionColor.ink)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background {
                Capsule(style: .continuous)
                    .fill(selected ? CollectionColor.ink : CollectionColor.fill)
            }
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// 标签胶囊（只作为展示 / 导航入口，不参与筛选）。
struct CollectionTagPill: View {
    let tag: String
    var count: Int?

    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(CollectionColor.ink)
            if let count {
                Text("\(count)")
                    .font(.system(size: 10.5))
                    .foregroundStyle(CollectionColor.secondary)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background(CollectionColor.fill, in: Capsule(style: .continuous))
        .contentShape(Capsule(style: .continuous))
    }
}

// MARK: - Mood 文案

extension Mood {
    /// "😄 开心" → "开心"
    var label: String {
        let parts = rawValue.split(separator: " ", maxSplits: 1)
        return parts.count > 1 ? String(parts[1]) : rawValue
    }
}
