import SwiftUI

struct PostgresAdvancedObjectsView: View {
    @Bindable var viewModel: PostgresAdvancedObjectsViewModel
    @Environment(TabStore.self) private var tabStore
    @Environment(EnvironmentState.self) private var environmentState

    @State private var showNewForeignServerSheet = false
    @State private var showNewEventTriggerSheet = false
    @State private var showNewDomainSheet = false
    @State private var showNewCompositeTypeSheet = false
    @State private var showNewRangeTypeSheet = false
    @State private var showNewCollationSheet = false
    @State private var showNewFTSConfigSheet = false
    @State private var showNewRuleSheet = false
    @State private var showNewTablespaceSheet = false
    @State private var showNewAggregateSheet = false
    @State private var showNewOperatorSheet = false
    @State private var showNewLanguageSheet = false
    @State private var showNewCastSheet = false

    var body: some View {
        VStack(spacing: 0) {
            TabSectionToolbar {
                sectionPicker
            } controls: {
                addButton
            }

            Divider()

            if !viewModel.isInitialized {
                TabInitializingPlaceholder(
                    icon: "puzzlepiece.extension",
                    title: "Loading Objects",
                    subtitle: "Fetching advanced object metadata\u{2026}"
                )
            } else {
                sectionContent
            }
        }
        .background(ColorTokens.Background.primary)
        .task { await viewModel.initialize() }
        .onChange(of: viewModel.selectedSection) { _, _ in
            guard viewModel.isInitialized else { return }
            Task { await viewModel.loadCurrentSection() }
        }
        .onChange(of: viewModel.schemaFilter) { _, _ in
            guard viewModel.isInitialized else { return }
            Task { await viewModel.loadCurrentSection() }
        }
        .sheet(isPresented: $showNewForeignServerSheet) { newForeignServerSheet }
        .sheet(isPresented: $showNewEventTriggerSheet) { newEventTriggerSheet }
        .sheet(isPresented: $showNewDomainSheet) { newDomainSheet }
        .sheet(isPresented: $showNewCompositeTypeSheet) { newCompositeTypeSheet }
        .sheet(isPresented: $showNewRangeTypeSheet) { newRangeTypeSheet }
        .sheet(isPresented: $showNewCollationSheet) { newCollationSheet }
        .sheet(isPresented: $showNewFTSConfigSheet) { newFTSConfigSheet }
        .sheet(isPresented: $showNewRuleSheet) { newRuleSheet }
        .sheet(isPresented: $showNewTablespaceSheet) { newTablespaceSheet }
        .sheet(isPresented: $showNewAggregateSheet) { newAggregateSheet }
        .sheet(isPresented: $showNewOperatorSheet) { newOperatorSheet }
        .sheet(isPresented: $showNewLanguageSheet) { newLanguageSheet }
        .sheet(isPresented: $showNewCastSheet) { newCastSheet }
    }

    // MARK: - Toolbar

