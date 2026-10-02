import Foundation

// The tools whose sections are pages in their tab (round 36.2, WP1). Query Store is a page of
// Maintenance, so its own two views stay a segmented control inside that page.

extension ActivityMonitorViewModel: ToolPageSource {
    var currentPageTitle: String? { currentPage }
    func selectPage(titled title: String) { selectedSection = title }
}

extension MSSQLMaintenanceViewModel: ToolPaged {
    var selectedPage: MaintenanceSection {
        get { selectedSection }
        set { selectedSection = newValue }
    }
}

extension MaintenanceViewModel: ToolPaged {
    var selectedPage: PostgresMaintenanceSection {
        get { selectedSection }
        set { selectedSection = newValue }
    }

    /// Only PostgreSQL's maintenance has pages; MySQL and SQLite use the operations list.
    var availablePages: [PostgresMaintenanceSection] {
        databaseType == .postgresql ? PostgresMaintenanceSection.allCases : []
    }
}

extension ServerPropertiesViewModel: ToolPaged {
    var selectedPage: Section {
        get { selectedSection }
        set { selectedSection = newValue }
    }

    /// PostgreSQL has no logs or configuration pages.
    var availablePages: [Section] {
        session is PostgresSession ? [.overview, .control, .variables, .status] : Section.allCases
    }
}

extension DatabaseSecurityViewModel: ToolPaged {
    var selectedPage: Section {
        get { selectedSection }
        set { selectedSection = newValue }
    }
}

extension PostgresDatabaseSecurityViewModel: ToolPaged {
    var selectedPage: Section {
        get { selectedSection }
        set { selectedSection = newValue }
    }
}

extension MySQLDatabaseSecurityViewModel: ToolPaged {
    var selectedPage: Section {
        get { selectedSection }
        set { selectedSection = newValue }
    }
}

extension ServerSecurityViewModel: ToolPaged {
    var selectedPage: Section {
        get { selectedSection }
        set { selectedSection = newValue }
    }
}

extension PolicyManagementViewModel: ToolPaged {
    var selectedPage: PolicyTab {
        get { selectedTab }
        set { selectedTab = newValue }
    }
}

extension PostgresAdvancedObjectsViewModel: ToolPaged {
    var selectedPage: Section {
        get { selectedSection }
        set { selectedSection = newValue }
    }

    /// Each of the four tools has its own pages (round 49, AO2).
    var availablePages: [Section] { group.sections }
}

extension MSSQLAdvancedObjectsViewModel: ToolPaged {
    var selectedPage: Section {
        get { selectedSection }
        set { selectedSection = newValue }
    }
}

extension TuningAdvisorViewModel: ToolPaged {
    var selectedPage: TuningTab {
        get { selectedTab }
        set { selectedTab = newValue }
    }
}

extension ErrorLogViewModel: ToolPaged {
    var selectedPage: LogProduct {
        get { selectedProduct }
        set { Task { await switchProduct(to: newValue) } }
    }
}

extension PostgresExtensionsViewModel: ToolPaged {
    var selectedPage: Tab {
        get { selectedTab }
        set { selectedTab = newValue }
    }
}

/// The structure editor's sections, by their titles (round 36.2); PostgreSQL's partitions and
/// inheritance included.
extension TableStructureEditorViewModel: ToolPageSource {
    var pageTitles: [String] { TableStructureSection.sections(for: databaseType).map(\.displayName) }
    var currentPageTitle: String? { selectedSection.displayName }

    func selectPage(titled title: String) {
        guard let section = TableStructureSection.sections(for: databaseType).first(where: { $0.displayName == title }) else { return }
        selectedSection = section
    }
}
