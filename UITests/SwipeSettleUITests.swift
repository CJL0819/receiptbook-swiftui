// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import XCTest

/// 左滑松手后必须吸附到「完全闭合」或「完全展开」，不能停在中间。
final class SwipeSettleUITests: XCTestCase {
    func testSwipeAlwaysSettlesToClosedOrOpen() {
        let app = XCUIApplication()
        app.launchArguments += ["-seedSampleData"]
        app.launch()

        let cell = app.staticTexts["海底捞火锅（望京店）"]
        XCTAssertTrue(cell.waitForExistence(timeout: 15))
        let before = cell.frame.minX

        // 短距离横向拖动（约 44pt），松手后应吸附，而不是停半路
        let start = cell.coordinate(withNormalizedOffset: CGVector(dx: 0.62, dy: 0.5))
        let end = cell.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
        sleep(1)

        let delta = before - cell.frame.minX
        let closed = abs(delta) < 1.5
        let opened = abs(delta - 102) < 4
        XCTAssertTrue(closed || opened, "松手后应吸附到闭合或展开，实际位移 \(delta)")
    }
}
