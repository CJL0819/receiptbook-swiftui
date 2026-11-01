import XCTest

/// 覆盖「左滑 → 点删除 → 点撤销」这条最容易出问题的交互链路。
final class DeleteUndoUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testSwipeRevealsDeleteThenUndoRestoresRow() {
        let app = XCUIApplication()
        app.launchArguments = ["-seedSampleData"]
        app.launch()

        let row = app.staticTexts["全家便利店"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 20), "列表应显示示例票据")

        // 左滑露出删除按钮（不再支持滑到底直接删）
        row.swipeLeft()

        let deleteButton = app.buttons["删除"].firstMatch
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "左滑后应露出删除按钮")
        deleteButton.tap()

        let undoButton = app.buttons["撤销"].firstMatch
        XCTAssertTrue(undoButton.waitForExistence(timeout: 8), "删除后应出现撤销条")
        undoButton.tap()

        XCTAssertTrue(app.staticTexts["全家便利店"].firstMatch.waitForExistence(timeout: 8),
                      "撤销后该行应恢复")
    }
}

/// 进入编辑态时卡片布局必须保持一致，不能出现位移/抖动。
final class EditModeLayoutUITests: XCTestCase {
    func testEditModeKeepsRowLayoutStable() {
        let app = XCUIApplication()
        app.launchArguments = ["-seedSampleData"]
        app.launch()

        let title = app.staticTexts["全家便利店"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 20), "列表应显示示例票据")
        let before = title.frame

        app.buttons["编辑"].tap()
        sleep(2)

        let after = app.staticTexts["全家便利店"].firstMatch.frame
        // 编辑态会有 ±0.55° 的摇摆（卡片中心旋转，左右两端纵向位移约 1pt），
        // 因此横向要求严格、纵向留一点余量。
        XCTAssertEqual(before.minX, after.minX, accuracy: 0.5, "进入编辑态时标题不应横向漂移")
        XCTAssertEqual(before.minY, after.minY, accuracy: 2.0, "进入编辑态时标题不应纵向漂移")
    }
}
