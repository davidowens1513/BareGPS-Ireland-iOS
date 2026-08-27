//
//  MapHillsUITestsLaunchTests.swift
//  MapHillsUITests
//
//  Created by David Owens on 26/03/2026.
//

import XCTest

final class MapHillsUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()
    }
}
