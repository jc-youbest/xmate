//
//  xmateUITests.swift
//  xmateUITests
//
//  Created by chao on 13/5/2026.
//

import XCTest

final class xmateUITests: XCTestCase {

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
        let app = XCUIApplication()
        app.launch()

        let mailboxButton = app.buttons["Show Mailbox"]
        XCTAssertTrue(mailboxButton.waitForExistence(timeout: 5))
        mailboxButton.tap()

        XCTAssertTrue(app.staticTexts["Mailbox"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Inbox"].exists)
        XCTAssertTrue(app.buttons["Drafts"].exists)
        XCTAssertTrue(app.buttons["Outbox"].exists)
        XCTAssertTrue(app.buttons["Sent"].exists)

        let hideMailboxButton = app.buttons["Hide Mailbox"]
        XCTAssertTrue(hideMailboxButton.exists)
        hideMailboxButton.coordinate(
            withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)
        ).tap()
        XCTAssertTrue(hideMailboxButton.waitForNonExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Show Mailbox"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
