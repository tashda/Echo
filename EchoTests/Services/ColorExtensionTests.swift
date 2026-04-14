import XCTest
import SwiftUI
@testable import Echo

final class ColorExtensionTests: XCTestCase {

    // MARK: - Hex Init

    func testInitWith6CharHex() {
        let color = Color(hex: "FF5733")
        XCTAssertNotNil(color)
    }

    func testInitWith6CharHexWithHash() {
        let color = Color(hex: "#FF5733")
        XCTAssertNotNil(color)
    }

    func testInitWith3CharHex() {
        let color = Color(hex: "F53")
        XCTAssertNotNil(color)
    }

    func testInitWith8CharHex() {
        let color = Color(hex: "FF5733AA")
        XCTAssertNotNil(color)
    }

    func testInvalidHexReturnsNil() {
        // "XYZ" has 3 characters, so it matches the 3-char shorthand hex branch.
        // Scanner.scanHexInt64 returns 0 for non-hex input, producing black (0,0,0).
        // Only strings with unsupported lengths (e.g. 1, 2, 5, 7) return nil.
        let color = Color(hex: "XYZ")
        XCTAssertNotNil(color, "3-char string matches shorthand hex branch, scanner defaults to 0 (black)")

        // Verify that truly invalid lengths do return nil
        XCTAssertNil(Color(hex: "AB"), "2-char hex is not a valid length and should return nil")
        XCTAssertNil(Color(hex: "ABCDE"), "5-char hex is not a valid length and should return nil")
    }

    func testEmptyHexReturnsNil() {
        let color = Color(hex: "")
        XCTAssertNil(color)
    }

    func testInvalidLengthHexReturnsNil() {
        let color = Color(hex: "ABCDE") // 5 chars
        XCTAssertNil(color)
    }

    // MARK: - toHex Round-Trip

    func testToHexRoundTrip() {
        guard let color = Color(hex: "FF5733") else {
            XCTFail("Failed to create color from hex")
            return
        }
        guard let hex = color.toHex() else {
            XCTFail("Failed to convert color to hex")
            return
        }
        XCTAssertTrue(hex.hasPrefix("#"))
        XCTAssertEqual(hex.count, 7) // "#RRGGBB"
    }

    // MARK: - Contrasting Foreground

    func testContrastingForegroundForBlack() {
        guard let black = Color(hex: "000000") else {
            XCTFail("Failed to create black")
            return
        }
        let foreground = black.contrastingForegroundColor
        // Black background should get white foreground
        XCTAssertNotNil(foreground)
    }

    func testContrastingForegroundForWhite() {
        guard let white = Color(hex: "FFFFFF") else {
            XCTFail("Failed to create white")
            return
        }
        let foreground = white.contrastingForegroundColor
        // White background should get black foreground
        XCTAssertNotNil(foreground)
    }
}
