// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI

@main
struct ReceiptBookApp: App {
    @StateObject private var store = ReceiptStore.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}
