// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import SwiftUI

@main
struct ReceiptBookApp: App {
    @StateObject private var store = ReceiptStore.shared
    @StateObject private var appState = AppState()

    init() {
        SampleDataBootstrap.prepare()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(appState)
        }
    }
}
