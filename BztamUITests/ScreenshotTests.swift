import XCTest

final class ScreenshotTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func save(_ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] ?? NSTemporaryDirectory()
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
    }

    func testLaunch() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.otherElements["placeholder"].waitForExistence(timeout: 10)
                      || app.staticTexts["Bztam"].waitForExistence(timeout: 5))
        save("01-launch")
    }
}
