import XCTest
@testable import Bztam

final class AppGroupTests: XCTestCase {
    func testIdentifierMatchesBundle() {
        XCTAssertEqual(AppGroup.identifier, "group.com.bzrmed.bztam")
    }

    func testInboxIsInsideContainer() throws {
        guard let container = AppGroup.containerURL, let inbox = AppGroup.inboxURL else {
            throw XCTSkip("App Group container is not available without signing")
        }
        XCTAssertEqual(inbox.deletingLastPathComponent().standardizedFileURL, container.standardizedFileURL)
    }
}
