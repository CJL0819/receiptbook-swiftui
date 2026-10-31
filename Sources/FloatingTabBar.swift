// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI

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
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
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
