// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack {
                ReceiptListView()
            }
            .tabItem { Label("记账", systemImage: "book.closed") }

            CollectionView()
                .tabItem { Label("收藏", systemImage: "bookmark.fill") }

            NavigationStack {
                AddReceiptView()
            }
            .tabItem { Label("扫描", systemImage: "camera.viewfinder") }

            StatsView()
                .tabItem { Label("统计", systemImage: "chart.bar") }
        }
    }
}
