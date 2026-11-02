// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI

/// 收藏馆：把无金额的纪念票据当成一个小画廊。
///
/// 结构很克制：大标题 + 一句概述 → 精选大图 → 心情筛选 → 按年份的图片网格。
/// 不做纸纹、印章、票根撕口这些装饰，颜色来自票据本身。
struct CollectionView: View {
    @EnvironmentObject private var store: ReceiptStore
    @EnvironmentObject private var appState: AppState

    /// 空状态里的按钮需要把添加页拉起来，由 RootView 注入。
    var onAdd: () -> Void = {}

    @State private var searchText = ""
    /// 本页自己的搜索态（不要和记账页共用，否则切 tab 会误入搜索）
    @State private var isSearching = false
    @State private var filter = CollectionFilter()
    @State private var showFilterSheet = false
    @State private var path = NavigationPath()
    @State private var heroSelection: String?
    @State private var scrollNonce = 0
    @State private var endNonce = 0
    @State private var pendingScrollAfterSheet = false
    @FocusState private var searchFocused: Bool

    private var catalog: CollectionCatalog {
        CollectionCatalog(receipts: store.receipts)
    }

    private var results: [CollectionEntry] {
        catalog.filtered(by: filter, search: isSearching ? searchText : "")
    }

    private var groups: [CollectionYearGroup] {
        catalog.groupedByYear(results)
    }

    private var featured: [CollectionEntry] {
        // 精选跟着筛选走，避免顶部出现与当前心情不一致的票
        catalog.featured(from: results)
    }

