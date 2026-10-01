import AppKit
import Testing
@testable import Echo

@MainActor
@Suite("Line number gutter")
struct LineNumberRulerTests {
    @Test func onlyLineStartsGetANumber() {
        let text = "select 1\nfrom t\r\nwhere x" as NSString
        #expect(LineNumberRulerView.startsLogicalLine(0, in: text))
        #expect(!LineNumberRulerView.startsLogicalLine(3, in: text))
        #expect(LineNumberRulerView.startsLogicalLine(9, in: text))
        #expect(LineNumberRulerView.startsLogicalLine(17, in: text))
    }

    @Test func gutterWidensWithDigitCount() {
        let two = LineNumberRulerView.thickness(forDigits: 2)
        let five = LineNumberRulerView.thickness(forDigits: 5)
        #expect(five > two)
    }

    @Test func tenThousandLinesAreCountedToTheLastLine() {
        let script = Array(repeating: "select 1;", count: 10_000).joined(separator: "\n") as NSString
        #expect(script.lineNumber(at: script.length) == 10_000)
    }
}
