import PDFKit
import UIKit

/// Reads PDF bills (Lydec, Redal, Inwi, bank statements…): the embedded text when there is some,
/// else the rendered pages go through text recognition. The first page becomes the preview image.
@MainActor
enum PDFImporter {
    struct Result {
        var lines: [String]
        var pages: [UIImage]
    }

    /// Up to the first three pages, so a long statement stays fast.
    static func read(_ url: URL, maxPages: Int = 3) async -> Result? {
        guard let document = PDFDocument(url: url), document.pageCount > 0 else { return nil }
        return await read(document, maxPages: maxPages)
    }

    static func read(_ document: PDFDocument, maxPages: Int = 3) async -> Result {
        var lines: [String] = []
        var pages: [UIImage] = []
        for index in 0..<min(document.pageCount, maxPages) {
            guard let page = document.page(at: index) else { continue }
            let image = render(page)
            pages.append(image)
            let text = page.string ?? ""
            if text.filter(\.isLetter).count >= 20 {
                lines += textLines(text)
            } else {
                lines += await TextRecognizer.lines(in: image)
            }
        }
        return Result(lines: lines, pages: pages)
    }

    /// Splits PDF text into trimmed, non-empty lines.
    nonisolated static func textLines(_ text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// A page rendered at about 1600 px on its long side, white background.
    static func render(_ page: PDFPage) -> UIImage {
        let bounds = page.bounds(for: .mediaBox)
        let scale = 1600 / max(bounds.width, bounds.height, 1)
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        return page.thumbnail(of: size, for: .mediaBox)
    }
}
