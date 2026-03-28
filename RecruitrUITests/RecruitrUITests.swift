//
//  RecruitrUITests.swift
//  RecruitrUITests
//
//  Created by Caden Warren on 7/23/25.
//

import XCTest

final class RecruitrUITests: XCTestCase {

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("UITEST_MODE")
        app.launch()
        return app
    }

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        let app = launchApp()
        XCTAssertTrue(app.buttons["View Records"].exists)
        XCTAssertTrue(app.buttons["Add New"].exists)
        XCTAssertTrue(app.buttons["AI Prompts"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            _ = launchApp()
        }
    }

    @MainActor
    func testCanOpenRecordDetailsInUITestMode() throws {
        let app = launchApp()

        app.buttons["View Records"].tap()
        app.buttons["sidebar-record-candidate-1"].tap()

        XCTAssertTrue(app.staticTexts["Taylor Candidate"].exists)
        XCTAssertTrue(app.staticTexts["Prompts Used"].exists)
    }

    @MainActor
    func testCanOpenPromptManagementInUITestMode() throws {
        let app = launchApp()

        app.buttons["AI Prompts"].tap()

        XCTAssertTrue(app.staticTexts["AI Prompt Management"].exists)
        XCTAssertTrue(app.staticTexts["Candidate Prompts"].exists)
    }
}
