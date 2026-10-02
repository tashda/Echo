import Foundation

/// Stable bytes allow digest comparisons to skip unchanged records and produce stable opaque IDs.
public enum LocalRecordEncoding {
    public static func encode<Value: Encodable>(_ value: Value) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }
}
