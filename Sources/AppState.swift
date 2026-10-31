// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI

/// 跨视图共享的 UI 状态。
final class AppState: ObservableObject {
    @Published var isSearching = false
}

/// 添加票据页的布局样式（开发者模式切换）。
enum AddReceiptStyle: String, CaseIterable, Identifiable {
    case plain = "标准表单"
    case b = "拍照优先（B）"
    var id: String { rawValue }
}
