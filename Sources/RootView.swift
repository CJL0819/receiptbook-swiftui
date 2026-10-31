// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI

enum RootTab: Hashable {
    case expense, collection, stats, travel
}

struct RootView: View {
    @State private var selection: RootTab = .expense
    @State private var showAddSheet = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selection) {
                NavigationStack {
                    ReceiptListView()
                }
                .tabItem { Label("记账", systemImage: "book.closed") }
                .tag(RootTab.expense)

                CollectionView()
                    .tabItem { Label("收藏", systemImage: "bookmark.fill") }
                    .tag(RootTab.collection)

                StatsView()
                    .tabItem { Label("统计", systemImage: "chart.bar") }
                    .tag(RootTab.stats)

                TravelMapView(plan: .sample)
                    .tabItem { Label("旅行", systemImage: "map.fill") }
                    .tag(RootTab.travel)
            }

            // 悬浮「+」：扫码/添加票据（旅行页不显示）
            if selection != .travel {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.accentColor, in: Circle())
                        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 84)
            }
        }
        .fullScreenCover(isPresented: $showAddSheet) {
            NavigationStack {
                AddReceiptView()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("取消") {
                                showAddSheet = false
                            }
                        }
                    }
            }
        }
    }
}
