import XCTest
@testable import Echo

final class ProjectTests: XCTestCase {

    // MARK: - Codable Round-Trip

    func testCodableRoundTrip() throws {
        let project = TestFixtures.project(
            name: "My Project",
            colorHex: "FF0000",
            iconName: "star",
            isDefault: false
        )

        let data = try JSONEncoder().encode(project)
        let decoded = try JSONDecoder().decode(Project.self, from: data)

        XCTAssertEqual(decoded.id, project.id)
        XCTAssertEqual(decoded.name, "My Project")
        XCTAssertEqual(decoded.colorHex, "FF0000")
        XCTAssertEqual(decoded.iconName, "star")
        XCTAssertEqual(decoded.isDefault, false)
    }

    func testCodableRoundTripWithBookmarks() throws {
        let connectionID = UUID()
        let bookmarks = [
            TestFixtures.bookmark(connectionID: connectionID, title: "Users Query", query: "SELECT * FROM users"),
            TestFixtures.bookmark(connectionID: connectionID, title: "Orders Query", query: "SELECT * FROM orders")
        ]
        let project = TestFixtures.project(name: "With Bookmarks", bookmarks: bookmarks)

        let data = try JSONEncoder().encode(project)
        let decoded = try JSONDecoder().decode(Project.self, from: data)

        XCTAssertEqual(decoded.bookmarks.count, 2)
        XCTAssertEqual(decoded.bookmarks[0].title, "Users Query")
        XCTAssertEqual(decoded.bookmarks[1].query, "SELECT * FROM orders")
    }

    // MARK: - Default Project

    func testDefaultProjectHasExpectedValues() {
        let defaultProject = Project.defaultProject

        XCTAssertEqual(defaultProject.name, "Default")
        XCTAssertTrue(defaultProject.isDefault)
        XCTAssertEqual(defaultProject.colorHex, "007AFF")
    }

    // MARK: - ProjectExportData Round-Trip

    func testProjectExportDataCodableRoundTrip() throws {
        let project = TestFixtures.project(name: "Export Test")
        let connections = [TestFixtures.savedConnection()]
        let exportData = ProjectExportData(
            project: project,
            connections: connections,
            identities: [],
            folders: [],
            globalSettings: GlobalSettings(),
            bookmarks: project.bookmarks,
            version: "1.0"
        )

        let data = try JSONEncoder().encode(exportData)
        let decoded = try JSONDecoder().decode(ProjectExportData.self, from: data)

        XCTAssertEqual(decoded.project.name, "Export Test")
        XCTAssertEqual(decoded.connections.count, 1)
        XCTAssertEqual(decoded.version, "1.0")
    }
}
