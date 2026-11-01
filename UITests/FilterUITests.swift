// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import XCTest

/// 顶部筛选条：按类型筛掉其它行，切回「全部」恢复。
final class FilterUITests: XCTestCase {
    func testTypeChipFiltersAndRestores() {
        let app = XCUIApplication()
        app.launchArguments += ["-seedSampleData"]
        app.launch()

        let hotpot = app.staticTexts["海底捞火锅（望京店）"]
        XCTAssertTrue(hotpot.waitForExistence(timeout: 15), "示例数据应包含海底捞")

        let flightChip = app.buttons["filter.type.小票"]
        XCTAssertTrue(flightChip.waitForExistence(timeout: 5), "筛选条应出现小票胶囊")
        flightChip.tap()

        XCTAssertFalse(hotpot.waitForExistence(timeout: 2), "筛选小票后不应再出现发票类记录")
        XCTAssertTrue(app.staticTexts["全家便利店"].waitForExistence(timeout: 3), "小票类记录应保留")

        app.buttons["filter.type.all"].tap()
        XCTAssertTrue(hotpot.waitForExistence(timeout: 3), "切回全部后应恢复")
    }
}