    /// 心情已经在吸顶索引里显示，不需要再出一条可移除的 token。
    private var showsFilterTokens: Bool {
        filter.year != nil || filter.type != nil || filter.tag != nil
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                CollectionColor.background.ignoresSafeArea()

                if isSearching {
                    searchPage
                        .transition(.opacity)
                } else {
                    browsePage
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .top) {
                CollectionStatusBarScrim()
            }
            .navigationDestination(for: CollectionRoute.self) { route in
                switch route {
                case .detail(let receipt):
                    CollectionDetailView(receipt: receipt)
                case .album(let tag):
                    CollectionAlbumView(tag: tag)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: isSearching ? 0 : FloatingTabMetrics.reservedHeight)
            }
            .sheet(isPresented: $showFilterSheet, onDismiss: {
                guard pendingScrollAfterSheet else { return }
                pendingScrollAfterSheet = false
                withAnimation(.snappy(duration: 0.32)) { scrollNonce += 1 }
            }) {
                CollectionFilterSheet(filter: $filter, catalog: catalog) {
                    pendingScrollAfterSheet = true
                }
            }
            .onChange(of: isSearching) { _, newValue in
                appState.isSearching = newValue
            }
            .onChange(of: filter) { _, _ in
                heroSelection = featured.first?.id
            }
            .onDisappear {
                isSearching = false
                searchFocused = false
                appState.isSearching = false
            }
            .task {
                #if DEBUG
                await handleDebugLaunchArguments()
                #endif
            }
        }
    }

    // MARK: - 浏览

    private var browsePage: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    header

                    if catalog.isEmpty {
                        CollectionEmptyState(kind: .empty, onAdd: onAdd)
                    } else {
                        if !featured.isEmpty {
                            CollectionFeaturedCarousel(entries: featured, selection: $heroSelection)
                                .padding(.top, 18)
                        }

                        Section {
                            catalogue
                        } header: {
                            CollectionMoodBar(moods: catalog.moods,
                                              total: catalog.count,
                                              selection: $filter.mood)
                                .id("catalogueTop")
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .onChange(of: scrollNonce) { _, _ in
                proxy.scrollTo("catalogueTop", anchor: .top)
            }
            .onChange(of: endNonce) { _, _ in
                proxy.scrollTo("colophon", anchor: .bottom)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("收藏")
                        .font(.system(size: 36, weight: .bold))
                        .tracking(-0.8)
                        .foregroundStyle(CollectionColor.ink)

                    Text(catalog.summary)
                        .font(.system(size: 13))
                        .foregroundStyle(CollectionColor.secondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                HStack(spacing: 0) {
                    CollectionIconButton(icon: "magnifyingglass",
                                         accessibilityText: "搜索收藏") {
                        beginSearch()
                    }
                    .accessibilityIdentifier("collection.search")

                    CollectionIconButton(icon: "slider.horizontal.3",
                                         isActive: filter.activeCount > 0,
                                         accessibilityText: "筛选") {
                        showFilterSheet = true
                    }
                    .accessibilityIdentifier("collection.filter")
                }
                .padding(.top, -4)
            }
            .padding(.horizontal, CollectionMetrics.gutter)
            .padding(.top, 10)

            if showsFilterTokens {
                CollectionActiveFilters(filter: $filter)
            }
        }
        .padding(.bottom, 2)
    }

    private var catalogue: some View {
        VStack(spacing: 0) {
            if results.isEmpty {
                CollectionEmptyState(kind: .noResults) {
                    withAnimation(.snappy(duration: 0.24)) { filter.reset() }
                }
            } else {
                ForEach(groups) { group in
                    VStack(spacing: 14) {
                        CollectionYearHeader(year: group.year, count: group.items.count)
                        CollectionGrid(entries: group.items)
                    }
                    .padding(.top, 28)
                }

                if !catalog.tags.isEmpty {
                    CollectionTagRow(tags: catalog.tags)
                        .padding(.top, 36)
                }

                CollectionFooter(count: results.count)
                    .id("colophon")
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: - 搜索

    private var searchPage: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                CollectionSearchField(text: $searchText, isFocused: $searchFocused)

                Button {
                    endSearch()
                } label: {
                    Text("取消")
                        .font(.system(size: 14))
                        .foregroundStyle(CollectionColor.ink)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("collection.searchCancel")
            }
            .padding(.horizontal, CollectionMetrics.gutter)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background(CollectionColor.background)
            .overlay(alignment: .bottom) { CollectionHairline() }

            ScrollView {
                searchBody
                    .padding(.top, 18)
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(220))
            searchFocused = true
        }
    }

    @ViewBuilder
    private var searchBody: some View {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            suggestions
        } else if results.isEmpty {
            CollectionEmptyState(kind: .noResults) {
                withAnimation(.snappy(duration: 0.2)) { searchText = "" }
            }
        } else {
            VStack(spacing: 0) {
                HStack {
                    Text("\(results.count) 件藏品")
                        .font(.system(size: 12))
                        .foregroundStyle(CollectionColor.secondary)
                    Spacer()
                }
                .padding(.horizontal, CollectionMetrics.gutter)

                CollectionGrid(entries: results)
                    .padding(.top, 14)

                CollectionFooter(count: results.count)
            }
        }
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("试试这些标签")
                .font(.system(size: 12))
                .foregroundStyle(CollectionColor.secondary)

            FlowLayout(spacing: 8) {
                ForEach(catalog.tags.prefix(8)) { item in
                    Button {
                        Haptics.selection()
                        withAnimation(.snappy(duration: 0.2)) { searchText = item.tag }
                    } label: {
                        CollectionTagPill(tag: item.tag)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("也可以搜商家、地点或备注里的字。")
                .font(.system(size: 12))
                .foregroundStyle(CollectionColor.tertiary)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, CollectionMetrics.gutter)
    }

    // MARK: - 动作

    private func beginSearch() {
        Haptics.selection()
        withAnimation(.snappy(duration: 0.24)) {
            isSearching = true
        }
        appState.isSearching = true
    }

    private func endSearch() {
        searchFocused = false
        withAnimation(.snappy(duration: 0.24)) {
            isSearching = false
        }
        searchText = ""
        appState.isSearching = false
    }

    #if DEBUG
    /// 截图 / 调试入口：`-openCollection` 落到收藏馆后，可再用下面的参数直达某个状态。
    /// - `-collectionSearch` / `-collectionFilter` / `-collectionGrid`
    /// - `-collectionEnd` / `-collectionDetail` / `-collectionAlbum`
    private func handleDebugLaunchArguments() async {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-collectionSearch") {
            try? await Task.sleep(for: .milliseconds(300))
            beginSearch()
            return
        }
        if arguments.contains("-collectionFilter") {
            try? await Task.sleep(for: .milliseconds(300))
            showFilterSheet = true
            return
        }
        if arguments.contains("-collectionFiltered") {
            try? await Task.sleep(for: .milliseconds(300))
            filter.year = 2026
            filter.mood = .excited
            heroSelection = featured.first?.id
            return
        }
        if arguments.contains("-collectionGrid") {
            try? await Task.sleep(for: .milliseconds(300))
            scrollNonce += 1
            return
        }
        if arguments.contains("-collectionEnd") {
            try? await Task.sleep(for: .milliseconds(300))
            endNonce += 1
            return
        }
        if arguments.contains("-collectionDetail"), let entry = catalog.featured.first {
            try? await Task.sleep(for: .milliseconds(300))
            path.append(CollectionRoute.detail(entry.receipt))
            return
        }
        if arguments.contains("-collectionAlbum"), let tag = catalog.tags.first?.tag {
            try? await Task.sleep(for: .milliseconds(300))
            path.append(CollectionRoute.album(tag))
        }
    }
    #endif
}
