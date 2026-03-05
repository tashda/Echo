import XCTest
@testable import Echo

final class ResultBinaryRowCodecTests: XCTestCase {

    func testEncodeDecodeRoundTripWithStrings() {
        let row: [String?] = ["hello", "world", "123"]
        let encoded = ResultBinaryRowCodec.encode(row: row)
        let decoded = ResultBinaryRowCodec.decode(encoded, columnCount: 3)
        XCTAssertEqual(decoded, row)
    }

    func testNilCellsPreserved() {
        let row: [String?] = ["a", nil, "c", nil]
        let encoded = ResultBinaryRowCodec.encode(row: row)
        let decoded = ResultBinaryRowCodec.decode(encoded, columnCount: 4)
        XCTAssertEqual(decoded, row)
    }

    func testEmptyRow() {
        let row: [String?] = []
        let encoded = ResultBinaryRowCodec.encode(row: row)
        let decoded = ResultBinaryRowCodec.decode(encoded, columnCount: 0)
        XCTAssertEqual(decoded, row)
    }

    func testUnicodeContent() {
        let row: [String?] = ["こんにちは", "🎉🚀", "café", "Ñoño"]
        let encoded = ResultBinaryRowCodec.encode(row: row)
        let decoded = ResultBinaryRowCodec.decode(encoded, columnCount: 4)
        XCTAssertEqual(decoded, row)
    }

    func testLargeCells() {
        let largeString = String(repeating: "x", count: 100_000)
        let row: [String?] = [largeString, "small"]
        let encoded = ResultBinaryRowCodec.encode(row: row)
        let decoded = ResultBinaryRowCodec.decode(encoded, columnCount: 2)
        XCTAssertEqual(decoded, row)
    }

    func testAllNilRow() {
        let row: [String?] = [nil, nil, nil]
        let encoded = ResultBinaryRowCodec.encode(row: row)
        let decoded = ResultBinaryRowCodec.decode(encoded, columnCount: 3)
        XCTAssertEqual(decoded, row)
    }

    func testColumnCountPadsWithNils() {
        let row: [String?] = ["a"]
        let encoded = ResultBinaryRowCodec.encode(row: row)
        let decoded = ResultBinaryRowCodec.decode(encoded, columnCount: 3)
        XCTAssertEqual(decoded, ["a", nil, nil])
    }

    func testEmptyStringCells() {
        let row: [String?] = ["", "nonempty", ""]
        let encoded = ResultBinaryRowCodec.encode(row: row)
        let decoded = ResultBinaryRowCodec.decode(encoded, columnCount: 3)
        XCTAssertEqual(decoded, row)
    }
}
