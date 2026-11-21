import XCTest

/// Captures the main screens with demo data in English and French. CI saves them to the ci-screenshots branch.
final class ScreenshotTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func save(_ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] ?? NSTemporaryDirectory()
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
    }

    private func launch(_ lang: String, _ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-appLanguage", lang] + extra
        app.launch()
        return app
    }

    private func capture(_ lang: String) {
        var app = launch(lang, ["-demoData"])
        XCTAssertTrue(app.staticTexts["home.left"].waitForExistence(timeout: 15))
        sleep(1)
        save("\(lang)-01-home")

        app.buttons["tab.activity"].tap()
        sleep(1)
        save("\(lang)-03-activity")
        app.buttons["tab.insights"].tap()
        sleep(2)
        save("\(lang)-09-insights")
        app.buttons["tab.settings"].tap()
        sleep(1)
        save("\(lang)-05-settings")
        // Bottom of the longest pages: the last row must sit above the floating tab bar.
        for _ in 0..<4 { app.swipeUp() }
        sleep(1)
        save("\(lang)-18-settings-bottom")
        app.buttons["tab.home"].tap()
        sleep(1)
        for _ in 0..<4 { app.swipeUp() }
        sleep(1)
        save("\(lang)-19-home-bottom")
        app.buttons["tab.settings"].tap()
        sleep(1)
        app.swipeUp()
        if app.buttons["settings.export"].waitForExistence(timeout: 5) {
            app.buttons["settings.export"].tap()
            sleep(1)
            save("\(lang)-12-export")
        }
        app.terminate()

        // Dark mode
        app = launch(lang, ["-demoData", "-appearance", "dark"])
        XCTAssertTrue(app.staticTexts["home.left"].waitForExistence(timeout: 15))
        sleep(1)
        save("\(lang)-13-home-dark")
        app.buttons["tab.insights"].tap()
        sleep(2)
        save("\(lang)-14-insights-dark")
        app.buttons["tab.activity"].tap()
        sleep(1)
        save("\(lang)-16-activity-dark")
        app.terminate()
        app = launch(lang, ["-demoData", "-appearance", "dark", "-openScreen", "category"])
        sleep(3)
        save("\(lang)-17-category-dark")
        app.terminate()
        app = launch(lang, ["-demoData", "-appearance", "dark", "-openScreen", "add"])
        XCTAssertTrue(app.buttons["add.save"].waitForExistence(timeout: 15))
        sleep(1)
        save("\(lang)-15-add-dark")
        app.terminate()

        app = launch(lang, ["-demoData", "-openScreen", "add"])
        XCTAssertTrue(app.buttons["add.save"].waitForExistence(timeout: 15))
        sleep(1)
        save("\(lang)-02-add")
        app.terminate()

        let question = lang == "fr" ? "Combien pour les cafés ce mois ?" : "How much did I spend on coffee this month?"
        app = launch(lang, ["-demoData", "-openScreen", "ask", "-askQuestion", question])
        XCTAssertTrue(app.staticTexts["ask.amount"].waitForExistence(timeout: 30))
        sleep(1)
        save("\(lang)-10-ask")
        app.terminate()

        app = launch(lang, ["-demoData", "-openScreen", "dart"])
        sleep(4)
        save("\(lang)-11-dart")
        app.terminate()

        app = launch(lang, ["-demoData", "-openScreen", "category"])
        sleep(3)
        save("\(lang)-04-category")
        app.terminate()

        app = launch(lang, ["-demoData", "-openScreen", "scan"])
        XCTAssertTrue(app.buttons["scan.save"].waitForExistence(timeout: 30))
        sleep(1)
        save("\(lang)-07-scan-review")
        app.terminate()

        // Privacy mode
        app = launch(lang, ["-demoData", "-amountsHidden", "YES"])
        XCTAssertTrue(app.staticTexts["home.left"].waitForExistence(timeout: 15))
        sleep(1)
        save("\(lang)-27-privacy")
        app.terminate()

        // Split with friends
        app = launch(lang, ["-demoData", "-openScreen", "friends"])
        sleep(3)
        save("\(lang)-24-friends")
        app.terminate()
        app = launch(lang, ["-demoData", "-openScreen", "split"])
        sleep(3)
        save("\(lang)-25-split")
        app.terminate()
        app = launch(lang, ["-demoData", "-appearance", "dark", "-openScreen", "friends"])
        sleep(3)
        save("\(lang)-26-friends-dark")
        app.terminate()

        // Dark versions for the website
        app = launch(lang, ["-demoData", "-appearance", "dark", "-openScreen", "ask", "-askQuestion", question])
        XCTAssertTrue(app.staticTexts["ask.amount"].waitForExistence(timeout: 30))
        sleep(1)
        save("\(lang)-22-ask-dark")
        app.terminate()
        app = launch(lang, ["-demoData", "-appearance", "dark", "-openScreen", "dart"])
        sleep(4)
        save("\(lang)-23-dart-dark")
        app.terminate()
        app = launch(lang, ["-demoData", "-appearance", "dark", "-openScreen", "scan"])
        XCTAssertTrue(app.buttons["scan.save"].waitForExistence(timeout: 30))
        sleep(1)
        save("\(lang)-21-scan-dark")
        app.terminate()
        app = launch(lang, ["-demoData", "-appearance", "dark"])
        XCTAssertTrue(app.buttons["tab.settings"].waitForExistence(timeout: 15))
        app.buttons["tab.settings"].tap()
        sleep(1)
        save("\(lang)-20-settings-dark")
        app.terminate()

        app = launch(lang, ["-demoData", "-openScreen", "pdf"])
        XCTAssertTrue(app.buttons["scan.save"].waitForExistence(timeout: 30))
        sleep(1)
        save("\(lang)-08-pdf-review")
        app.terminate()

        app = launch(lang, ["-demoData", "-openScreen", "goals"])
        XCTAssertTrue(app.buttons["goals.new"].waitForExistence(timeout: 15))
        sleep(1)
        save("\(lang)-32-goals")
        app.terminate()

        app = launch(lang, ["-freshStart"])
        XCTAssertTrue(app.buttons["onboarding.continue"].waitForExistence(timeout: 15))
        save("\(lang)-06-onboarding-welcome")
        app.buttons["onboarding.continue"].tap()               // currency
        sleep(1)
        app.buttons["onboarding.continue"].tap()               // payday
        sleep(1)
        app.buttons["onboarding.continue"].tap()               // money in
        sleep(1)
        for key in ["8", "0", "0", "0"] where app.buttons[key].exists { app.buttons[key].tap() }
        app.buttons["onboarding.continue"].tap()               // household
        sleep(1)
        app.buttons["onboarding.continue"].tap()               // bills
        sleep(1)
        for bill in ["bill.rent", "bill.phone", "bill.utilities"] where app.buttons[bill].exists { app.buttons[bill].tap() }
        let field = app.textFields.firstMatch
        if field.waitForExistence(timeout: 3) { field.tap(); app.typeText("3000") }
        sleep(1)
        save("\(lang)-28-onboarding-bills")
        if app.buttons["keyboard.done"].exists { app.buttons["keyboard.done"].tap() }
        sleep(1)
        app.buttons["onboarding.continue"].tap()               // how you live
        sleep(1)
        save("\(lang)-29-onboarding-life")
        app.buttons["onboarding.continue"].tap()               // savings
        sleep(1)
        app.buttons["onboarding.continue"].tap()               // plan
        sleep(2)
        save("\(lang)-30-onboarding-plan")
        app.buttons["onboarding.continue"].tap()               // summary
        sleep(1)
        save("\(lang)-31-onboarding-ready")
        app.terminate()
    }

    func testScreenshotsEnglish() { capture("en") }
    func testScreenshotsFrench() { capture("fr") }

    /// Arabic, right to left: the main screens only.
    func testScreenshotsArabic() {
        var app = launch("ar", ["-demoData"])
        XCTAssertTrue(app.staticTexts["home.left"].waitForExistence(timeout: 15))
        sleep(1)
        save("ar-01-home")
        app.buttons["tab.insights"].tap(); sleep(2); save("ar-09-insights")
        app.buttons["tab.activity"].tap(); sleep(1); save("ar-03-activity")
        app.buttons["tab.settings"].tap(); sleep(1); save("ar-05-settings")
        app.terminate()
        app = launch("ar", ["-demoData", "-openScreen", "add"])
        XCTAssertTrue(app.buttons["add.save"].waitForExistence(timeout: 15))
        sleep(1)
        save("ar-02-add")
        app.terminate()
        app = launch("ar", ["-demoData", "-openScreen", "friends"])
        sleep(3)
        save("ar-24-friends")
        app.terminate()
        app = launch("ar", ["-demoData", "-openScreen", "ask", "-askQuestion", "كم صرفت هذا الشهر؟"])
        XCTAssertTrue(app.staticTexts["ask.amount"].waitForExistence(timeout: 30))
        sleep(1)
        save("ar-10-ask")
        app.terminate()
        app = launch("ar", ["-demoData", "-openScreen", "dart"])
        sleep(4)
        save("ar-11-dart")
        app.terminate()
        app = launch("ar", ["-demoData", "-openScreen", "category"])
        sleep(3)
        save("ar-04-category")
        app.terminate()
        app = launch("ar", ["-demoData", "-openScreen", "scan"])
        XCTAssertTrue(app.buttons["scan.save"].waitForExistence(timeout: 30))
        sleep(1)
        save("ar-07-scan-review")
        app.terminate()
        app = launch("ar", ["-demoData", "-openScreen", "split"])
        sleep(3)
        save("ar-25-split")
        app.terminate()
        app = launch("ar", ["-freshStart"])
        XCTAssertTrue(app.buttons["onboarding.continue"].waitForExistence(timeout: 15))
        save("ar-06-onboarding-welcome")
        app.terminate()
    }
}
