// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI

enum RootTab: Hashable {
    case expense, collection, travel, me
}

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var bursts = BurstCenter.shared
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
                // 底边留白从 38pt 收到 19pt（下沉一半），更贴近底边但不盖住 Home 指示条
                .padding(.bottom, -15)
            }
        }
        .onChange(of: selection) { _, _ in
            // 切 tab 一律退出搜索态，避免新页面继承上一个页面的搜索状态
            appState.isSearching = false
        }
        .overlay {
            particleLayer
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

    /// 全屏粒子层：用屏幕尺寸而不是 GeometryReader 的测量值 ——
    /// overlay 首次布局时可能量到 0，SpriteKit 场景会被建成 0×0 而什么都画不出来。
    private var particleLayer: some View {
        let canvas = UIScreen.main.bounds.size
        return ZStack(alignment: .topLeading) {
            ForEach(bursts.bursts) { burst in
                ParticleDissolve(image: burst.image,
                                 cardRect: burst.frame,
                                 canvas: canvas) {
                    bursts.remove(burst.id)
                }
            }
        }
        .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var addSheetContent: some View {
        switch style {
        case .plain: AddReceiptView()
        case .b: AddReceiptViewB()
        }
    }
}
