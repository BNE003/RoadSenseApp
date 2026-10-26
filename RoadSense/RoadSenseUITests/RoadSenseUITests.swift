//
//  RoadSenseUITests.swift
//  RoadSenseUITests
//

import XCTest

final class RoadSenseUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Home → start → end → save → history shows the new drive.
    @MainActor
    func testInspectionFlowEndsInHistory() throws {
        let app = XCUIApplication()
        app.launch()

        let start = app.buttons["Start inspection"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()

        let end = app.buttons["End inspection"]
        XCTAssertTrue(end.waitForExistence(timeout: 5))
        sleep(4)   // let the simulated camera report a few detections
        end.tap()

        let save = app.buttons["Save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()

        XCTAssertTrue(app.staticTexts["History"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["24 drives · 412 km inspected"].exists
                      || app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '24 drives'")).firstMatch.exists)
    }

    @MainActor
    func testTabsSwitchScreens() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["Map"].tap()
        XCTAssertTrue(app.staticTexts["7 issues"].waitForExistence(timeout: 5))
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Mount height"].waitForExistence(timeout: 5))
        app.buttons["History"].tap()
        // Section labels are drawn uppercase, so compare case-insensitively.
        let thisWeek = app.staticTexts.matching(NSPredicate(format: "label ==[c] 'This week'")).firstMatch
        XCTAssertTrue(thisWeek.waitForExistence(timeout: 5))
        app.buttons["Home"].tap()
        XCTAssertTrue(app.buttons["Start inspection"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testDeniedCameraShowsExplanation() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-RS_CAMERA_DENIED", "YES"]
        app.launch()

        app.buttons["Start inspection"].tap()
        XCTAssertTrue(app.staticTexts["Can't start"].waitForExistence(timeout: 5))
        app.buttons["Back"].tap()
        XCTAssertTrue(app.buttons["Start inspection"].waitForExistence(timeout: 5))
    }
}
