import Foundation

/// Round MC, MC-0: connection folders retire. A connection signs in with an identity or its own
/// login; nothing is inherited from a folder any more (Design/05-components › Connections).
///
/// This turns saved data from before the round into that shape, once, without changing who a
/// connection signs in as:
/// - a connection that inherited from a folder whose sign-in is an identity now uses that identity;
/// - a folder with its own user name and password becomes an identity named after the folder (it
///   keeps the folder's keychain item, so the password is not copied), and the connections that
///   inherited from it use that identity;
/// - every connection leaves its folder, and every connection folder is removed;
/// - identity folders stay only while an identity is still in them; they are shown as groups.
///
/// The function is pure so it can be tested and run again safely: data that has no connection
/// folders and no inherited sign-ins comes back unchanged.
nonisolated enum FolderRetirement {
    struct Outcome: Sendable {
        var connections: [SavedConnection]
        var identities: [SavedIdentity]
        /// The folders to keep: identity folders that still hold an identity.
        var folders: [SavedFolder]
        var changedConnectionIDs: Set<UUID> = []
        /// Identities created from folders with their own login, and identities that left a removed folder.
        var changedIdentityIDs: Set<UUID> = []
        var removedFolders: [SavedFolder] = []

        var didChange: Bool {
            !changedConnectionIDs.isEmpty || !changedIdentityIDs.isEmpty || !removedFolders.isEmpty
        }
    }

    static func run(
        connections: [SavedConnection],
        folders: [SavedFolder],
        identities: [SavedIdentity]
    ) -> Outcome {
        var outcome = Outcome(connections: connections, identities: identities, folders: folders)
        let foldersByID = Dictionary(folders.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let connectionFolderIDs = Set(folders.filter { $0.kind == .connections }.map(\.id))
        let identityIDs = Set(identities.map(\.id))

        // Identities made from folders with their own login, one per folder and sign-in method,
        // because a folder's login used each connection's own method and domain.
        var madeIdentities: [MadeIdentityKey: UUID] = [:]

        for index in outcome.connections.indices {
            var connection = outcome.connections[index]
            let original = connection

            if connection.credentialSource == .inherit {
                switch source(forFolder: connection.folderID, in: foldersByID) {
                case .identity(let identityID) where identityIDs.contains(identityID):
                    connection.credentialSource = .identity
                    connection.identityID = identityID
                case .ownLogin(let folder, let username):
                    let key = MadeIdentityKey(
                        folderID: folder.id,
                        method: connection.authenticationMethod,
                        domain: connection.domain.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    let identityID: UUID
                    if let existing = madeIdentities[key] {
                        identityID = existing
                    } else {
                        let identity = SavedIdentity(
                            projectID: folder.projectID ?? connection.projectID,
                            name: uniqueName(for: folder, method: key.method, among: outcome.identities),
                            authenticationMethod: key.method,
                            username: username,
                            domain: key.domain.isEmpty ? nil : key.domain,
                            keychainIdentifier: folder.manualKeychainIdentifier
                        )
                        outcome.identities.append(identity)
                        outcome.changedIdentityIDs.insert(identity.id)
                        madeIdentities[key] = identity.id
                        identityID = identity.id
                    }
                    connection.credentialSource = .identity
                    connection.identityID = identityID
                case .identity, .nothing:
                    // The folder gave no usable sign-in, so the connection had none either.
                    // It keeps its own (empty) login and asks for a password, as before.
                    connection.credentialSource = .manual
                }
            }

            if connection.folderID != nil {
                connection.folderID = nil
            }

            if connection != original {
                outcome.connections[index] = connection
                outcome.changedConnectionIDs.insert(connection.id)
            }
        }

        // Identities never belong to a connection folder; damaged data could say otherwise.
        for index in outcome.identities.indices {
            if let folderID = outcome.identities[index].folderID,
               connectionFolderIDs.contains(folderID) || foldersByID[folderID] == nil {
                outcome.identities[index].folderID = nil
                outcome.changedIdentityIDs.insert(outcome.identities[index].id)
            }
        }

        let usedIdentityFolderIDs = Set(outcome.identities.compactMap(\.folderID))
        outcome.folders = folders.filter { $0.kind == .identities && usedIdentityFolderIDs.contains($0.id) }
        let keptIDs = Set(outcome.folders.map(\.id))
        outcome.removedFolders = folders.filter { !keptIDs.contains($0.id) }
        return outcome
    }

    // MARK: - Resolving a folder's sign-in

    enum FolderSource: Equatable {
        case identity(UUID)
        case ownLogin(SavedFolder, username: String)
        case nothing
    }

    /// What a connection inheriting from this folder signed in with, following "inherit from
    /// parent" upwards. A loop or a missing folder gives nothing.
    static func source(forFolder folderID: UUID?, in folders: [UUID: SavedFolder]) -> FolderSource {
        var visited = Set<UUID>()
        var currentID = folderID
        while let id = currentID, !visited.contains(id), let folder = folders[id] {
            visited.insert(id)
            switch folder.credentialMode {
            case .none:
                return .nothing
            case .identity:
                guard let identityID = folder.identityID else { return .nothing }
                return .identity(identityID)
            case .manual:
                let username = folder.manualUsername?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return username.isEmpty ? .nothing : .ownLogin(folder, username: username)
            case .inherit:
                currentID = folder.parentFolderID
            }
        }
        return .nothing
    }

    // MARK: - Names

    private struct MadeIdentityKey: Hashable {
        let folderID: UUID
        let method: DatabaseAuthenticationMethod
        let domain: String
    }

    /// The folder's name, made unique among the project's identities ("corporate", "corporate 2").
    /// A second sign-in method from the same folder adds the method ("corporate (Windows integrated)").
    private static func uniqueName(
        for folder: SavedFolder,
        method: DatabaseAuthenticationMethod,
        among identities: [SavedIdentity]
    ) -> String {
        let trimmed = folder.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "Folder sign-in" : trimmed
        let projectNames = Set(
            identities
                .filter { $0.projectID == folder.projectID }
                .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        )
        var candidates = [base]
        if method != .sqlPassword { candidates.insert("\(base) (\(method.displayName))", at: 0) }
        for candidate in candidates where !projectNames.contains(candidate.lowercased()) {
            return candidate
        }
        var number = 2
        while projectNames.contains("\(base) \(number)".lowercased()) { number += 1 }
        return "\(base) \(number)"
    }
}
