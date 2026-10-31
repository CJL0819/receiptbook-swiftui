// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI

enum RootTab: Hashable {
    case expense, collection, travel, me
}

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("addReceiptStyle") private var style: AddReceiptStyle = .plain
    @State private var selection: RootTab = .expense
    @State private var showAddSheet = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selection) {
                NavigationStack {
                    ReceiptListView()
                }
                .toolbar(.hidden, for: .tabBar)
                .toolbarBackground(.hidden, for: .tabBar)
                .tag(RootTab.expense)

                CollectionView()
                    .toolbar(.hidden, for: .tabBar)
                    .toolbarBackground(.hidden, for: .tabBar)
                    .tag(RootTab.collection)

                TravelMapView(plan: .sample)
                    .toolbar(.hidden, for: .tabBar)
                    .toolbarBackground(.hidden, for: .tabBar)
                    .tag(RootTab.travel)

                MeView()
                    .toolbar(.hidden, for: .tabBar)
                    .toolbarBackground(.hidden, for: .tabBar)
                    .tag(RootTab.me)
            }

            if !appState.isSearching {
                FloatingTabBar(selection: $selection) {
                    showAddSheet = true
                }
                .padding(.horizontal, 26)
                .padding(.bottom, 4)
            }
        }
        .fullScreenCover(isPresented: $showAddSheet) {
            NavigationStack {
                addSheetContent
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

    @ViewBuilder
    private var addSheetContent: some View {
        switch style {
        case .plain: AddReceiptView()
        case .b: AddReceiptViewB()
        }
    }
}
