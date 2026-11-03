// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI

/// 跨视图共享的 UI 状态。
final class AppState: ObservableObject {
    @Published var isSearching = false
    /// 收藏馆的详情 / 专题页需要沉浸阅读，暂时收起悬浮 Tab 栏。
    @Published var hidesTabBar = false

    /// 子页面（统计、详情等）入栈时登记一个令牌，出栈时注销。
    /// 用令牌而不是布尔：重复 onAppear 不会把计数加错，多级压栈也不会提前恢复。
    @Published private(set) var subPageTokens = Set<UUID>()

    var hidesTabBarForSubPage: Bool { !subPageTokens.isEmpty }

    func pushSubPage(_ token: UUID) { subPageTokens.insert(token) }
    func popSubPage(_ token: UUID) { subPageTokens.remove(token) }
}

/// 添加票据页的布局样式（开发者模式切换）。
enum AddReceiptStyle: String, CaseIterable, Identifiable {
    case plain = "标准表单"
    case b = "拍照优先（B）"
    var id: String { rawValue }
}
