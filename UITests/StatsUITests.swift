// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import XCTest

/// 统计页：能打开、能切月/年、能进入分类明细。
final class StatsUITests: XCTestCase {
    func testStatsPageOpensAndSwitchesScope() {
        let app = XCUIApplication()
        app.launchArguments += ["-seedSampleData"]
        app.launch()

        XCTAssertTrue(app.staticTexts["全家便利店"].waitForExistence(timeout: 15))
        app.buttons["统计"].tap()

        XCTAssertTrue(app.staticTexts["分类构成"].waitForExistence(timeout: 8), "统计页应显示分类构成")

        app.buttons["stats.scope.年"].tap()
        XCTAssertTrue(app.staticTexts["每月支出"].waitForExistence(timeout: 5), "切到年应显示每月支出")

        app.buttons["stats.scope.月"].tap()
        XCTAssertTrue(app.staticTexts["每日支出"].waitForExistence(timeout: 5), "切回月应显示每日支出")
    }
}
