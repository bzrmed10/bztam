import CoreGraphics
import ImageIO
import UIKit
import Vision

/// On-device text recognition (Vision). Nothing leaves the phone.
enum TextRecognizer {
    private struct ImageBox: @unchecked Sendable {
        let image: CGImage
        let orientation: CGImagePropertyOrientation
    }

    /// Text lines of an image, top to bottom, each line read left to right.
    static func lines(in image: UIImage) async -> [String] {
        guard let cg = image.cgImage else { return [] }
        let box = ImageBox(image: cg, orientation: CGImagePropertyOrientation(image.imageOrientation))
        return await Task.detached(priority: .userInitiated) {
            recognize(box.image, orientation: box.orientation)
        }.value
    }

    nonisolated private static func recognize(_ image: CGImage, orientation: CGImagePropertyOrientation) -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["fr-FR", "en-US"]
        let handler = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])
        do { try handler.perform([request]) } catch { return [] }
        let items: [(String, CGRect)] = (request.results ?? []).compactMap { observation in
            guard let text = observation.topCandidates(1).first?.string else { return nil }
            return (text, observation.boundingBox)
        }
        return groupIntoLines(items)
    }

    /// Joins boxes that sit on the same row (Vision splits "TOTAL TTC" and "245,50").
    /// Boxes are in Vision's normalized space: origin bottom-left, y up.
    nonisolated static func groupIntoLines(_ items: [(String, CGRect)]) -> [String] {
        let sorted = items.sorted { $0.1.midY > $1.1.midY }
        var rows: [(midY: CGFloat, height: CGFloat, parts: [(String, CGRect)])] = []
        for item in sorted {
            if let last = rows.last, abs(last.midY - item.1.midY) < max(last.height, item.1.height) * 0.5 {
                rows[rows.count - 1].parts.append(item)
            } else {
                rows.append((item.1.midY, item.1.height, [item]))
            }
        }
        return rows.map { row in
            row.parts.sorted { $0.1.minX < $1.1.minX }.map(\.0).joined(separator: " ")
        }
    }
}

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
