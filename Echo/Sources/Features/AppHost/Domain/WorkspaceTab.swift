import Foundation
import SwiftUI
import Combine

@MainActor
final class WorkspaceTab: ObservableObject, Identifiable {
    struct BookmarkTabContext: Equatable {
        let bookmarkID: UUID
        let displayName: String
        let originalQuery: String

        init(bookmarkID: UUID, displayName: String, originalQuery: String) {
            self.bookmarkID = bookmarkID
            self.displayName = displayName
            self.originalQuery = originalQuery
        }

        init(bookmark: Bookmark) {
            self.bookmarkID = bookmark.id
            self.displayName = bookmark.primaryLine
            self.originalQuery = bookmark.query
        }
    }

    enum Kind: CaseIterable {
        case query
        case structure
        case diagram
        case jobQueue
        case psql
        case extensionStructure
        case extensionsManager
        case activityMonitor
    }

    enum Content {
        case query(QueryEditorState)
        case structure(TableStructureEditorViewModel)
        case diagram(SchemaDiagramViewModel)
        case jobQueue(JobQueueViewModel)
        case psql(PSQLTabViewModel)
        case extensionStructure(PostgresExtensionStructureViewModel)
        case extensionsManager(PostgresExtensionsManagerViewModel)
        case activityMonitor(ActivityMonitorViewModel)
    }

    let id = UUID()
    let connection: SavedConnection
    let session: DatabaseSession
    let connectionSessionID: UUID

    @Published var title: String
    @Published private(set) var content: Content
    @Published var isPinned: Bool
    @Published var activeDatabaseName: String?
    let bookmarkContext: BookmarkTabContext?

    private var contentCancellable: AnyCancellable?
    let resultsGridState = QueryResultsGridState()

    init(
        connection: SavedConnection,
        session: DatabaseSession,
        connectionSessionID: UUID,
        title: String,
        content: Content,
        isPinned: Bool = false,
        activeDatabaseName: String? = nil,
        bookmarkContext: BookmarkTabContext? = nil
    ) {
        self.connection = connection
        self.session = session
        self.connectionSessionID = connectionSessionID
        self.title = title
        self.content = content
        self.isPinned = isPinned
        self.activeDatabaseName = activeDatabaseName
        self.bookmarkContext = bookmarkContext
        subscribeToContent()
    }

    var kind: Kind {
        switch content {
        case .query: return .query
        case .structure: return .structure
        case .diagram: return .diagram
        case .jobQueue: return .jobQueue
        case .psql: return .psql
        case .extensionStructure: return .extensionStructure
        case .extensionsManager: return .extensionsManager
        case .activityMonitor: return .activityMonitor
        }
    }

    var query: QueryEditorState? {
        if case .query(let state) = content { return state }
        return nil
    }

    var structureEditor: TableStructureEditorViewModel? {
        if case .structure(let editor) = content { return editor }
        return nil
    }

    var extensionStructure: PostgresExtensionStructureViewModel? {
        if case .extensionStructure(let vm) = content { return vm }
        return nil
    }

    var extensionsManager: PostgresExtensionsManagerViewModel? {
        if case .extensionsManager(let vm) = content { return vm }
        return nil
    }

    var diagram: SchemaDiagramViewModel? {
        if case .diagram(let diagram) = content { return diagram }
        return nil
    }

    var jobQueue: JobQueueViewModel? {
        if case .jobQueue(let vm) = content { return vm }
        return nil
    }

    var psql: PSQLTabViewModel? {
        if case .psql(let vm) = content { return vm }
        return nil
    }

    var activityMonitor: ActivityMonitorViewModel? {
        if case .activityMonitor(let vm) = content { return vm }
        return nil
    }

    func setContent(_ newContent: Content) {
        content = newContent
        subscribeToContent()
        objectWillChange.send()
    }

    func estimatedMemoryUsageBytes() -> Int {
        let baseOverhead = 96 * 1024
        switch content {
        case .query(let state):
            return baseOverhead + state.estimatedMemoryUsageBytes()
        case .structure(let editor):
            return baseOverhead + editor.estimatedMemoryUsageBytes()
        case .diagram(let diagram):
            return baseOverhead + diagram.estimatedMemoryUsageBytes()
        case .jobQueue:
            return baseOverhead
        case .psql(let vm):
            return baseOverhead + vm.estimatedMemoryUsageBytes()
        case .extensionStructure(let vm):
            return baseOverhead + vm.estimatedMemoryUsageBytes()
        case .extensionsManager(let vm):
            return baseOverhead + vm.estimatedMemoryUsageBytes()
        case .activityMonitor:
            return baseOverhead + 1024 * 1024
        }
    }

    private func subscribeToContent() {
        contentCancellable = nil
        switch content {
        case .query(let state):
            state.rowCountRefreshHandler = { [weak self] in
                self?.resultsGridState.scheduleRowCountRefresh()
            }
            contentCancellable = state.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.objectWillChange.send() }
        case .structure(let editor):
            contentCancellable = editor.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.objectWillChange.send() }
        case .extensionStructure(let vm):
            contentCancellable = vm.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.objectWillChange.send() }
        case .extensionsManager(let vm):
            contentCancellable = vm.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.objectWillChange.send() }
        case .diagram(let diagram):
            contentCancellable = diagram.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.objectWillChange.send() }
        case .jobQueue(let vm):
            contentCancellable = vm.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.objectWillChange.send() }
        case .psql(let vm):
            contentCancellable = vm.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.objectWillChange.send() }
        case .activityMonitor(let vm):
            contentCancellable = vm.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.objectWillChange.send() }
        }
    }
}
