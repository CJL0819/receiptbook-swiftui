// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI

/// 跨视图共享的 UI 状态。
final class AppState: ObservableObject {
    @Published var isSearching = false
}
