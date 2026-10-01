import SwiftUI

extension ColorTokens {
    /// Echo's mark: three pills, each with its own gradient (Design/AppIcon/EchoIcon.svg). Brand
    /// artwork, so the colours do not adapt to the appearance.
    public enum Brand {
        /// The gradient of pill `index` (0 top, 2 bottom), running left to right and slightly down.
        public static func markPillGradient(_ index: Int) -> LinearGradient {
            LinearGradient(stops: markPillStops(index), startPoint: UnitPoint(x: 0, y: 0), endPoint: UnitPoint(x: 1, y: 0.25))
        }

        private static func markPillStops(_ index: Int) -> [Gradient.Stop] {
            switch index {
            case 0: [stop(0x8B4BFF, 0), stop(0x6F6CFF, 0.45), stop(0x2AA9FF, 0.85), stop(0x2ACBFF, 1)]
            case 1: [stop(0x9166F0, 0), stop(0xA660D6, 0.5), stop(0xFF6E60, 0.88), stop(0xFF9B78, 1)]
            default: [stop(0xFFA087, 0), stop(0xFF7C8C, 0.5), stop(0xFF5AA3, 0.88), stop(0xFF78B8, 1)]
            }
        }

        private static func stop(_ hex: UInt32, _ location: CGFloat) -> Gradient.Stop {
            Gradient.Stop(
                color: Color(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255),
                location: location
            )
        }
    }
}
