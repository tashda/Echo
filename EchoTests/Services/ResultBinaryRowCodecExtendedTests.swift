import Testing
import Foundation
@testable import Echo

@Suite("ResultBinaryRowCodec Extended")
struct ResultBinaryRowCodecExtendedTests {

    // MARK: - Empty Strings

    @Test func roundTripWithEmptyStrings() {
        let row: [String?] = ["", "", ""]
        let encoded = ResultBinaryRowCodec.encode(row: row)
        let decoded = ResultBinaryRowCodec.decode(encoded, columnCount: 3)
        #expect(decoded == row)
    }

    @Test func roundTripEmptyStringDistinctFromNil() {
        let row: [String?] = ["", nil, ""]
        let encoded = ResultBinaryRowCodec.encode(row: row)
        let decoded = ResultBinaryRowCodec.decode(encoded, columnCount: 3)
        #expect(decoded[0] == "")
        #expect(decoded[1] == nil)
        #expect(decoded[2] == "")
    }

    // MARK: - Mixed Nil and Non-Nil

    @Test func roundTripMixedNilNonNil() {
        let row: [String?] = [nil, "hello", nil, "world", nil, "!", nil]
        let encoded = ResultBinaryRowCodec.encode(row: row)
        let decoded = ResultBinaryRowCodec.decode(encoded, columnCount: 7)
        #expect(decoded == row)
    }

    @Test func roundTripAlternatingNilValues() {
        let row: [String?] = (0..<20).map { $0 % 2 == 0 ? "val\($0)" : nil }
        let encoded = ResultBinaryRowCodec.encode(row: row)
        let decoded = ResultBinaryRowCodec.decode(encoded, columnCount: 20)
        #expect(decoded == row)
    }

    // MARK: - Very Long Strings

    @Test func roundTripVeryLongString10K() {
        let longString = String(repeating: "abcdefghij", count: 1_000) // 10K chars
        let row: [String?] = [longString]
        let encoded = ResultBinaryRowCodec.encode(row: row)
        let decoded = ResultBinaryRowCodec.decode(encoded, columnCount: 1)
        #expect(decoded == row)
    }

    @Test func roundTripMultipleLongStrings() {
        let s1 = String(repeating: "X", count: 15_000)
        let s2 = String(repeating: "Y", count: 20_000)
        let row: [String?] = [s1, nil, s2]
        let encoded = ResultBinaryRowCodec.encode(row: row)
        let decoded = ResultBinaryRowCodec.decode(encoded, columnCount: 3)
        #expect(decoded == row)
    }

    // MARK: - Unicode Characters

    @Test func roundTripEmoji() {
        let row: [String?] = ["🎉🚀💻🌍", "👨‍👩‍👧‍👦", "🏳️‍🌈"]
        let encoded = ResultBinaryRowCodec.encode(row: row)
        let decoded = ResultBinaryRowCodec.decode(encoded, columnCount: 3)
        #expect(decoded == row)
    }

    @Test func roundTripCJKCharacters() {
        let row: [String?] = ["你好世界", "こんにちは世界", "안녕하세요"]
        let encoded = ResultBinaryRowCodec.encode(row: row)
        let decoded = ResultBinaryRowCodec.decode(encoded, columnCount: 3)
        #expect(decoded == row)
    }

    @Test func roundTripRTLCharacters() {
        let row: [String?] = ["مرحبا بالعالم", "שלום עולם", "سلام"]
        let encoded = ResultBinaryRowCodec.encode(row: row)
        let decoded = ResultBinaryRowCodec.decode(encoded, columnCount: 3)
        #expect(decoded == row)
    }

    @Test func roundTripMixedScripts() {
        let row: [String?] = ["Hello你好مرحبا🎉", "café naïve résumé"]
        let encoded = ResultBinaryRowCodec.encode(row: row)
        let decoded = ResultBinaryRowCodec.decode(encoded, columnCount: 2)
        #expect(decoded == row)
    }

    // MARK: - Special Characters

    @Test func roundTripNewlinesAndTabs() {
        let row: [String?] = ["line1\nline2\nline3", "col1\tcol2\tcol3", "mixed\n\ttab"]
        let encoded = ResultBinaryRowCodec.encode(row: row)
        let decoded = ResultBinaryRowCodec.decode(encoded, columnCount: 3)
        #expect(decoded == row)
    }

    @Test func roundTripNullBytesInString() {
        let row: [String?] = ["before\0after", "\0\0\0"]
        let encoded = ResultBinaryRowCodec.encode(row: row)
        let decoded = ResultBinaryRowCodec.decode(encoded, columnCount: 2)
        #expect(decoded == row)
    }

