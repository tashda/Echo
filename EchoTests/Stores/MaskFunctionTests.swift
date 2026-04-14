import Testing
import SQLServerKit

@Suite("MaskFunction")
struct MaskFunctionTests {

    // MARK: - sqlExpression

    @Test("default() expression")
    func defaultExpression() {
        #expect(MaskFunction.defaultMask.sqlExpression == "default()")
    }

    @Test("email() expression")
    func emailExpression() {
        #expect(MaskFunction.email.sqlExpression == "email()")
    }

    @Test("random() expression")
    func randomExpression() {
        #expect(MaskFunction.random(start: 1, end: 100).sqlExpression == "random(1, 100)")
    }

    @Test("partial() expression")
    func partialExpression() {
        #expect(MaskFunction.partial(prefix: 2, padding: "XXX", suffix: 1).sqlExpression == "partial(2, 'XXX', 1)")
    }

    @Test("datetime() expression")
    func datetimeExpression() {
        #expect(MaskFunction.datetime(part: "year").sqlExpression == "datetime('year')")
    }

    @Test("partial() escapes single quotes in padding")
    func partialEscapesSingleQuotes() {
        let fn = MaskFunction.partial(prefix: 1, padding: "X'X", suffix: 1)
        #expect(fn.sqlExpression == "partial(1, 'X''X', 1)")
    }

    // MARK: - parse()

    @Test("parse default()")
    func parseDefault() {
        let result = MaskFunction.parse("default()")
        #expect(result == .defaultMask)
    }

    @Test("parse email()")
    func parseEmail() {
        let result = MaskFunction.parse("email()")
        #expect(result == .email)
    }

    @Test("parse random(1, 100)")
    func parseRandom() {
        let result = MaskFunction.parse("random(1, 100)")
        #expect(result == .random(start: 1, end: 100))
    }

    @Test("parse partial(2, \"XXX\", 1)")
    func parsePartial() {
        let result = MaskFunction.parse("partial(2, \"XXX\", 1)")
        #expect(result == .partial(prefix: 2, padding: "XXX", suffix: 1))
    }

    @Test("parse datetime('year')")
    func parseDatetime() {
        let result = MaskFunction.parse("datetime('year')")
        #expect(result == .datetime(part: "year"))
    }

    @Test("parse returns nil for invalid input")
    func parseInvalid() {
        #expect(MaskFunction.parse("unknown()") == nil)
        #expect(MaskFunction.parse("random(abc)") == nil)
    }

    @Test("parse handles whitespace")
    func parseWhitespace() {
        #expect(MaskFunction.parse("  default()  ") == .defaultMask)
        #expect(MaskFunction.parse("  email() ") == .email)
    }
}
