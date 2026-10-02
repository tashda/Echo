import Foundation

/// Routing fields contain opaque identifiers only. Names, SQL and server details belong in payload.
public struct LocalRecord: Sendable {
    public let collection: String
    public let id: String
    public let group: String?
    public let payload: Data
    public let position: Int
    public let isCache: Bool

    public init(collection: String, id: String, group: String? = nil, payload: Data,
                position: Int = 0, isCache: Bool = false) {
        self.collection = collection
        self.id = id
        self.group = group
        self.payload = payload
        self.position = position
        self.isCache = isCache
    }
}

public enum LocalStorageError: Error, LocalizedError, Sendable {
    case sqlite(Int32)
    case keychain(Int32)
    case missingKey
    case invalidKey
    case invalidEnvelope
    case unsupportedVersion
    case invalidRecord

    public var errorDescription: String? {
        switch self {
        case .sqlite(let status): "Local storage operation failed (\(status))."
        case .keychain(let status): "Echo’s local encryption key is unavailable (\(status))."
        case .missingKey: "Echo’s encryption key is missing. Restore the Keychain or import an encrypted export."
        case .invalidKey: "Echo’s local encryption key is invalid. Existing data has been preserved."
        case .invalidEnvelope: "An encrypted local record is damaged."
        case .unsupportedVersion: "This local record requires a newer version of Echo."
        case .invalidRecord: "The local storage record is invalid."
        }
    }
}
