// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import XCTest

/// 搜索态不能「串」到别的 tab：进入搜索 → 取消 → 切 tab，不应自动弹搜索。
final class SearchStateUITests: XCTestCase {
    func testCancelSearchThenSwitchTabStaysOutOfSearch() {
        let app = XCUIApplication()
        app.launchArguments += ["-seedSampleData"]
        app.launch()

        XCTAssertTrue(app.staticTexts["全家便利店"].waitForExistence(timeout: 15), "示例数据应已灌入")

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "应能看到搜索框")
        searchField.tap()

        let cancel = app.buttons["取消"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "进入搜索后应出现取消按钮")
        cancel.tap()

        app.buttons["收藏"].tap()
        sleep(2)

        XCTAssertFalse(app.buttons["取消"].exists, "切到收藏后不应自动进入搜索状态")

        app.buttons["记账"].tap()
        sleep(1)
        XCTAssertFalse(app.buttons["取消"].exists, "切回记账后也不应处于搜索状态")
    }
}
