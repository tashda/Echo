import Foundation
import Testing
@testable import Echo

@Suite("Folder retirement (round MC, MC-0)")
struct FolderRetirementTests {
    private let projectID = UUID()

    private func folder(
        _ name: String,
        mode: FolderCredentialMode,
        identityID: UUID? = nil,
        username: String? = nil,
        keychain: String? = nil,
        parent: UUID? = nil,
        kind: FolderKind = .connections
    ) -> SavedFolder {
        var folder = SavedFolder(name: name, projectID: projectID, parentFolderID: parent)
        folder.credentialMode = mode
        folder.identityID = identityID
        folder.manualUsername = username
        folder.manualKeychainIdentifier = keychain
        folder.kind = kind
        return folder
    }

    @Test func inheritedIdentityBecomesTheConnectionsOwn() {
        let identity = TestFixtures.savedIdentity(projectID: projectID, name: "loomis", username: "loomis")
        let corporate = folder("corporate", mode: .identity, identityID: identity.id)
        let connection = TestFixtures.savedConnection(projectID: projectID, credentialSource: .inherit, folderID: corporate.id)

        let outcome = FolderRetirement.run(connections: [connection], folders: [corporate], identities: [identity])

        #expect(outcome.connections[0].credentialSource == .identity)
        #expect(outcome.connections[0].identityID == identity.id)
        #expect(outcome.connections[0].folderID == nil)
        #expect(outcome.folders.isEmpty)
        #expect(outcome.removedFolders.map(\.id) == [corporate.id])
        #expect(outcome.identities.count == 1)
    }

    @Test func folderWithItsOwnLoginBecomesAnIdentityKeepingTheKeychainItem() {
        let corporate = folder("corporate", mode: .manual, username: "svc_echo", keychain: "echo.folder.manual.abc")
        let first = TestFixtures.savedConnection(projectID: projectID, credentialSource: .inherit, folderID: corporate.id)
        let second = TestFixtures.savedConnection(projectID: projectID, credentialSource: .inherit, folderID: corporate.id)

        let outcome = FolderRetirement.run(connections: [first, second], folders: [corporate], identities: [])

        #expect(outcome.identities.count == 1, "One identity for the folder, shared by both connections")
        let made = outcome.identities[0]
        #expect(made.name == "corporate")
        #expect(made.username == "svc_echo")
        #expect(made.keychainIdentifier == "echo.folder.manual.abc")
        #expect(made.projectID == projectID)
        #expect(outcome.connections.allSatisfy { $0.credentialSource == .identity && $0.identityID == made.id })
        #expect(outcome.changedIdentityIDs == [made.id])
    }

    @Test func aSecondMethodFromTheSameFolderGetsItsOwnIdentity() {
        let corporate = folder("corporate", mode: .manual, username: "kb", keychain: "k1")
        let sql = TestFixtures.savedConnection(projectID: projectID, credentialSource: .inherit, folderID: corporate.id)
        let windows = TestFixtures.savedConnection(
            projectID: projectID, authenticationMethod: .windowsIntegrated, domain: "BKS",
            credentialSource: .inherit, folderID: corporate.id
        )

        let outcome = FolderRetirement.run(connections: [sql, windows], folders: [corporate], identities: [])

        #expect(outcome.identities.count == 2)
        let windowsIdentity = outcome.identities.first { $0.authenticationMethod == .windowsIntegrated }
        #expect(windowsIdentity?.domain == "BKS")
        #expect(windowsIdentity?.name == "corporate (\(DatabaseAuthenticationMethod.windowsIntegrated.displayName))")
    }

    @Test func nestedFoldersFollowInheritUpwards() {
        let identity = TestFixtures.savedIdentity(projectID: projectID, name: "loomis")
        let parent = folder("corporate", mode: .identity, identityID: identity.id)
        let child = folder("EU", mode: .inherit, parent: parent.id)
        let connection = TestFixtures.savedConnection(projectID: projectID, credentialSource: .inherit, folderID: child.id)

        let outcome = FolderRetirement.run(connections: [connection], folders: [parent, child], identities: [identity])

        #expect(outcome.connections[0].identityID == identity.id)
        #expect(outcome.folders.isEmpty)
        #expect(outcome.removedFolders.count == 2)
    }

    @Test func aFolderWithoutSignInLeavesAnEmptyOwnLogin() {
        let empty = folder("misc", mode: .none)
        let connection = TestFixtures.savedConnection(projectID: projectID, credentialSource: .inherit, folderID: empty.id)

        let outcome = FolderRetirement.run(connections: [connection], folders: [empty], identities: [])

        #expect(outcome.connections[0].credentialSource == .manual)
        #expect(outcome.identities.isEmpty)
    }

    @Test func anInheritLoopGivesNothingInsteadOfHanging() {
        var a = folder("a", mode: .inherit)
        let b = folder("b", mode: .inherit, parent: a.id)
        a.parentFolderID = b.id
        let connection = TestFixtures.savedConnection(projectID: projectID, credentialSource: .inherit, folderID: a.id)

        let outcome = FolderRetirement.run(connections: [connection], folders: [a, b], identities: [])

        #expect(outcome.connections[0].credentialSource == .manual)
    }

    @Test func aNameAlreadyTakenGetsANumber() {
        let existing = TestFixtures.savedIdentity(projectID: projectID, name: "corporate")
        let corporate = folder("corporate", mode: .manual, username: "svc", keychain: "k")
        let connection = TestFixtures.savedConnection(projectID: projectID, credentialSource: .inherit, folderID: corporate.id)

        let outcome = FolderRetirement.run(connections: [connection], folders: [corporate], identities: [existing])

        #expect(outcome.identities.map(\.name).sorted() == ["corporate", "corporate 2"])
    }

    @Test func identityFoldersStayWhileTheyHoldAnIdentity() {
        let used = folder("mssql", mode: .none, kind: .identities)
        let unused = folder("old", mode: .none, kind: .identities)
        var identity = TestFixtures.savedIdentity(projectID: projectID, name: "sa")
        identity.folderID = used.id

        let outcome = FolderRetirement.run(connections: [], folders: [used, unused], identities: [identity])

        #expect(outcome.folders.map(\.id) == [used.id])
        #expect(outcome.removedFolders.map(\.id) == [unused.id])
        #expect(outcome.identities[0].folderID == used.id)
    }

    @Test func connectionsWithTheirOwnSignInOnlyLeaveTheirFolder() {
        let corporate = folder("corporate", mode: .none)
        let identity = TestFixtures.savedIdentity(projectID: projectID, name: "k")
        let own = TestFixtures.savedConnection(projectID: projectID, username: "sa", credentialSource: .manual, folderID: corporate.id)
        let viaIdentity = TestFixtures.savedConnection(projectID: projectID, credentialSource: .identity, identityID: identity.id, folderID: corporate.id)

        let outcome = FolderRetirement.run(connections: [own, viaIdentity], folders: [corporate], identities: [identity])

        #expect(outcome.connections[0].credentialSource == .manual)
        #expect(outcome.connections[0].username == "sa")
        #expect(outcome.connections[1].identityID == identity.id)
        #expect(outcome.connections.allSatisfy { $0.folderID == nil })
    }

    @Test func dataWithoutFoldersIsLeftAlone() {
        let identity = TestFixtures.savedIdentity(projectID: projectID, name: "k")
        let connection = TestFixtures.savedConnection(projectID: projectID, credentialSource: .identity, identityID: identity.id)

        let outcome = FolderRetirement.run(connections: [connection], folders: [], identities: [identity])

        #expect(!outcome.didChange)
        #expect(outcome.connections == [connection])
    }
}
