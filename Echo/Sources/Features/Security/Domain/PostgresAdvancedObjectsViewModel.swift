import Foundation
import Observation
import PostgresKit

@Observable
final class PostgresAdvancedObjectsViewModel {

    enum Section: String, CaseIterable {
        case foreignData = "Foreign Data"
        case eventTriggers = "Event Triggers"
        case domains = "Domains"
        case compositeTypes = "Composite Types"
        case rangeTypes = "Range Types"
        case collations = "Collations"
        case ftsConfig = "Text Search"
        case rules = "Rules"
        case tablespaces = "Tablespaces"
        case aggregates = "Aggregates"
        case operators = "Operators"
        case languages = "Languages"
        case casts = "Casts"
    }

    let connectionID: UUID
    let connectionSessionID: UUID
    @ObservationIgnored let session: DatabaseSession
    @ObservationIgnored private(set) var panelState: BottomPanelState?
    @ObservationIgnored var activityEngine: ActivityEngine?

    var selectedSection: Section = .foreignData
    var isInitialized = false
    var schemaFilter: String = "public"
    var availableSchemas: [String] = []

    // Data arrays
    var fdws: [PostgresFDWInfo] = []
    var foreignServers: [PostgresForeignServerInfo] = []
    var eventTriggers: [PostgresEventTriggerInfo] = []
    var domains: [PostgresDomainInfo] = []
    var compositeTypes: [PostgresCompositeTypeInfo] = []
    var rangeTypes: [PostgresRangeTypeInfo] = []
    var collations: [PostgresCollationInfo] = []
    var ftsConfigs: [PostgresFTSConfigInfo] = []
    var rules: [PostgresRuleInfo] = []
    var tablespaces: [PostgresTablespaceInfo] = []
    var aggregates: [PostgresAggregateInfo] = []
    var operators: [PostgresOperatorInfo] = []
    var languages: [PostgresLanguageInfo] = []
    var casts: [PostgresCastInfo] = []

    // Loading states
    var isLoadingFDW = false
    var isLoadingEventTriggers = false
    var isLoadingDomains = false
    var isLoadingCompositeTypes = false
    var isLoadingRangeTypes = false
    var isLoadingCollations = false
    var isLoadingFTS = false
    var isLoadingRules = false
    var isLoadingTablespaces = false
    var isLoadingAggregates = false
    var isLoadingOperators = false
    var isLoadingLanguages = false
    var isLoadingCasts = false

    var isLoadingCurrentSection: Bool {
        switch selectedSection {
        case .foreignData: return isLoadingFDW
        case .eventTriggers: return isLoadingEventTriggers
        case .domains: return isLoadingDomains
        case .compositeTypes: return isLoadingCompositeTypes
        case .rangeTypes: return isLoadingRangeTypes
        case .collations: return isLoadingCollations
        case .ftsConfig: return isLoadingFTS
        case .rules: return isLoadingRules
        case .tablespaces: return isLoadingTablespaces
        case .aggregates: return isLoadingAggregates
        case .operators: return isLoadingOperators
        case .languages: return isLoadingLanguages
        case .casts: return isLoadingCasts
        }
    }

    init(session: DatabaseSession, connectionID: UUID, connectionSessionID: UUID) {
        self.session = session
        self.connectionID = connectionID
        self.connectionSessionID = connectionSessionID
    }

    func setPanelState(_ state: BottomPanelState) {
        self.panelState = state
    }

    func initialize() async {
        guard let pg = session as? PostgresSession else { return }
        isInitialized = true
        if availableSchemas.isEmpty {
            do { availableSchemas = try await pg.client.metadata.listSchemas().map(\.name) }
            catch { panelState?.appendMessage("Failed to load schemas: \(error.localizedDescription)", severity: .error) }
        }
        await loadCurrentSection()
    }

    func loadCurrentSection() async {
        guard let pg = session as? PostgresSession else { return }
        switch selectedSection {
        case .foreignData: await loadForeignData(pg: pg)
        case .eventTriggers: await loadEventTriggers(pg: pg)
        case .domains: await loadDomains(pg: pg)
        case .compositeTypes: await loadCompositeTypes(pg: pg)
        case .rangeTypes: await loadRangeTypes(pg: pg)
        case .collations: await loadCollations(pg: pg)
        case .ftsConfig: await loadFTSConfigs(pg: pg)
        case .rules: await loadRules(pg: pg)
        case .tablespaces: await loadTablespaces(pg: pg)
        case .aggregates: await loadAggregates(pg: pg)
        case .operators: await loadOperators(pg: pg)
        case .languages: await loadLanguages(pg: pg)
        case .casts: await loadCasts(pg: pg)
        }
    }