    private var sectionPicker: some View {
        HStack(spacing: SpacingTokens.sm) {
            Picker(selection: $viewModel.selectedSection) {
                ForEach(PostgresAdvancedObjectsViewModel.Section.allCases, id: \.self) { section in
                    Text(section.rawValue).tag(section)
                }
            } label: { EmptyView() }
            .pickerStyle(.menu)
            .frame(maxWidth: 180)

            if sectionUsesSchemaFilter {
                Picker("Schema", selection: $viewModel.schemaFilter) {
                    ForEach(viewModel.availableSchemas, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 160)
            }

            if viewModel.isLoadingCurrentSection {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private var addButton: some View {
        Button { presentNewSheet() } label: {
            Label("Add", systemImage: "plus")
        }
        .controlSize(.small)
        .buttonStyle(.bordered)
    }

    // MARK: - Content

    private var sectionUsesSchemaFilter: Bool {
        switch viewModel.selectedSection {
        case .domains, .compositeTypes, .rangeTypes, .collations, .ftsConfig, .rules, .aggregates, .operators:
            return true
        case .foreignData, .eventTriggers, .tablespaces, .languages, .casts:
            return false
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        VStack(spacing: 0) {
            switch viewModel.selectedSection {
            case .foreignData:
                PostgresFDWSection(viewModel: viewModel, onCreate: { presentNewSheet() })
            case .eventTriggers:
                PostgresEventTriggersSection(viewModel: viewModel, onCreate: { presentNewSheet() })
            case .domains:
                PostgresDomainsSection(viewModel: viewModel, onCreate: { presentNewSheet() })
            case .compositeTypes:
                PostgresCompositeTypesSection(viewModel: viewModel, onCreate: { presentNewSheet() })
            case .rangeTypes:
                PostgresRangeTypesSection(viewModel: viewModel, onCreate: { presentNewSheet() })
            case .collations:
                PostgresCollationsSection(viewModel: viewModel, onCreate: { presentNewSheet() })
            case .ftsConfig:
                PostgresFTSConfigSection(viewModel: viewModel, onCreate: { presentNewSheet() })
            case .rules:
                PostgresRulesSection(viewModel: viewModel, onCreate: { presentNewSheet() })
            case .tablespaces:
                PostgresTablespacesSection(viewModel: viewModel, onCreate: { presentNewSheet() })
            case .aggregates:
                PostgresAggregatesSection(viewModel: viewModel, onCreate: { presentNewSheet() })
            case .operators:
                PostgresOperatorsSection(viewModel: viewModel, onCreate: { presentNewSheet() })
            case .languages:
                PostgresLanguagesSection(viewModel: viewModel, onCreate: { presentNewSheet() })
            case .casts:
                PostgresCastsSection(viewModel: viewModel, onCreate: { presentNewSheet() })
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Sheet Presentation

    private func presentNewSheet() {
        switch viewModel.selectedSection {
        case .foreignData: showNewForeignServerSheet = true
        case .eventTriggers: showNewEventTriggerSheet = true
        case .domains: showNewDomainSheet = true
        case .compositeTypes: showNewCompositeTypeSheet = true
        case .rangeTypes: showNewRangeTypeSheet = true
        case .collations: showNewCollationSheet = true
        case .ftsConfig: showNewFTSConfigSheet = true
        case .rules: showNewRuleSheet = true
        case .tablespaces: showNewTablespaceSheet = true
        case .aggregates: showNewAggregateSheet = true
        case .operators: showNewOperatorSheet = true
        case .languages: showNewLanguageSheet = true
        case .casts: showNewCastSheet = true
        }
    }

    private func dismissAndReload(_ binding: Binding<Bool>) {
        binding.wrappedValue = false
        Task { await viewModel.loadCurrentSection() }
    }

    // MARK: - Sheets

    private var newForeignServerSheet: some View {
        NewForeignServerSheet(viewModel: viewModel) { dismissAndReload($showNewForeignServerSheet) }
    }

    private var newEventTriggerSheet: some View {
        NewEventTriggerSheet(viewModel: viewModel) { dismissAndReload($showNewEventTriggerSheet) }
    }

    private var newDomainSheet: some View {
        NewDomainSheet(viewModel: viewModel) { dismissAndReload($showNewDomainSheet) }
    }

    private var newCompositeTypeSheet: some View {
        NewCompositeTypeSheet(viewModel: viewModel) { dismissAndReload($showNewCompositeTypeSheet) }
    }

    private var newRangeTypeSheet: some View {
        NewRangeTypeSheet(viewModel: viewModel) { dismissAndReload($showNewRangeTypeSheet) }
    }

    private var newCollationSheet: some View {
        NewCollationSheet(viewModel: viewModel) { dismissAndReload($showNewCollationSheet) }
    }

    private var newFTSConfigSheet: some View {
        NewFTSConfigSheet(viewModel: viewModel) { dismissAndReload($showNewFTSConfigSheet) }
    }

    private var newRuleSheet: some View {
        NewRuleSheet(viewModel: viewModel) { dismissAndReload($showNewRuleSheet) }
    }

    private var newTablespaceSheet: some View {
        NewTablespaceSheet(viewModel: viewModel) { dismissAndReload($showNewTablespaceSheet) }
    }

    private var newAggregateSheet: some View {
        NewAggregateSheet(viewModel: viewModel) { dismissAndReload($showNewAggregateSheet) }
    }

    private var newOperatorSheet: some View {
        NewOperatorSheet(viewModel: viewModel) { dismissAndReload($showNewOperatorSheet) }
    }

    private var newLanguageSheet: some View {
        NewLanguageSheet(viewModel: viewModel) { dismissAndReload($showNewLanguageSheet) }
    }

    private var newCastSheet: some View {
        NewCastSheet(viewModel: viewModel) { dismissAndReload($showNewCastSheet) }
    }
}
