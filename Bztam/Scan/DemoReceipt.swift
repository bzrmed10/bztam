import SwiftUI
import UIKit

/// A sample Marjane receipt drawn in code, used by screenshots and UI tests (the simulator has no camera).
/// It goes through the real text recognition and parser.
struct DemoReceipt: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MARJANE").font(.system(size: 34, weight: .bold, design: .monospaced)).frame(maxWidth: .infinity)
            Text("Casablanca Ain Sebaa").frame(maxWidth: .infinity)
            Text("17/11/2026  18:42").frame(maxWidth: .infinity)
            Divider()
            line("LAIT 1L x2", "15,80")
            line("PAIN COMPLET", "12,00")
            line("HUILE OLIVE", "89,90")
            line("TOMATES 2KG", "18,00")
            line("FROMAGE", "68,88")
            Divider()
            line("TVA 20%", "40,92")
            line("TOTAL TTC", "245,50").font(.system(size: 26, weight: .bold, design: .monospaced))
            line("ESPECES", "300,00")
            line("RENDU", "54,50")
            Text("MERCI DE VOTRE VISITE").frame(maxWidth: .infinity).padding(.top, 8)
        }
        .font(.system(size: 22, design: .monospaced))
        .foregroundStyle(.black)
        .padding(40)
        .frame(width: 640)
        .background(.white)
    }

    private func line(_ left: String, _ right: String) -> some View {
        HStack {
            Text(left)
            Spacer()
            Text(right)
        }
    }

    @MainActor
    static func image() -> UIImage {
        let renderer = ImageRenderer(content: DemoReceipt())
        renderer.scale = 2
        return renderer.uiImage ?? UIImage()
    }
}