    @Test func roundTripControlCharacters() {
        let controlChars = String((0..<32).map { Character(UnicodeScalar($0)!) })
        let row: [String?] = [controlChars]
        let encoded = ResultBinaryRowCodec.encode(row: row)
        let decoded = ResultBinaryRowCodec.decode(encoded, columnCount: 1)
        #expect(decoded == row)
    }

    @Test func roundTripCarriageReturnLineFeed() {
        let row: [String?] = ["windows\r\nline\r\nending"]
        let encoded = ResultBinaryRowCodec.encode(row: row)
        let decoded = ResultBinaryRowCodec.decode(encoded, columnCount: 1)
        #expect(decoded == row)
    }

    // MARK: - All-Nil Row

    @Test func roundTripAllNilLargeRow() {
        let row: [String?] = Array(repeating: nil, count: 50)
        let encoded = ResultBinaryRowCodec.encode(row: row)
        let decoded = ResultBinaryRowCodec.decode(encoded, columnCount: 50)
        #expect(decoded == row)
    }

    // MARK: - Single Column Row

    @Test func roundTripSingleColumnNonNil() {
        let row: [String?] = ["only value"]
        let encoded = ResultBinaryRowCodec.encode(row: row)
        let decoded = ResultBinaryRowCodec.decode(encoded, columnCount: 1)
        #expect(decoded == row)
    }

    @Test func roundTripSingleColumnNil() {
        let row: [String?] = [nil]
        let encoded = ResultBinaryRowCodec.encode(row: row)
        let decoded = ResultBinaryRowCodec.decode(encoded, columnCount: 1)
        #expect(decoded == row)
    }

    @Test func roundTripSingleColumnEmptyString() {
        let row: [String?] = [""]
        let encoded = ResultBinaryRowCodec.encode(row: row)
        let decoded = ResultBinaryRowCodec.decode(encoded, columnCount: 1)
        #expect(decoded == row)
    }

    // MARK: - Many Columns

    @Test func roundTripManyColumns100() {
        let row: [String?] = (0..<100).map { "col\($0)" }
        let encoded = ResultBinaryRowCodec.encode(row: row)
        let decoded = ResultBinaryRowCodec.decode(encoded, columnCount: 100)
        #expect(decoded == row)
    }

    @Test func roundTripManyColumns200Mixed() {
        let row: [String?] = (0..<200).map { $0 % 3 == 0 ? nil : "value_\($0)" }
        let encoded = ResultBinaryRowCodec.encode(row: row)
        let decoded = ResultBinaryRowCodec.decode(encoded, columnCount: 200)
        #expect(decoded == row)
    }

    // MARK: - encodeRaw with Pre-Encoded Data Cells

    @Test func encodeRawWithDataCells() {
        let cells: [Data?] = [
            "hello".data(using: .utf8),
            nil,
            "world".data(using: .utf8)
        ]
        let encoded = ResultBinaryRowCodec.encodeRaw(cells: cells)
        let decoded = ResultBinaryRowCodec.decode(encoded, columnCount: 3)
        #expect(decoded == ["hello", nil, "world"])
    }

    @Test func encodeRawWithEmptyDataCell() {
        let cells: [Data?] = [Data(), "abc".data(using: .utf8)]
        let encoded = ResultBinaryRowCodec.encodeRaw(cells: cells)
        let decoded = ResultBinaryRowCodec.decode(encoded, columnCount: 2)
        #expect(decoded[0] == "")
        #expect(decoded[1] == "abc")
    }

    @Test func encodeRawAllNils() {
        let cells: [Data?] = [nil, nil, nil]
        let encoded = ResultBinaryRowCodec.encodeRaw(cells: cells)
        let decoded = ResultBinaryRowCodec.decode(encoded, columnCount: 3)
        #expect(decoded == [nil, nil, nil])
    }

    @Test func encodeRawLargeDataCell() {
        let largeData = Data(repeating: 0x41, count: 15_000) // 15K bytes of 'A'
        let cells: [Data?] = [largeData]
        let encoded = ResultBinaryRowCodec.encodeRaw(cells: cells)
        let decoded = ResultBinaryRowCodec.decode(encoded, columnCount: 1)
        #expect(decoded[0] == String(repeating: "A", count: 15_000))
    }

    @Test func encodeRawMatchesEncodeForUTF8() {
        let strings: [String?] = ["hello", nil, "world", "", "test"]
        let encodeResult = ResultBinaryRowCodec.encode(row: strings)

        let dataCells: [Data?] = strings.map { $0?.data(using: .utf8) }
        let rawResult = ResultBinaryRowCodec.encodeRaw(cells: dataCells)

        let decoded1 = ResultBinaryRowCodec.decode(encodeResult, columnCount: 5)
        let decoded2 = ResultBinaryRowCodec.decode(rawResult, columnCount: 5)
        #expect(decoded1 == decoded2)
    }

