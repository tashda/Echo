import SQLServerKit

/// Round 29: the driver's Always Encrypted description as Echo's column model keeps it.
extension ColumnInfo.Encryption {
    nonisolated init?(_ encryption: SQLServerColumnEncryption?) {
        guard let encryption else { return nil }
        self.init(
            kind: encryption.kind?.rawValue,
            algorithm: encryption.algorithm,
            typeName: encryption.typeName,
            keyStoreName: encryption.keyStoreName,
            keyPath: encryption.keyPath
        )
    }
}
