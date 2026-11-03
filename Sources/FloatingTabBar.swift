// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI

/// 悬浮胶囊 Tab 栏相关布局常量。
enum FloatingTabMetrics {
    /// 悬浮栏下沉后，顶边距屏幕底部约 77pt，再留一点呼吸空间。
    static let reservedHeight: CGFloat = 72
}

/// 悬浮胶囊 Tab 栏：记账 / 收藏 / [+] / 旅行 / 我的
struct FloatingTabBar: View {
    @Binding var selection: RootTab
    var onAdd: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.expense, "记账", "book.closed")
            tabButton(.collection, "收藏", "bookmark.fill")

            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.accentColor, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)

            tabButton(.travel, "旅行", "map.fill")
            tabButton(.me, "我的", "person.fill")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        // 不用毛玻璃：这条栏常驻在列表上方，列表每滚一帧都要重新采样背景模糊，
        // 是 120Hz 下最贵的一笔开销。改成 96% 不透明的自适应底色，观感几乎一致。
        .background {
            Capsule()
                .fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.96))
                .shadow(color: .black.opacity(0.13), radius: 11, y: 5)
        }
    }

    private func tabButton(_ tab: RootTab, _ title: String, _ icon: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selection = tab
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .medium))
                Text(title)
                    .font(.system(size: 10))
            }
            .foregroundStyle(selection == tab ? Color.accentColor : .secondary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
