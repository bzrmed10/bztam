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

    /// Fixed bills: pick, remove, add your own, skip without amounts, come back, skip again. Used to crash.
    func testBillsSkipAndRemove() {
        let app = launch("en", ["-freshStart", "-currency", "mad"])
        func tap(_ id: String) {
            let b = app.buttons[id].firstMatch
            XCTAssertTrue(b.waitForExistence(timeout: 5), id)
            b.tap()
            sleep(1)
        }
        tap("onboarding.continue")   // currency
        tap("onboarding.continue")   // payday
        tap("onboarding.continue")   // money in
        tap("onboarding.continue")   // household
        tap("onboarding.continue")   // bills
        tap("bill.rent")
        tap("bill.utilities")
        tap("bill.rent")             // remove it again
        tap("bill.custom")           // scrolls down to its card
        if app.buttons["keyboard.done"].exists { app.buttons["keyboard.done"].tap(); sleep(1) }
        tap("onboarding.skip")       // skip with bills that have no amount
        XCTAssertTrue(app.staticTexts["How do you live?"].waitForExistence(timeout: 5))
        app.buttons["Back"].firstMatch.tap()
        sleep(1)
        tap("bill.phone")
        let field = app.textFields.firstMatch
        if field.waitForExistence(timeout: 3) { field.tap(); app.typeText("200") }
        tap("bill.phone")            // remove while typing
        tap("onboarding.skip")
        XCTAssertTrue(app.staticTexts["How do you live?"].waitForExistence(timeout: 5))
        tap("onboarding.skip")       // how you live
        tap("onboarding.skip")       // savings
        tap("onboarding.skip")       // plan
        XCTAssertTrue(app.buttons["onboarding.finish"].waitForExistence(timeout: 5))
        app.buttons["onboarding.finish"].tap()
        XCTAssertTrue(app.staticTexts["Categories"].waitForExistence(timeout: 10))
    }

    private func capture(_ lang: String) {
        var app = launch(lang, ["-demoData"])
        XCTAssertTrue(app.staticTexts["home.left"].waitForExistence(timeout: 15))
        sleep(1)
        save("\(lang)-01-home")

        app.buttons["tab.activity"].tap()
        sleep(1)
        save("\(lang)-03-activity")
        app.buttons["tab.plan"].tap()
        sleep(1)
        save("\(lang)-35-plan")
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

        app = launch(lang, ["-demoData", "-paywallShot"])
        sleep(3)
        save("\(lang)-40-plus")
        app.terminate()

        app = launch(lang, ["-demoData", "-openScreen", "monthend"])
        sleep(2)
        save("\(lang)-37-monthend")
        app.terminate()

        app = launch(lang, ["-demoData", "-openScreen", "monthover"])
        sleep(2)
        save("\(lang)-38-monthover")
        if app.buttons["monthend.savings"].waitForExistence(timeout: 3) {
            app.buttons["monthend.savings"].tap()
            sleep(2)
            save("\(lang)-39-monthend-pick")
        }
        app.terminate()

        app = launch(lang, ["-demoData", "-openScreen", "calendar"])
        sleep(3)
        save("\(lang)-36-calendar")
        app.terminate()

        app = launch(lang, ["-demoData", "-openScreen", "goals"])
        XCTAssertTrue(app.buttons["goals.new"].waitForExistence(timeout: 15))
        sleep(1)
        save("\(lang)-32-goals")
        app.terminate()

        app = launch(lang, ["-freshStart", "-currency", "mad"])
        XCTAssertTrue(app.buttons["onboarding.continue"].waitForExistence(timeout: 15))
        save("\(lang)-06-onboarding-welcome")
        // One step at a time: wait for the slide to finish before the next tap.
        func next() {
            let button = app.buttons["onboarding.continue"].firstMatch
            _ = button.waitForExistence(timeout: 5)
            button.tap()
            sleep(2)
        }
        next()                                                  // currency
        next()                                                  // payday
        next()                                                  // money in
        XCTAssertTrue(app.buttons["8"].waitForExistence(timeout: 5))
        for key in ["8", "0", "0", "0"] { app.buttons[key].firstMatch.tap() }
        next()                                                  // household
        next()                                                  // bills
        XCTAssertTrue(app.buttons["bill.rent"].waitForExistence(timeout: 5))
        for bill in ["bill.rent", "bill.phone", "bill.utilities"] { app.buttons[bill].firstMatch.tap(); sleep(1) }
        let field = app.textFields.firstMatch
        if field.waitForExistence(timeout: 3) { field.tap(); app.typeText("3000") }
        sleep(1)
        save("\(lang)-28-onboarding-bills")
        if app.buttons["keyboard.done"].exists { app.buttons["keyboard.done"].tap(); sleep(1) }
        next()                                                  // how you live
        save("\(lang)-29-onboarding-life")
        next()                                                  // savings
        next()                                                  // plan
        save("\(lang)-30-onboarding-plan")
        next()                                                  // summary
        save("\(lang)-31-onboarding-ready")
        app.terminate()
    }

    /// The biggest text size: Home, Add and Settings must stay readable and not overlap.
    func testLargeText() {
        let app = launch("en", ["-demoData", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"])
        XCTAssertTrue(app.staticTexts["Categories"].waitForExistence(timeout: 15))
        sleep(1)
        save("en-33-large-home")
        app.terminate()
        let add = launch("en", ["-demoData", "-openScreen", "add", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"])
        sleep(3)
        save("en-34-large-add")
        add.terminate()
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
        app.buttons["tab.plan"].tap(); sleep(1); save("ar-35-plan")
        app.buttons["tab.settings"].tap(); sleep(1); save("ar-05-settings")
        app.terminate()
        app = launch("ar", ["-demoData", "-openScreen", "add"])
        XCTAssertTrue(app.buttons["add.save"].waitForExistence(timeout: 15))
        sleep(1)
        save("ar-02-add")
        app.terminate()
        app = launch("ar", ["-demoData", "-openScreen", "goals"])
        XCTAssertTrue(app.buttons["goals.new"].waitForExistence(timeout: 15))
        sleep(1)
        save("ar-32-goals")
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
