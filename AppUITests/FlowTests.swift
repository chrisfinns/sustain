import XCTest

/// End-to-end flows from the plan (the old Playwright list), run against a fresh in-memory store.
final class FlowTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        app.launch()
    }

    private func openCapture() -> XCUIElement {
        app.typeKey("k", modifierFlags: .command)
        let name = app.textFields["Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5), "Capture didn't open")
        return name
    }

    private func todayRow(_ title: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title + ",")).firstMatch
    }

    func testCaptureWithOnlyANameShowsAsNew() {
        let name = openCapture()
        name.typeText("Spider exercise\r")
        let row = todayRow("Spider exercise")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertEqual(row.label, "Spider exercise, New")
    }

    func testTypingANewAreaMakesADashedChipAndSavesWithTheItem() {
        let name = openCapture()
        name.typeText("Slap groove in E")
        let area = app.textFields["Type an area"]
        area.click()
        area.typeText("Slap\r")
        XCTAssertTrue(app.buttons["Slap · new"].waitForExistence(timeout: 3), "dashed chip missing")
        area.typeText("\r")
        XCTAssertTrue(todayRow("Slap groove in E").waitForExistence(timeout: 5))
        app.typeKey("2", modifierFlags: .command)
        XCTAssertTrue(app.staticTexts["Slap"].waitForExistence(timeout: 5), "Library should show the new area")
    }

    func testEscapeTwiceCreatesNoArea() {
        let name = openCapture()
        name.typeText("Nothing")
        let area = app.textFields["Type an area"]
        area.click()
        area.typeText("Ghost")
        area.typeKey(.escape, modifierFlags: [])
        area.typeKey(.escape, modifierFlags: [])
        XCTAssertFalse(app.textFields["Name"].waitForExistence(timeout: 1), "Capture should close")
        app.typeKey(",", modifierFlags: .command)
        XCTAssertFalse(app.buttons["Rename Ghost"].exists)
    }

    func testShiftEnterKeepsCaptureOpenForTheNextOne() {
        let name = openCapture()
        name.typeText("Riff one")
        name.typeKey(.return, modifierFlags: .shift)
        XCTAssertTrue(name.waitForExistence(timeout: 2))
        XCTAssertEqual(name.value as? String ?? "", "")
        name.typeText("Riff two\r")
        XCTAssertTrue(todayRow("Riff one").waitForExistence(timeout: 5))
        XCTAssertTrue(todayRow("Riff two").exists)
    }

    func testPressingThreeRatesGoodAndMovesToDoneToday() {
        let name = openCapture()
        name.typeText("Minor pentatonic\r")
        let row = todayRow("Minor pentatonic")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.click()
        XCTAssertTrue(app.buttons["End session"].waitForExistence(timeout: 5))
        app.typeKey("3", modifierFlags: [])
        XCTAssertTrue(app.staticTexts["Good"].waitForExistence(timeout: 5), "Done today should show the rating")
        XCTAssertTrue(app.buttons["Re-rate"].exists)
    }

    func testDeletingAUsedAreaKeepsTheItemAndUndoRestoresIt() {
        let name = openCapture()
        name.typeText("Walking line")
        let area = app.textFields["Type an area"]
        area.click()
        area.typeText("Grooves\r")
        name.click()
        name.typeText("\r")
        XCTAssertTrue(todayRow("Walking line").waitForExistence(timeout: 5))
        app.typeKey(",", modifierFlags: .command)
        let trash = app.buttons["Delete Grooves"]
        XCTAssertTrue(trash.waitForExistence(timeout: 5))
        trash.click()
        let undo = app.buttons["Undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 3))
        undo.click()
        XCTAssertTrue(app.buttons["Rename Grooves"].waitForExistence(timeout: 3))
        app.typeKey("1", modifierFlags: .command)
        XCTAssertTrue(todayRow("Walking line").waitForExistence(timeout: 5))
    }
}