    // MARK: - Data Loading

    private func loadForeignData(pg: PostgresSession) async {
        isLoadingFDW = true
        defer { isLoadingFDW = false }
        do {
            fdws = try await pg.client.metadata.listForeignDataWrappers()
            foreignServers = try await pg.client.metadata.listForeignServers()
        } catch {
            panelState?.appendMessage("Failed to load foreign data: \(error.localizedDescription)", severity: .error)
        }
    }

    private func loadEventTriggers(pg: PostgresSession) async {
        isLoadingEventTriggers = true
        defer { isLoadingEventTriggers = false }
        do { eventTriggers = try await pg.client.metadata.listEventTriggers() }
        catch { panelState?.appendMessage("Failed to load event triggers: \(error.localizedDescription)", severity: .error) }
    }

    private func loadDomains(pg: PostgresSession) async {
        isLoadingDomains = true
        defer { isLoadingDomains = false }
        do { domains = try await pg.client.metadata.listDomains(schema: schemaFilter) }
        catch { panelState?.appendMessage("Failed to load domains: \(error.localizedDescription)", severity: .error) }
    }

    private func loadCompositeTypes(pg: PostgresSession) async {
        isLoadingCompositeTypes = true
        defer { isLoadingCompositeTypes = false }
        do { compositeTypes = try await pg.client.metadata.listCompositeTypes(schema: schemaFilter) }
        catch { panelState?.appendMessage("Failed to load composite types: \(error.localizedDescription)", severity: .error) }
    }

    private func loadRangeTypes(pg: PostgresSession) async {
        isLoadingRangeTypes = true
        defer { isLoadingRangeTypes = false }
        do { rangeTypes = try await pg.client.metadata.listRangeTypes(schema: schemaFilter) }
        catch { panelState?.appendMessage("Failed to load range types: \(error.localizedDescription)", severity: .error) }
    }

    private func loadCollations(pg: PostgresSession) async {
        isLoadingCollations = true
        defer { isLoadingCollations = false }
        do { collations = try await pg.client.metadata.listCollations(schema: schemaFilter) }
        catch { panelState?.appendMessage("Failed to load collations: \(error.localizedDescription)", severity: .error) }
    }

    private func loadFTSConfigs(pg: PostgresSession) async {
        isLoadingFTS = true
        defer { isLoadingFTS = false }
        do { ftsConfigs = try await pg.client.metadata.listTextSearchConfigurations(schema: schemaFilter) }
        catch { panelState?.appendMessage("Failed to load FTS configs: \(error.localizedDescription)", severity: .error) }
    }

    private func loadRules(pg: PostgresSession) async {
        isLoadingRules = true
        defer { isLoadingRules = false }
        do { rules = try await pg.client.metadata.listRules(schema: schemaFilter) }
        catch { panelState?.appendMessage("Failed to load rules: \(error.localizedDescription)", severity: .error) }
    }

    private func loadTablespaces(pg: PostgresSession) async {
        isLoadingTablespaces = true
        defer { isLoadingTablespaces = false }
        do { tablespaces = try await pg.client.metadata.listTablespaces() }
        catch { panelState?.appendMessage("Failed to load tablespaces: \(error.localizedDescription)", severity: .error) }
    }

    private func loadAggregates(pg: PostgresSession) async {
        isLoadingAggregates = true
        defer { isLoadingAggregates = false }
        do { aggregates = try await pg.client.metadata.listAggregates(schema: schemaFilter) }
        catch { panelState?.appendMessage("Failed to load aggregates: \(error.localizedDescription)", severity: .error) }
    }

    private func loadOperators(pg: PostgresSession) async {
        isLoadingOperators = true
        defer { isLoadingOperators = false }
        do { operators = try await pg.client.metadata.listOperators(schema: schemaFilter) }
        catch { panelState?.appendMessage("Failed to load operators: \(error.localizedDescription)", severity: .error) }
    }

    private func loadLanguages(pg: PostgresSession) async {
        isLoadingLanguages = true
        defer { isLoadingLanguages = false }
        do { languages = try await pg.client.metadata.listLanguages() }
        catch { panelState?.appendMessage("Failed to load languages: \(error.localizedDescription)", severity: .error) }
    }

    private func loadCasts(pg: PostgresSession) async {
        isLoadingCasts = true
        defer { isLoadingCasts = false }
        do { casts = try await pg.client.metadata.listCasts() }
        catch { panelState?.appendMessage("Failed to load casts: \(error.localizedDescription)", severity: .error) }
    }
}
