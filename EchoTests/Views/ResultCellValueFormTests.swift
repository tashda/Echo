import Testing
@testable import Echo

@Suite("Result cell value forms (round 21, values in the grid)")
struct ResultCellValueFormTests {
    @Test func formsFollowKindAndPostgresArrays() {
        #expect(ResultCellValueForm.form(kind: .text, dataType: "TEXT[](1009)") == .postgresArray)
        #expect(ResultCellValueForm.form(kind: .text, dataType: "INTEGER[](1007)") == .postgresArray)
        #expect(ResultCellValueForm.form(kind: .json, dataType: "JSONB(3802)") == .json)
        #expect(ResultCellValueForm.form(kind: .json, dataType: "json") == .json)
        #expect(ResultCellValueForm.form(kind: .binary, dataType: "varbinary") == .binary)
        #expect(ResultCellValueForm.form(kind: .numeric, dataType: "NUMERIC(1700)") == .decimal)
        #expect(ResultCellValueForm.form(kind: .text, dataType: "nvarchar") == .plain)
        #expect(ResultCellValueForm.form(kind: .temporal, dataType: "date") == .plain)
    }

    @Test func arraysShowCountThenItems() {
        let shown = ResultCellValueForm.shown(#"{new,"net 30",NULL}"#, form: .postgresArray)
        #expect(shown.text == "3\u{2002}new, net 30, NULL")
        #expect(shown.countLength == 1)
        #expect(ResultCellValueForm.shown("{}", form: .postgresArray).text == "0")
        #expect(ResultCellValueForm.postgresArray(#"{"a,b","c\"d","{x}"}"#)?.items == #"a,b, c"d, {x}"#)
        #expect(ResultCellValueForm.postgresArray("{{1,2},{3,4}}").map { "\($0.count) \($0.items)" } == "2 {1,2}, {3,4}")
        #expect(ResultCellValueForm.postgresArray("[0:1]={7,8}")?.count == 2)
        #expect(ResultCellValueForm.postgresArray(#"{{"}",b}}"#)?.count == 1)
        #expect(ResultCellValueForm.shown("not an array", form: .postgresArray).text == "not an array")
    }

    @Test func jsonShowsASummary() {
        #expect(ResultCellValueForm.jsonSummary(#"{"sku": "A-100", "qty": 2, "gift": true, "note": null}"#) == "{ 4 keys }")
        #expect(ResultCellValueForm.jsonSummary(#"{"a": {"b": [1, 2, 3]}, "c": "x,y"}"#) == "{ 2 keys }")
        #expect(ResultCellValueForm.jsonSummary(#"{"only": 1}"#) == "{ 1 key }")
        #expect(ResultCellValueForm.jsonSummary(" { } ") == "{ }")
        #expect(ResultCellValueForm.jsonSummary("[1, [2, 3], {\"a\": 4}]") == "[ 3 items ]")
        #expect(ResultCellValueForm.jsonSummary("[\"one\"]") == "[ 1 item ]")
        #expect(ResultCellValueForm.jsonSummary("[]") == "[ ]")
        #expect(ResultCellValueForm.jsonSummary(#""a string""#) == nil)
        #expect(ResultCellValueForm.jsonSummary("42") == nil)
        #expect(ResultCellValueForm.jsonSummary(#"{"q": "say \"hi\", then {go}"}"#) == "{ 1 key }")
    }

    @Test func binaryShowsKindAndSize() {
        let png = "\\x89504e470d0a1a0a" + String(repeating: "00", count: 12_280)
        #expect(ResultCellValueForm.binarySummary(png) == "PNG image · 12 KB")
        #expect(ResultCellValueForm.binarySummary("0xFFD8FFE000104A46") == "JPEG image · 8 bytes")
        #expect(ResultCellValueForm.binarySummary("0x255044462D") == "PDF · 5 bytes")
        #expect(ResultCellValueForm.binarySummary("\\x01") == "Binary · 1 byte")
        #expect(ResultCellValueForm.binarySummary("\\x") == "Empty")
        #expect(ResultCellValueForm.binarySummary("hello") == nil)
        #expect(ResultCellValueForm.binarySummary("0xZZ") == nil)
        #expect(ResultCellValueForm.byteSize(1536) == "1.5 KB")
        #expect(ResultCellValueForm.byteSize(5 * 1024 * 1024) == "5 MB")
    }

    @Test func decimalsLineUpOnThePoint() {
        #expect(ResultCellValueForm.fractionDigits("1249.5") == 1)
        #expect(ResultCellValueForm.fractionDigits("12045.75") == 2)
        #expect(ResultCellValueForm.fractionDigits("42") == 0)
        #expect(ResultCellValueForm.fractionDigits("1.5e10") == 0)
        #expect(ResultCellValueForm.decimalAligned("1249.5", fractionDigits: 2) == "1249.5\u{2007}")
        #expect(ResultCellValueForm.decimalAligned("7", fractionDigits: 2) == "7\u{2008}\u{2007}\u{2007}")
        #expect(ResultCellValueForm.decimalAligned("38.00", fractionDigits: 2) == "38.00")
        #expect(ResultCellValueForm.decimalAligned("42", fractionDigits: 0) == "42")
        #expect(ResultCellValueForm.decimalAligned("0.1", fractionDigits: 40) == "0.1" + String(repeating: "\u{2007}", count: 5))
    }

    @Test func copyAsShownHasNoPadding() {
        #expect(ResultCellValueForm.copiedAsShown(#"{a,b}"#, kind: .text, form: .postgresArray) == "2 a, b")
        #expect(ResultCellValueForm.copiedAsShown("7", kind: .numeric, form: .decimal) == "7")
        #expect(ResultCellValueForm.copiedAsShown("t", kind: .boolean, form: .plain) == "✓")
        #expect(ResultCellValueForm.copiedAsShown(nil, kind: .null, form: .plain) == nil)
    }
}
