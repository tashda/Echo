import XCTest
@testable import Echo

@MainActor
final class ProjectStoreTests: XCTestCase {
    private var mockRepo: MockProjectRepository!
    private var store: ProjectStore!

    override func setUp() async throws {
        mockRepo = MockProjectRepository()
        store = ProjectStore(repository: mockRepo)
    }

    // MARK: - Load

    func testLoadPopulatesProjectsAndSettings() async throws {
        let project = TestFixtures.project(name: "Test", isDefault: true)
        mockRepo.projects = [project]

        var settings = GlobalSettings()
        settings.defaultEditorFontSize = 16.0
        mockRepo.globalSettings = settings

        try await store.load()

        XCTAssertEqual(store.projects.count, 1)
        XCTAssertEqual(store.selectedProject?.name, "Test")
        XCTAssertEqual(store.globalSettings.defaultEditorFontSize, 16.0)
    }

    func testLoadCreatesDefaultProjectIfEmpty() async throws {
        mockRepo.projects = []

        try await store.load()

        XCTAssertEqual(store.projects.count, 1)
        XCTAssertTrue(store.projects[0].isDefault)
        XCTAssertEqual(mockRepo.saveProjectsCallCount, 1)
    }

    // MARK: - Project CRUD

    func testCreateProject() async throws {
        try await store.load()
        let created = try await store.createProject(name: "New", colorHex: "FF0000", iconName: "star")

        XCTAssertEqual(created.name, "New")
        XCTAssertEqual(created.colorHex, "FF0000")
        XCTAssertTrue(store.projects.contains(where: { $0.id == created.id }))
    }

    func testCreateProjectGeneratesUniqueNames() async throws {
        mockRepo.projects = [TestFixtures.project(name: "Project", isDefault: true)]
        try await store.load()

        let created = try await store.createProject(name: "Project", colorHex: "", iconName: nil)
        XCTAssertEqual(created.name, "Project 2")
    }

    func testUpdateProject() async throws {
        let project = TestFixtures.project(name: "Old", isDefault: true)
        mockRepo.projects = [project]
        try await store.load()

        var updated = project
        updated.name = "New Name"
        try await store.updateProject(updated)

        XCTAssertEqual(store.projects.first(where: { $0.id == project.id })?.name, "New Name")
    }

    func testDeleteProject() async throws {
        let defaultProject = TestFixtures.project(name: "Default", isDefault: true)
        let project = TestFixtures.project(name: "To Delete")
        mockRepo.projects = [defaultProject, project]
        try await store.load()

        try await store.deleteProject(project)

        XCTAssertFalse(store.projects.contains(where: { $0.id == project.id }))
    }

    func testDeleteDefaultProjectIsIgnored() async throws {
        let defaultProject = TestFixtures.project(name: "Default", isDefault: true)
        mockRepo.projects = [defaultProject]
        try await store.load()

        try await store.deleteProject(defaultProject)

        XCTAssertTrue(store.projects.contains(where: { $0.id == defaultProject.id }))
    }

    // MARK: - Selection

    func testSelectProject() async throws {
        let p1 = TestFixtures.project(name: "P1")
        let p2 = TestFixtures.project(name: "P2")
        mockRepo.projects = [p1, p2]
        try await store.load()

        store.selectProject(p2)
        XCTAssertEqual(store.selectedProject?.id, p2.id)

        store.selectProject(nil)
        XCTAssertNil(store.selectedProject)
    }

    // MARK: - Global Settings

    func testSaveGlobalSettingsPersists() async throws {
        try await store.load()

        var settings = store.globalSettings
        settings.editorShowLineNumbers = false
        try await store.saveGlobalSettings(settings)

        XCTAssertEqual(store.globalSettings.editorShowLineNumbers, false)

        // saveGlobalSettings persists via Task.detached; poll until it completes
        // rather than relying on a fixed sleep which is flaky on slow CI runners.
        for _ in 0..<50 {
            if mockRepo.globalSettings.editorShowLineNumbers == false { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertEqual(mockRepo.globalSettings.editorShowLineNumbers, false)
    }
}
