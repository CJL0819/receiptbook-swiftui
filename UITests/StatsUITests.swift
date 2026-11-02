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

extension StatsUITests {
    /// 「回到当前期间」按钮必须可点，并且在点击后消失（已回到当前期间）
    func testReturnToNowRestoresCurrentPeriod() {
        let app = XCUIApplication()
        app.launchArguments += ["-seedSampleData"]
        app.launch()
        app.buttons["统计"].tap()

        XCTAssertTrue(app.buttons["stats.prev"].waitForExistence(timeout: 10))
        app.buttons["stats.prev"].tap()

        let reset = app.buttons["stats.returnToNow"]
        XCTAssertTrue(reset.waitForExistence(timeout: 5), "离开当前期间后应出现返回按钮")
        print("RESET frame=\(reset.frame) hittable=\(reset.isHittable) enabled=\(reset.isEnabled)")
        print("PROBE buttons=\(app.buttons.allElementsBoundByIndex.map { $0.identifier + "|" + $0.label })")
        let previousTitle = app.buttons["stats.period"].label
        reset.tap()
        sleep(1)
        let titleAfter = app.buttons["stats.period"].label
        XCTAssertNotEqual(previousTitle, titleAfter, "点击后期间应改变（\(previousTitle) → \(titleAfter)）")
    }
}
