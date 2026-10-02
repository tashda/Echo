import Foundation
import MySQLKit
import Testing
@testable import Echo

/// How MySQL and MariaDB values and column types read in the grid (Echo #40, decision D24).
@Suite("MySQL values in the grid")
struct MySQLValueDisplayTests {
    private let formatter = MySQLCellFormatter()

    private func column(_ type: MySQLDataType, length: UInt64 = 0, binary: Bool = false) -> MySQLColumn {
        MySQLColumn(name: "c", type: type, length: length, characterSet: binary ? 63 : 255)
    }

    @Test func textValuesAreTheServers() {
        #expect(formatter.stringValue(bytes: Data("2026-01-01 12:34:56.123456".utf8), column: column(.datetime)) == "2026-01-01 12:34:56.123456")
        #expect(formatter.stringValue(bytes: Data("9999-12-31 23:59:59.999999".utf8), column: column(.datetime)) == "9999-12-31 23:59:59.999999")
        #expect(formatter.stringValue(bytes: Data("0.1".utf8), column: column(.float)) == "0.1")
        #expect(formatter.stringValue(bytes: Data("-838:59:59".utf8), column: column(.time)) == "-838:59:59")
        #expect(formatter.stringValue(bytes: nil, column: column(.varString)) == nil)
        #expect(formatter.stringValue(bytes: Data(), column: column(.varString)) == "")
    }

    @Test func bitsShowAsBitStrings() {
        #expect(formatter.stringValue(bytes: Data([1]), column: column(.bit, length: 1)) == "1")
        #expect(formatter.stringValue(bytes: Data([0, 5]), column: column(.bit, length: 10)) == "b'0000000101'")
    }

    @Test func bytesThatArentTextShowAsHex() {
        #expect(formatter.stringValue(bytes: Data([0x00, 0xFF, 0x10]), column: column(.varString, binary: true)) == "0x00FF10")
        #expect(formatter.stringValue(bytes: Data("abc".utf8), column: column(.blob, binary: true)) == "abc")
        #expect(formatter.stringValue(bytes: Data([1, 2]), column: column(.geometry, binary: true)) == "0x0102")
    }

    @Test func longBitColumnsAreTextNotBooleans() {
        #expect(ResultGridValueClassifier.kind(forDataType: "BIT(64)", value: "b'1'") == .text)
        #expect(ResultGridValueClassifier.kind(forDataType: "BIT", value: "1") == .boolean)
        #expect(ResultGridValueClassifier.kind(forDataType: "BIGINT UNSIGNED", value: "1") == .numeric)
        #expect(ResultGridValueClassifier.kind(forDataType: "DECIMAL(65,30)", value: "1.5") == .numeric)
        #expect(ResultGridValueClassifier.kind(forDataType: "VARBINARY", value: "0x00") == .binary)
        #expect(ResultGridValueClassifier.kind(forDataType: "DATETIME", value: "2026-01-01") == .temporal)
    }

    @Test func tlsSettingsMapToMySQLModes() {
        #expect(MySQLNIOFactory.tlsMode(enabled: false, mode: .require, caPath: nil) == .disabled)
        #expect(MySQLNIOFactory.tlsMode(enabled: true, mode: .prefer, caPath: nil) == .preferred)
        #expect(MySQLNIOFactory.tlsMode(enabled: true, mode: .require, caPath: nil) == .required)
        #expect(MySQLNIOFactory.tlsMode(enabled: true, mode: .verifyCA, caPath: "/ca.pem") == .verifyCA(caCertificatePath: "/ca.pem"))
        #expect(MySQLNIOFactory.tlsMode(enabled: true, mode: .verifyFull, caPath: "") == .verifyIdentity(caCertificatePath: nil))
    }
}
