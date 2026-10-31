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
                .tag(RootTab.expense)

                CollectionView()
                    .tag(RootTab.collection)

                TravelMapView(plan: .sample)
                    .tag(RootTab.travel)

                MeView()
                    .tag(RootTab.me)
            }
            .toolbar(.hidden, for: .tabBar)
            .toolbarBackground(.hidden, for: .tabBar)

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
        case .c: AddReceiptViewC()
        }
    }
}
