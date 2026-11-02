// SPDX-License-Identifier: MIT
// Copyright (c) 2026
import XCTest

/// 收藏馆的两条关键链路：
/// 1) 详情页收起悬浮 Tab 栏，返回目录后恢复；
/// 2) 筛选 sheet 选年份并应用，列表只留下该年份。
final class CollectionUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testDetailHidesAndRestoresFloatingTabBar() {
        let app = XCUIApplication()
        app.launchArguments = ["-seedSampleData", "-openCollection", "-collectionDetail"]
        app.launch()

        let back = app.buttons["返回"].firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 30), "收藏详情应自动打开")

        sleep(1)
        XCTAssertFalse(app.buttons["记账"].exists, "详情页应收起悬浮 Tab 栏")

        back.tap()
        XCTAssertTrue(app.buttons["记账"].waitForExistence(timeout: 6), "回到目录后 Tab 栏应恢复")
    }

    func testFilterSheetKeepsOnlyChosenYear() {
        let app = XCUIApplication()
        app.launchArguments = ["-seedSampleData", "-openCollection"]
        app.launch()

        let filterButton = app.buttons["collection.filter"]
        XCTAssertTrue(filterButton.waitForExistence(timeout: 25), "收藏页应有筛选入口")
        filterButton.tap()

        let year2023 = app.buttons["collection.filter.year.2023"]
        XCTAssertTrue(year2023.waitForExistence(timeout: 5), "筛选页应列出 2023")
        year2023.tap()

        let apply = app.buttons["collection.filter.apply"]
        XCTAssertTrue(apply.waitForExistence(timeout: 3), "应有应用按钮")
        apply.tap()

        XCTAssertTrue(app.staticTexts["拙政园"].firstMatch.waitForExistence(timeout: 6),
                      "筛选 2023 后应看到当年的藏品")
        XCTAssertFalse(app.staticTexts["JR 嵯峨野线"].firstMatch.waitForExistence(timeout: 2),
                       "2023 以外的藏品不应出现")
    }
}