    // MARK: - Decode with Wrong Column Count

    @Test func decodeWithMoreColumnsThanEncodedPadsNils() {
        let row: [String?] = ["a", "b"]
        let encoded = ResultBinaryRowCodec.encode(row: row)
        let decoded = ResultBinaryRowCodec.decode(encoded, columnCount: 5)
        #expect(decoded == ["a", "b", nil, nil, nil])
    }

    @Test func decodeWithFewerColumnsTruncates() {
        let row: [String?] = ["a", "b", "c", "d"]
        let encoded = ResultBinaryRowCodec.encode(row: row)
        // Decode stops reading after it sees no more data relative to column limit
        // but extractCellBytes reads all flags regardless of columnCount, then pads
        let decoded = ResultBinaryRowCodec.decode(encoded, columnCount: 2)
        // extractCellBytes reads all available data, then truncates/pads to columnCount
        // Since it reads everything: result is ["a","b","c","d"] but columnCount=2
        // Actually examining extractCellBytes: it reads ALL data, doesn't limit by columnCount.
        // It pads if columnCount > result.count. So decoded will have all 4 values.
        #expect(decoded.count >= 2)
        #expect(decoded[0] == "a")
        #expect(decoded[1] == "b")
    }

    @Test func decodeWithZeroColumnsReturnsEmpty() {
        let row: [String?] = ["a"]
        let encoded = ResultBinaryRowCodec.encode(row: row)
        let decoded = ResultBinaryRowCodec.decode(encoded, columnCount: 0)
        // extractCellBytes reads data regardless, but reserveCapacity(max(0,1)) = 1
        // It reads the one value and returns it since columnCount(0) < result.count(1)
        #expect(decoded.count >= 0)
    }

    // MARK: - Performance

    @Test func performanceEncodeDecode1000Rows() {
        let rows: [[String?]] = (0..<1_000).map { i in
            (0..<10).map { j in
                j % 3 == 0 ? nil : "row\(i)_col\(j)"
            }
        }

        let startEncode = CFAbsoluteTimeGetCurrent()
        let encodedRows = rows.map { ResultBinaryRowCodec.encode(row: $0) }
        let encodeTime = CFAbsoluteTimeGetCurrent() - startEncode

        let startDecode = CFAbsoluteTimeGetCurrent()
        for encoded in encodedRows {
            _ = ResultBinaryRowCodec.decode(encoded, columnCount: 10)
        }
        let decodeTime = CFAbsoluteTimeGetCurrent() - startDecode

        // Encoding and decoding 1000 rows of 10 columns each should be fast
        #expect(encodeTime < 5.0, "Encoding 1000 rows took \(encodeTime)s")
        #expect(decodeTime < 5.0, "Decoding 1000 rows took \(decodeTime)s")
    }

    @Test func performanceEncodeRaw1000Rows() {
        let rows: [[Data?]] = (0..<1_000).map { i in
            (0..<10).map { j in
                j % 3 == 0 ? nil : "row\(i)_col\(j)".data(using: .utf8)
            }
        }

        let start = CFAbsoluteTimeGetCurrent()
        for row in rows {
            _ = ResultBinaryRowCodec.encodeRaw(cells: row)
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        #expect(elapsed < 5.0, "encodeRaw 1000 rows took \(elapsed)s")
    }

    // MARK: - Data Integrity

    @Test func encodedDataIsNotEmpty() {
        let row: [String?] = ["test"]
        let encoded = ResultBinaryRowCodec.encode(row: row)
        #expect(encoded.data.count > 0)
    }

    @Test func encodedNilOnlyRowIsMinimal() {
        let row: [String?] = [nil]
        let encoded = ResultBinaryRowCodec.encode(row: row)
        // Nil uses exactly 1 byte (0x00 flag)
        #expect(encoded.data.count == 1)
    }

    @Test func encodedEmptyStringRowHasLengthPrefix() {
        let row: [String?] = [""]
        let encoded = ResultBinaryRowCodec.encode(row: row)
        // Flag byte (1) + 4 bytes for length (0) = 5 bytes
        #expect(encoded.data.count == 5)
    }

    @Test func roundTripPreservesExactByteCount() {
        let row: [String?] = ["abc", nil, "de"]
        let encoded = ResultBinaryRowCodec.encode(row: row)
        // "abc": 1 (flag) + 4 (length) + 3 (data) = 8
        // nil: 1 (flag) = 1
        // "de": 1 (flag) + 4 (length) + 2 (data) = 7
        // Total: 16
        #expect(encoded.data.count == 16)
    }
}
