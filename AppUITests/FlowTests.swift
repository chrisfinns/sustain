import AppKit
import XCTest

/// End-to-end flows from the plan (the old Playwright list), run against a fresh in-memory store.
final class FlowTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch() {
        app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        app.launch()
    }

    /// Opens Capture with ⌘K and waits for the Name field to have keyboard focus.
    @MainActor
    private func openCapture() -> XCUIElement {
        app.typeKey("k", modifierFlags: .command)
        let name = app.textFields["Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5), "Capture didn't open")
        let focused = NSPredicate(format: "hasKeyboardFocus == true")
        let wait = expectation(for: focused, evaluatedWith: name)
        XCTAssertEqual(XCTWaiter.wait(for: [wait], timeout: 3), .completed, "Name field should be focused when Capture opens")
        return name
    }

    @MainActor
    private func todayRow(_ title: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title + ",")).firstMatch
    }

    @MainActor
    func testCaptureWithOnlyANameShowsAsNew() {
        launch()
        _ = openCapture()
        app.typeText("Spider exercise\r")
        let row = todayRow("Spider exercise")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertEqual(row.label, "Spider exercise, New")
    }

    @MainActor
    func testTypingANewAreaMakesADashedChipAndSavesWithTheItem() {
        launch()
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

    @MainActor
    func testEscapeTwiceCreatesNoArea() {
        launch()
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

    @MainActor
    func testShiftEnterKeepsCaptureOpenForTheNextOne() {
        launch()
        let name = openCapture()
        name.typeText("Riff one")
        name.typeKey(.return, modifierFlags: .shift)
        XCTAssertTrue(name.waitForExistence(timeout: 2))
        XCTAssertEqual(name.value as? String ?? "", "")
        name.typeText("Riff two\r")
        XCTAssertTrue(todayRow("Riff one").waitForExistence(timeout: 5))
        XCTAssertTrue(todayRow("Riff two").exists)
    }

    @MainActor
    func testPressingThreeRatesGoodAndMovesToDoneToday() {
        launch()
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

    @MainActor
    func testPastingScreenshotsOnThePracticeCardAttachesThem() throws {
        // A tiny PNG on the clipboard, as if a screenshot was just copied.
        let rep = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8,
                                                 samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                                 colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let png = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setData(png, forType: .png)

        launch()
        let name = openCapture()
        name.typeText("Chorus riff\r")
        let row = todayRow("Chorus riff")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.click()
        XCTAssertTrue(app.buttons["End session"].waitForExistence(timeout: 5))
        app.typeKey("v", modifierFlags: .command)
        XCTAssertTrue(app.staticTexts["Screenshot 1"].waitForExistence(timeout: 5), "⌘V on the card should attach the screenshot")
        let tile = app.buttons["Paste a screenshot"]
        XCTAssertTrue(tile.waitForExistence(timeout: 3), "Images tab should offer the paste tile")
        tile.click()
        XCTAssertTrue(app.staticTexts["Screenshot 2"].waitForExistence(timeout: 5), "the paste tile should attach another one")
    }

    @MainActor
    func testZDeletingAUsedAreaKeepsTheItemAndUndoRestoresIt() {
        launch()
        let name = openCapture()
        name.typeText("Walking line")
        let area = app.textFields["Type an area"]
        area.click()
        area.typeText("Grooves\r")
        XCTAssertTrue(app.buttons["Grooves"].waitForExistence(timeout: 3), "picked area chip should show")
        area.typeText("\r")
        XCTAssertTrue(todayRow("Walking line").waitForExistence(timeout: 5), "item should be saved")
        app.typeKey(",", modifierFlags: .command)
        let trash = app.buttons["Delete Grooves"]
        XCTAssertTrue(trash.waitForExistence(timeout: 5), "Settings › Areas should list Grooves")
        for _ in 0..<6 where !trash.isHittable {
            app.scrollViews.firstMatch.scroll(byDeltaX: 0, deltaY: -400)
        }
        XCTAssertTrue(trash.isHittable, "couldn't scroll to Grooves")
        trash.click()
        let undo = app.buttons["Undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 3), "Undo toast should appear")
        undo.hover()
        undo.click()
        XCTAssertTrue(app.buttons["Rename Grooves"].waitForExistence(timeout: 3), "Undo should restore Grooves")
        app.typeKey("1", modifierFlags: .command)
        XCTAssertTrue(todayRow("Walking line").waitForExistence(timeout: 5))
    }
}
