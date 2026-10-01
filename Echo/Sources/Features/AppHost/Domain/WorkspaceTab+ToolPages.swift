import Foundation

/// A tool tab's pages, shown in its tab (ST2, round 36.2): every tool whose sections are separate
/// views. The tab remembers the last page used on its server and reopens on it.
extension WorkspaceTab {
    var toolPageSource: (any ToolPageSource)? {
        let sources: [(any ToolPageSource)?] = [
            activityMonitor, mssqlMaintenance, maintenance, serverPropertiesVM,
            databaseSecurity, postgresSecurity, mysqlSecurity, serverSecurity,
            policyManagementVM, postgresAdvancedObjectsVM, mssqlAdvancedObjectsVM,
            tuningAdvisorVM, errorLogVM, extensionsManager, structureEditor,
        ]
        return sources.lazy.compactMap { $0 }.first
    }

    var toolPages: [String] { toolPageSource?.pageTitles ?? [] }

    var currentToolPage: String? { toolPageSource?.currentPageTitle }

    /// Switches the page from the tab and remembers it for this server.
    func selectToolPage(_ page: String, memory: ToolPageMemory = ToolPageMemory()) {
        guard let source = toolPageSource else { return }
        source.selectPage(titled: page)
        memory.remember(page, tool: toolPageMemoryName, connectionID: connection.id)
    }

    /// Opens on the page last used in this tool on this server. Called once, when the tab is made,
    /// so a caller that opens a tool on a given page still wins.
    func restoreToolPage(memory: ToolPageMemory = ToolPageMemory()) {
        guard let source = toolPageSource,
              let page = memory.page(tool: toolPageMemoryName, connectionID: connection.id),
              source.pageTitles.contains(page) else { return }
        source.selectPage(titled: page)
    }

    private var toolPageMemoryName: String { String(describing: kind) }
}
