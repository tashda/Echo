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
    }

    enum Content {
        case query(QueryEditorState)
        case structure(TableStructureEditorViewModel)
        case diagram(SchemaDiagramViewModel)
        case jobQueue(JobQueueViewModel)
    }

    let id = UUID()
    let connection: SavedConnection
    let session: DatabaseSession
    let connectionSessionID: UUID

    @Published var title: String
    @Published private(set) var content: Content
    @Published var isPinned: Bool
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
        bookmarkContext: BookmarkTabContext? = nil
    ) {
        self.connection = connection
        self.session = session
        self.connectionSessionID = connectionSessionID
        self.title = title
        self.content = content
        self.isPinned = isPinned
        self.bookmarkContext = bookmarkContext
        subscribeToContent()
    }

    var kind: Kind {
        switch content {
        case .query: return .query
        case .structure: return .structure
        case .diagram: return .diagram
        case .jobQueue: return .jobQueue
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

    var diagram: SchemaDiagramViewModel? {
        if case .diagram(let diagram) = content { return diagram }
        return nil
    }

    var jobQueue: JobQueueViewModel? {
        if case .jobQueue(let vm) = content { return vm }
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
        case .diagram(let diagram):
            contentCancellable = diagram.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.objectWillChange.send() }
        case .jobQueue(let vm):
            contentCancellable = vm.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.objectWillChange.send() }
        }
    }
}
