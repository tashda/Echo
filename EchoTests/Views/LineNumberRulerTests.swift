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

    @Test func numbersFollowTheCodeSize() {
        #expect(LineNumberRulerView.numberFont(forCodeSize: 13).pointSize == 11)
        #expect(LineNumberRulerView.numberFont(forCodeSize: 18).pointSize == 16)
        #expect(LineNumberRulerView.thickness(forDigits: 2, codeSize: 18) > LineNumberRulerView.thickness(forDigits: 2, codeSize: 13))
    }

    @Test func tenThousandLinesAreCountedToTheLastLine() {
        let script = Array(repeating: "select 1;", count: 10_000).joined(separator: "\n") as NSString
        #expect(script.lineNumber(at: script.length) == 10_000)
    }
}
