//
//  MapHillsUITests.swift
//  MapHillsUITests
//
//  Created by David Owens on 26/03/2026.
//

import XCTest

private struct UITestSavedWaypointFixture: Codable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let createdAt: Date
}

final class MapHillsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        addUIInterruptionMonitor(withDescription: "System Alerts") { alert in
            guard alert.buttons.count > 0 else { return false }
            alert.buttons.element(boundBy: 0).tap()
            return true
        }
    }

    @MainActor
    private func launchApp(launchEnvironment: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_BYPASS_LOCATION_PROMPTS"] = "1"
        launchEnvironment.forEach { key, value in
            app.launchEnvironment[key] = value
        }
        app.launch()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for _ in 0..<10 {
            let alert = springboard.alerts.firstMatch
            if alert.exists, alert.buttons.count > 0 {
                alert.buttons.element(boundBy: 0).tap()
                break
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return app
    }

    @MainActor
    private func assertOverlayOpensAndCloses(
        app: XCUIApplication,
        buttonIdentifier: String,
        title: String
    ) {
        let triggerButton = app.buttons[buttonIdentifier]
        XCTAssertTrue(triggerButton.waitForExistence(timeout: 5))
        triggerButton.tap()

        let titleText = app.staticTexts[title]
        XCTAssertTrue(titleText.waitForExistence(timeout: 5))

        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5))
        doneButton.tap()

        XCTAssertFalse(titleText.waitForExistence(timeout: 2))
    }

    @MainActor
    private func openSettings(app: XCUIApplication) {
        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func encodedWaypointJSON(_ waypoints: [UITestSavedWaypointFixture]) throws -> String {
        let data = try JSONEncoder().encode(waypoints)
        return try XCTUnwrap(String(data: data, encoding: .utf8))
    }

    @MainActor
    private func dismissAnySystemAlertIfNeeded() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let firstButton = springboard.buttons.element(boundBy: 0)
        if firstButton.exists {
            firstButton.tap()
        }
    }

    @MainActor
    private func isSwitchOn(_ element: XCUIElement) -> Bool {
        (element.value as? String) == "1"
    }

    @MainActor
    func testRightRailButtonsExist() throws {
        let app = launchApp()

        XCTAssertTrue(app.buttons["menuButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settingsButton"].exists)
        XCTAssertTrue(app.buttons["cachingButton"].exists)
        XCTAssertTrue(app.buttons["recordsButton"].exists)
        XCTAssertTrue(app.buttons["aboutButton"].exists)
    }

    @MainActor
    func testAboutOverlayOpensAndCloses() throws {
        let app = launchApp()
        assertOverlayOpensAndCloses(app: app, buttonIdentifier: "aboutButton", title: "About BareGPS Ireland")
    }

    @MainActor
    func testSettingsOverlayOpensAndCloses() throws {
        let app = launchApp()
        assertOverlayOpensAndCloses(app: app, buttonIdentifier: "settingsButton", title: "Settings")
    }

    @MainActor
    func testSettingsShowsKeySections() throws {
        let app = launchApp()
        openSettings(app: app)

        XCTAssertTrue(app.staticTexts["Nearest 100"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Track Recording"].exists)
        XCTAssertTrue(app.staticTexts["Snail Trail"].exists)
        XCTAssertTrue(app.staticTexts["Track Colors"].exists)
        XCTAssertTrue(app.switches["snailTrailSwitch"].exists)
        XCTAssertFalse(app.staticTexts["Units"].exists)
        XCTAssertFalse(app.staticTexts["Recording Display"].exists)
    }

    @MainActor
    func testSettingsSwitchesPersistWhenReopened() throws {
        let app = launchApp()
        openSettings(app: app)

        let snailTrailSwitch = app.switches["snailTrailSwitch"]
        let hillMarkerSwitch = app.switches["hillMarkerSwitch"]
        XCTAssertTrue(snailTrailSwitch.waitForExistence(timeout: 5))
        XCTAssertTrue(hillMarkerSwitch.waitForExistence(timeout: 5))

        let initialSnailTrailState = isSwitchOn(snailTrailSwitch)
        let initialHillMarkerState = isSwitchOn(hillMarkerSwitch)

        snailTrailSwitch.tap()
        hillMarkerSwitch.tap()

        XCTAssertEqual(isSwitchOn(snailTrailSwitch), !initialSnailTrailState)
        XCTAssertEqual(isSwitchOn(hillMarkerSwitch), !initialHillMarkerState)

        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5))
        doneButton.tap()

        openSettings(app: app)

        XCTAssertEqual(isSwitchOn(app.switches["snailTrailSwitch"]), !initialSnailTrailState)
        XCTAssertEqual(isSwitchOn(app.switches["hillMarkerSwitch"]), !initialHillMarkerState)
    }

    @MainActor
    func testLocalHundredModeSwitchingShowsRelevantControls() throws {
        let app = launchApp()
        openSettings(app: app)

        XCTAssertTrue(app.buttons["useCurrentPositionNearestHundredButton"].waitForExistence(timeout: 5))

        let setupModeControl = app.segmentedControls["nearestHundredSetupModeControl"]
        XCTAssertTrue(setupModeControl.waitForExistence(timeout: 5))
        setupModeControl.buttons["Grid Ref"].tap()

        XCTAssertTrue(app.textFields["nearestHundredGridReferenceField"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["setNearestHundredGridReferenceButton"].exists)
        XCTAssertTrue(app.buttons["resetNearestHundredButton"].exists)
    }

    @MainActor
    func testMenuOverlayOpensAndCloses() throws {
        let app = launchApp()
        assertOverlayOpensAndCloses(app: app, buttonIdentifier: "menuButton", title: "Hill Filters")
    }

    @MainActor
    func testCachingOverlayOpensAndCloses() throws {
        let app = launchApp()
        assertOverlayOpensAndCloses(app: app, buttonIdentifier: "cachingButton", title: "Caching")
    }

    @MainActor
    func testCachingDetailLevelSelectionPersistsWhenReopened() throws {
        let app = launchApp()

        let cachingButton = app.buttons["cachingButton"]
        XCTAssertTrue(cachingButton.waitForExistence(timeout: 5))
        cachingButton.tap()

        let detailLevelControl = app.segmentedControls["cacheDetailLevelControl"]
        XCTAssertTrue(detailLevelControl.waitForExistence(timeout: 5))

        XCTAssertTrue(detailLevelControl.buttons["Deep"].waitForExistence(timeout: 5))
        detailLevelControl.buttons["Deep"].tap()
        XCTAssertTrue(detailLevelControl.buttons["Deep"].isSelected)

        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5))
        doneButton.tap()

        XCTAssertFalse(app.staticTexts["Caching"].waitForExistence(timeout: 2))

        cachingButton.tap()
        let reopenedDetailLevelControl = app.segmentedControls["cacheDetailLevelControl"]
        XCTAssertTrue(reopenedDetailLevelControl.waitForExistence(timeout: 5))
        XCTAssertTrue(reopenedDetailLevelControl.buttons["Deep"].isSelected)
    }

    @MainActor
    func testNearestHundredGridReferenceCanBeSetAndReopened() throws {
        let app = launchApp()
        openSettings(app: app)

        let setupModeControl = app.segmentedControls["nearestHundredSetupModeControl"]
        XCTAssertTrue(setupModeControl.waitForExistence(timeout: 5))
        setupModeControl.buttons["Grid Ref"].tap()

        let gridReferenceField = app.textFields["nearestHundredGridReferenceField"]
        XCTAssertTrue(gridReferenceField.waitForExistence(timeout: 5))
        gridReferenceField.tap()
        gridReferenceField.typeText("V 83643 84450")

        let setButton = app.buttons["setNearestHundredGridReferenceButton"]
        XCTAssertTrue(setButton.waitForExistence(timeout: 5))
        setButton.tap()

        let readyAlert = app.staticTexts["Nearest 100 Ready"]
        if readyAlert.waitForExistence(timeout: 2) {
            XCTAssertTrue(app.buttons["OK"].waitForExistence(timeout: 5))
            app.buttons["OK"].tap()
        }

        let statusButton = app.buttons["nearestHundredStatusButton"]
        XCTAssertTrue(statusButton.waitForExistence(timeout: 5))
        XCTAssertTrue(statusButton.label.contains("Grid Ref"))
        XCTAssertTrue(statusButton.label.contains("V 83643 84450"))

        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5))
        doneButton.tap()

        openSettings(app: app)

        let reopenedStatusButton = app.buttons["nearestHundredStatusButton"]
        XCTAssertTrue(reopenedStatusButton.waitForExistence(timeout: 5))
        XCTAssertTrue(reopenedStatusButton.label.contains("Grid Ref"))
        XCTAssertTrue(reopenedStatusButton.label.contains("V 83643 84450"))
    }

    @MainActor
    func testRecordsOverlayOpensAndCloses() throws {
        let app = launchApp()
        let triggerButton = app.buttons["recordsButton"]
        XCTAssertTrue(triggerButton.waitForExistence(timeout: 5))
        triggerButton.tap()

        let titleLabel = app.staticTexts["recordsTitleLabel"]
        XCTAssertTrue(titleLabel.waitForExistence(timeout: 5))

        let doneButton = app.buttons["recordsDoneButton"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5))
        doneButton.tap()

        XCTAssertFalse(titleLabel.waitForExistence(timeout: 2))
    }

    @MainActor
    func testWaypointCreationFromMapSavesWaypointAndAppearsInWaypointsList() throws {
        let app = launchApp(launchEnvironment: [
            "UITEST_CLEAR_SAVED_WAYPOINTS": "1"
        ])

        let mapView = app.otherElements["mainMapView"]
        XCTAssertTrue(mapView.waitForExistence(timeout: 10))
        mapView.press(forDuration: 1.2)
        dismissAnySystemAlertIfNeeded()

        XCTAssertTrue(app.staticTexts["Map Point"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Save Waypoint"].waitForExistence(timeout: 5))
        app.buttons["Save Waypoint"].tap()

        XCTAssertTrue(app.staticTexts["Save Waypoint"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["textInputConfirmButton"].waitForExistence(timeout: 5))
        app.buttons["textInputConfirmButton"].tap()

        let trailButton = app.buttons["trailButton"]
        XCTAssertTrue(trailButton.waitForExistence(timeout: 5))
        trailButton.tap()
        dismissAnySystemAlertIfNeeded()

        let waypointsButton = app.buttons["Waypoints"]
        XCTAssertTrue(waypointsButton.waitForExistence(timeout: 5))
        waypointsButton.tap()
        dismissAnySystemAlertIfNeeded()

        let waypointsTable = app.tables["waypointsTableView"]
        XCTAssertTrue(waypointsTable.waitForExistence(timeout: 5))
        XCTAssertEqual(waypointsTable.cells.count, 1)
    }

    @MainActor
    func testSavedWaypointsOverlayOpensGoToAndDeleteFlowWorks() throws {
        let waypoint = UITestSavedWaypointFixture(
            id: "waypoint-seed-1",
            name: "UITest Waypoint",
            latitude: 53.25,
            longitude: -8.75,
            createdAt: Date(timeIntervalSinceReferenceDate: 1_000)
        )
        let app = launchApp(launchEnvironment: [
            "UITEST_CLEAR_SAVED_WAYPOINTS": "1",
            "UITEST_SAVED_WAYPOINTS_JSON": try encodedWaypointJSON([waypoint])
        ])

        let trailButton = app.buttons["trailButton"]
        XCTAssertTrue(trailButton.waitForExistence(timeout: 5))
        trailButton.tap()
        dismissAnySystemAlertIfNeeded()

        let waypointsButton = app.buttons["Waypoints"]
        XCTAssertTrue(waypointsButton.waitForExistence(timeout: 5))
        waypointsButton.tap()
        dismissAnySystemAlertIfNeeded()

        let waypointsTable = app.tables["waypointsTableView"]
        XCTAssertTrue(waypointsTable.waitForExistence(timeout: 5))
        XCTAssertEqual(waypointsTable.cells.count, 1)

        let waypointCell = waypointsTable.cells.element(boundBy: 0)
        XCTAssertTrue(waypointCell.waitForExistence(timeout: 5))
        waypointCell.tap()

        XCTAssertTrue(app.buttons["Open on Map"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Go To"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 5))

        app.buttons["Open on Map"].tap()
        XCTAssertFalse(app.buttons["Open on Map"].waitForExistence(timeout: 2))

        trailButton.tap()
        waypointsButton.tap()

        XCTAssertTrue(waypointsTable.waitForExistence(timeout: 5))
        XCTAssertEqual(waypointsTable.cells.count, 1)

        waypointsTable.cells.element(boundBy: 0).tap()
        app.buttons["Go To"].tap()

        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))

        app.buttons["Done"].tap()

        trailButton.tap()
        waypointsButton.tap()
        XCTAssertTrue(waypointsTable.waitForExistence(timeout: 5))
        waypointsTable.cells.element(boundBy: 0).tap()
        app.buttons["Delete"].tap()

        XCTAssertTrue(app.staticTexts["No saved waypoints yet."].waitForExistence(timeout: 5))
        XCTAssertEqual(waypointsTable.cells.count, 0)
    }

    @MainActor
    func testRealWorldWaypointShowsIrishGridReferenceInOverlayAndGoToFlow() throws {
        let waypoint = UITestSavedWaypointFixture(
            id: "carrauntoohil-seed",
            name: "Carrauntoohil",
            latitude: 51.999450220,
            longitude: -9.742692984,
            createdAt: Date(timeIntervalSinceReferenceDate: 2_000)
        )
        let app = launchApp(launchEnvironment: [
            "UITEST_CLEAR_SAVED_WAYPOINTS": "1",
            "UITEST_SAVED_WAYPOINTS_JSON": try encodedWaypointJSON([waypoint])
        ])

        let trailButton = app.buttons["trailButton"]
        XCTAssertTrue(trailButton.waitForExistence(timeout: 5))
        trailButton.tap()
        dismissAnySystemAlertIfNeeded()

        let waypointsButton = app.buttons["Waypoints"]
        XCTAssertTrue(waypointsButton.waitForExistence(timeout: 5))
        waypointsButton.tap()
        dismissAnySystemAlertIfNeeded()

        let waypointsTable = app.tables["waypointsTableView"]
        XCTAssertTrue(waypointsTable.waitForExistence(timeout: 5))
        XCTAssertEqual(waypointsTable.cells.count, 1)

        let waypointCell = waypointsTable.cells.element(boundBy: 0)
        XCTAssertTrue(waypointCell.waitForExistence(timeout: 5))
        waypointCell.tap()

        XCTAssertTrue(app.staticTexts["Carrauntoohil"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Grid Ref: V 80364 84421"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Open on Map"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Go To"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 5))

        app.buttons["Go To"].tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
    }

    @MainActor
    func testGPXImportLaunchEnvironmentLoadsImportedTrack() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_GPX_IMPORT_XML"] = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="MapHills">
            <wpt lat="53.1" lon="-8.2">
                <name>Imported Waypoint</name>
            </wpt>
            <trk>
                <trkseg>
                    <trkpt lat="53.1" lon="-8.2">
                        <ele>120</ele>
                        <time>2026-07-07T08:00:00Z</time>
                    </trkpt>
                    <trkpt lat="53.1004" lon="-8.1996">
                        <ele>121</ele>
                        <time>2026-07-07T08:01:00Z</time>
                    </trkpt>
                </trkseg>
            </trk>
        </gpx>
        """
        app.launch()

        XCTAssertTrue(app.staticTexts["GPX Imported"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["OK"].waitForExistence(timeout: 5))
        app.buttons["OK"].tap()

        let gpxButton = app.buttons["trailButton"]
        XCTAssertTrue(gpxButton.waitForExistence(timeout: 5))
        gpxButton.tap()

        XCTAssertTrue(app.buttons["Save Imported GPX"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Clear Imported GPX"].waitForExistence(timeout: 5))

        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5))
        doneButton.tap()
    }
}
