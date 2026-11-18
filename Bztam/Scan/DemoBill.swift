import UIKit

/// A sample Lydec bill as a real PDF with embedded text, used by screenshots and tests.
enum DemoBill {
    static let lines = [
        "LYDEC", "Facture d'électricité et d'eau", "Date de facture : 06/11/2026", "Client : 1234567",
        "Consommation électricité 210 kWh", "Montant HT 258,33", "TVA 51,67", "Montant à payer 310,00 DH"
    ]

    static func pdfData() -> Data {
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        return UIGraphicsPDFRenderer(bounds: page).pdfData { context in
            context.beginPage()
            var y: CGFloat = 60
            for (index, line) in lines.enumerated() {
                let font = index == 0 ? UIFont.boldSystemFont(ofSize: 28) : UIFont.systemFont(ofSize: 16)
                (line as NSString).draw(at: CGPoint(x: 50, y: y), withAttributes: [.font: font, .foregroundColor: UIColor.black])
                y += index == 0 ? 50 : 30
            }
        }
    }

    static func writeTemporaryPDF() -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("demo-bill.pdf")
        return (try? pdfData().write(to: url)) != nil ? url : nil
    }
}
