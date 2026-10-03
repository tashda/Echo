import AppKit
import ImageIO
import UniformTypeIdentifiers

/// The picture sent with a question (decision H14): the Stage window as the owner sees it, as a JPEG small enough for the
/// local API (it refuses more than 1.4 MB). Returns `nil` when nothing could be drawn; the question is then sent without it.
@MainActor
enum StageSnapshot {
    static let maxPixels = 1600
    static let maxBytes = 1_300_000

    static func jpegOfFrontStageWindow() -> Data? {
        let window = NSApp.windows.first(where: { $0.isVisible && !$0.isSheet && $0.contentView != nil })
        guard let view = window?.contentView else { return nil }
        return jpeg(of: view)
    }

    static func jpeg(of view: NSView) -> Data? {
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let cg = rep.cgImage else { return nil }
        // Scale down so a retina window does not produce a huge file (and drop the alpha channel, which JPEG cannot keep), then try
        // lower qualities until it fits.
        let scale = min(1.0, Double(maxPixels) / Double(max(cg.width, cg.height)))
        let image = resized(cg, scale: scale) ?? cg
        for quality in [0.8, 0.6, 0.4] {
            if let data = encode(image, quality: quality), data.count <= maxBytes { return data }
        }
        return nil
    }

    private static func resized(_ image: CGImage, scale: Double) -> CGImage? {
        let w = max(Int(Double(image.width) * scale), 1)
        let h = max(Int(Double(image.height) * scale), 1)
        guard let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return context.makeImage()
    }

    private static func encode(_ image: CGImage, quality: Double) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
