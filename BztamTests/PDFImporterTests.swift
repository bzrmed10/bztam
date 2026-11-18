import Foundation
import PDFKit
import Testing
@testable import Bztam

@MainActor
struct PDFImporterTests {
    @Test func readsTheEmbeddedTextOfABill() async throws {
        let document = try #require(PDFDocument(data: DemoBill.pdfData()))
        let result = await PDFImporter.read(document)
        #expect(result.pages.count == 1)
        #expect(result.lines.contains { $0.contains("LYDEC") })

        let draft = ReceiptParser.parse(lines: result.lines)
        #expect(draft.amount == 31_000)
        #expect(draft.merchant == "Lydec")
        #expect(draft.categoryKey == "bills")
    }

    @Test func splitsTextIntoLines() {
        #expect(PDFImporter.textLines("  A \n\n B\r\nC ") == ["A", "B", "C"])
    }
}
