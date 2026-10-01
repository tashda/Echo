import AppKit
import CoreImage

/// Round 44: the masks that shape a blur from its reach's top (clear) to the card's edge (full).
/// One column of pixels, row 0 at the top; white and opaque where the blur is full, clear where
/// there is none, so both Core Animation (alpha) and Core Image (brightness) read it.
@MainActor
enum LabFBMaskImage {
    /// A column `height` pixels tall where row `y` (from the top) has `amount(y / height)`.
    static func column(height: Int, amount: (CGFloat) -> CGFloat) -> CGImage? {
        let rows = max(height, 2)
        var pixels = [UInt8](repeating: 0, count: rows * 4)
        for row in 0..<rows {
            let value = UInt8((min(max(amount(CGFloat(row) / CGFloat(rows - 1)), 0), 1) * 255).rounded())
            pixels[row * 4 + 0] = value
            pixels[row * 4 + 1] = value
            pixels[row * 4 + 2] = value
            pixels[row * 4 + 3] = value
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(width: 1, height: rows, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 4,
                       space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    /// The same mask for a whole strip `size` in pixels, for Core Image, whose origin is the bottom.
    static func strip(width: CGFloat, height: CGFloat, amount: @escaping (CGFloat) -> CGFloat) -> CIImage? {
        guard let column = column(height: Int(height.rounded()), amount: amount) else { return nil }
        return CIImage(cgImage: column)
            .transformed(by: CGAffineTransform(scaleX: max(width, 1), y: 1))
            .clampedToExtent()
    }
}
