import Testing
import Foundation
@testable import Echo

@Suite("ExplorerSidebarIdentity")
struct ExplorerSidebarIdentityTests {
    @Test func databaseIDsStayUniqueAcrossConnections() {
        let firstConnectionID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let secondConnectionID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

        let first = ExplorerSidebarIdentity.database(connectionID: firstConnectionID, databaseName: "employees")
        let second = ExplorerSidebarIdentity.database(connectionID: secondConnectionID, databaseName: "employees")

        #expect(first != second)
    }

    @Test func objectIDsStayUniqueAcrossDatabasesAndConnections() {
        let firstConnectionID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let secondConnectionID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

        let sameConnectionDifferentDatabase = ExplorerSidebarIdentity.object(
            connectionID: firstConnectionID,
            databaseName: "employees",
            objectID: "public.users"
        )
        let differentConnectionSameDatabase = ExplorerSidebarIdentity.object(
            connectionID: secondConnectionID,
            databaseName: "employees",
            objectID: "public.users"
        )
        let sameConnectionSameDatabase = ExplorerSidebarIdentity.object(
            connectionID: firstConnectionID,
            databaseName: "employees",
            objectID: "public.users"
        )

        #expect(sameConnectionDifferentDatabase != ExplorerSidebarIdentity.object(
            connectionID: firstConnectionID,
            databaseName: "hr",
            objectID: "public.users"
        ))
        #expect(sameConnectionDifferentDatabase != differentConnectionSameDatabase)
        #expect(sameConnectionSameDatabase == sameConnectionDifferentDatabase)
    }
}
