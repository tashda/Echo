import Foundation
import Testing
@testable import Echo

/// Round 29: SQL Server Always Encrypted columns in the results grid and Table Data.
struct AlwaysEncryptedColumnTests {
    private let encryption = ColumnInfo.Encryption(
        kind: "deterministic", algorithm: "AEAD_AES_256_CBC_HMAC_SHA_256", typeName: "nvarchar(11)",
        keyStoreName: "MSSQL_CERTIFICATE_STORE", keyPath: "CurrentUser/My/0123456789ABCDEF"
    )

    @Test func anEncryptedColumnIsClassifiedAsEncryptedWhateverItsWireType() {
        let column = ColumnInfo(name: "SSN", dataType: "varbinary", encryption: encryption)
        #expect(ResultGridValueClassifier.kind(for: column, value: "0x01A3F2") == .encrypted)
        #expect(ResultGridValueClassifier.kind(for: column, value: nil) == .null, "NULL is not encrypted")
        #expect(ResultGridValueClassifier.kind(for: ColumnInfo(name: "doc", dataType: "varbinary"), value: "0x01") == .binary)
    }

    @Test func theCellReadsEncryptedWhileItsValueStaysTheCiphertext() {
        #expect(ResultCellPresentation.displayText("0x01A3F2", kind: .encrypted) == "Encrypted")
        #expect(ResultCellPresentation.displayText(nil, kind: .null) == "NULL")
    }

    @Test func theHeaderToolTipNamesTypeKindAlgorithmAndKey() {
        let tip = QueryResultsTableView.Coordinator.encryptionToolTip(encryption)
        #expect(tip.contains("Always Encrypted · nvarchar(11) · deterministic"))
        #expect(tip.contains("AEAD_AES_256_CBC_HMAC_SHA_256"))
        #expect(tip.contains("Key: MSSQL_CERTIFICATE_STORE, CurrentUser/My/0123456789ABCDEF"))
    }

    @Test func editingExplainsWhichKeyIsNeeded() {
        #expect(TableDataEncryptedCell.explanation(columnName: "SSN", encryption: encryption)
            == "Changing SSN needs the column master key (MSSQL_CERTIFICATE_STORE, CurrentUser/My/0123456789ABCDEF), which Echo cannot use.")
    }

    @Test func columnsStoredBeforeTheFieldExistedStillDecode() throws {
        let old = #"{"name":"id","dataType":"int","isPrimaryKey":false,"isNullable":true}"#
        let decoded = try JSONDecoder().decode(ColumnInfo.self, from: Data(old.utf8))
        #expect(decoded.encryption == nil)
        let encrypted = ColumnInfo(name: "SSN", dataType: "varbinary", encryption: encryption)
        let roundTrip = try JSONDecoder().decode(ColumnInfo.self, from: JSONEncoder().encode(encrypted))
        #expect(roundTrip.encryption == encryption)
    }
}
