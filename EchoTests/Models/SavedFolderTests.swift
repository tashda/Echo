import Foundation
import Testing
@testable import Echo

/// Folders are organisation only (round MC). Files and synced copies written while folders
/// still held credentials must keep reading.
@MainActor
struct SavedFolderTests {
    /// A folders.json entry as the old FolderDiskStore wrote it, credential keys and all.
    private let legacyJSON = #"""
    [
      {
        "id": "6B1C1D5E-8F35-4C0B-9D8B-2E0C1F7A9B01",
        "projectID": "0E5D7C9A-1B2C-4D3E-8F4A-5B6C7D8E9F00",
        "name": "Production",
        "folderDescription": "Live servers",
        "icon": "folder",
        "parentFolderID": "1A2B3C4D-5E6F-4A7B-8C9D-0E1F2A3B4C5D",
        "createdAt": 780000000,
        "kind": "connections",
        "credentialMode": "manual",
        "identityID": "9F8E7D6C-5B4A-4392-8170-6F5E4D3C2B1A",
        "manualUsername": "sa",
        "manualKeychainIdentifier": "echo.folder.6B1C1D5E",
        "children": [],
        "colorHex": "FF3B30"
      },
      {
        "id": "7C2D3E4F-5A6B-4C7D-8E9F-0A1B2C3D4E5F",
        "name": "Logins",
        "createdAt": 780000001,
        "kind": "identities",
        "credentialMode": "inherit"
      }
    ]
    """#

    @Test func oldFoldersWithCredentialKeysDecode() throws {
        let folders = try JSONDecoder().decode([SavedFolder].self, from: Data(legacyJSON.utf8))

        #expect(folders.count == 2)
        let production = folders[0]
        #expect(production.id == UUID(uuidString: "6B1C1D5E-8F35-4C0B-9D8B-2E0C1F7A9B01"))
        #expect(production.projectID == UUID(uuidString: "0E5D7C9A-1B2C-4D3E-8F4A-5B6C7D8E9F00"))
        #expect(production.name == "Production")
        #expect(production.folderDescription == "Live servers")
        #expect(production.parentFolderID == UUID(uuidString: "1A2B3C4D-5E6F-4A7B-8C9D-0E1F2A3B4C5D"))
        #expect(production.colorHex == "FF3B30")
        #expect(production.kind == .connections)

        let logins = folders[1]
        #expect(logins.kind == .identities)
        #expect(logins.icon == SavedFolder.defaultIcon)
        #expect(logins.colorHex == SavedFolder.defaultColorHex)
        #expect(logins.parentFolderID == nil)
    }

    @Test func encodingKeepsTheOldKeysAndDropsCredentials() throws {
        let folder = SavedFolder(
            name: "Staging",
            projectID: UUID(),
            parentFolderID: UUID(),
            kind: .connections,
            createdAt: Date(timeIntervalSinceReferenceDate: 780_000_000)
        )
        let data = try JSONEncoder().encode(folder)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        for key in ["id", "projectID", "name", "icon", "parentFolderID", "createdAt", "kind", "colorHex"] {
            #expect(object[key] != nil, "\(key) is missing")
        }
        for key in ["credentialMode", "identityID", "manualUsername", "manualKeychainIdentifier"] {
            #expect(object[key] == nil, "\(key) is still written")
        }

        let decoded = try JSONDecoder().decode(SavedFolder.self, from: data)
        #expect(decoded == folder)
    }

    @Test func syncedFolderWithCredentialFieldsApplies() throws {
        let adapter = SyncAdapter()
        let folder = SavedFolder(name: "Shared", projectID: UUID(), kind: .connections)
        var document = try adapter.toSyncDocument(folder, hlc: 1)
        #expect(document.fields["credentialMode"] == nil)

        // A document pushed by an Echo whose folders still held credentials.
        document.fields["credentialMode"] = SyncField(value: Data(#""identity""#.utf8), hlc: 1)
        document.fields["identityID"] = SyncField(value: Data("\"\(UUID().uuidString)\"".utf8), hlc: 1)

        let applied = try adapter.applyToFolder(document, existing: nil)
        #expect(applied.id == folder.id)
        #expect(applied.name == "Shared")
        #expect(applied.kind == .connections)
    }

    @Test func connectionAndIdentityKeepTheirFolder() throws {
        let folderID = UUID()
        let connection = SavedConnection(connectionName: "A", host: "h", port: 1, database: "d", username: "u", folderID: folderID)
        let decodedConnection = try JSONDecoder().decode(SavedConnection.self, from: JSONEncoder().encode(connection))
        #expect(decodedConnection.folderID == folderID)

        let identity = SavedIdentity(name: "Admin", username: "sa", folderID: folderID)
        let decodedIdentity = try JSONDecoder().decode(SavedIdentity.self, from: JSONEncoder().encode(identity))
        #expect(decodedIdentity.folderID == folderID)

        let adapter = SyncAdapter()
        #expect(try adapter.applyToConnection(adapter.toSyncDocument(connection, hlc: 1), existing: nil).folderID == folderID)
    }
}
