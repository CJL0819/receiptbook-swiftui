// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import XCTest

/// 「我的 → 恢复默认数据」：确认后示例票据应重新出现。
final class RestoreDefaultsUITests: XCTestCase {
    func testRestoreDefaultsFromMeTab() {
        let app = XCUIApplication()
        app.launchArguments += ["-seedSampleData"]
        app.launch()

        XCTAssertTrue(app.staticTexts["全家便利店"].waitForExistence(timeout: 15))

        app.buttons["我的"].tap()
        let restore = app.buttons["me.restoreDefaults"]
        XCTAssertTrue(restore.waitForExistence(timeout: 5), "我的页应有「恢复默认数据」")
        restore.tap()

        let confirm = app.buttons["恢复"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "应弹出确认框")
        confirm.tap()

        app.buttons["记账"].tap()
        XCTAssertTrue(app.staticTexts["全家便利店"].waitForExistence(timeout: 5), "恢复后应重新出现示例票据")
    }
}
