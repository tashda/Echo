import SwiftUI
import MySQLKit

struct ServerPropertiesView: View {
    @Bindable var viewModel: ServerPropertiesViewModel
    @Bindable var panelState: BottomPanelState
    @Environment(TabStore.self) private var tabStore
    @Environment(ProjectStore.self) private var projectStore

    @State private var showVariableEditor = false

    var body: some View {
        Group {
            if viewModel.session is MySQLSession {
                mysqlContent
            } else if viewModel.session is PostgresSession {
                postgresContent
            } else {
                placeholder
            }
        }
        .background(ColorTokens.Background.primary)
        .task {
            viewModel.setPanelState(panelState)
            await viewModel.initialize()
        }
        .onChange(of: viewModel.selectedSection) { _, _ in
            guard viewModel.isInitialized else { return }
            Task { await viewModel.loadCurrentSection() }
        }
        .onChange(of: viewModel.searchText) { _, _ in
            guard viewModel.selectedSection == .variables || viewModel.selectedSection == .status else { return }
        }
        .sheet(isPresented: $showVariableEditor) {
            if let variable = viewModel.selectedVariable {
                MySQLServerVariableEditorSheet(variable: variable) { value in
                    Task { await viewModel.setSelectedVariable(to: value) }
                } onDismiss: {
                    showVariableEditor = false
                }
            }
        }
    }

    private var mysqlContent: some View {
        MaintenanceTabFrame(
            panelState: panelState,
            connectionText: tabStore.activeTab?.connection.connectionName ?? "Server",
            isInitialized: viewModel.isInitialized,
            statusBubble: viewModel.isLoading ? .init(label: "Loading\u{2026}", tint: .blue, isPulsing: true) : nil
        ) {
            HStack(spacing: SpacingTokens.md) {
                Picker(selection: $viewModel.selectedSection) {
                    ForEach(ServerPropertiesViewModel.Section.allCases, id: \.self) { section in
                        Text(section.rawValue).tag(section)
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 560)
            }
        } content: {
            switch viewModel.selectedSection {
            case .overview:
                propertiesTable(viewModel.overviewItems)
            case .control:
                MySQLServerControlSection(
                    viewModel: viewModel,
                    customToolPath: projectStore.globalSettings.mysqlToolCustomPath
                )
            case .variables:
                MySQLServerVariablesSection(
                    viewModel: viewModel,
                    showVariableEditor: $showVariableEditor
                )
            case .status:
                MySQLServerStatusVariablesSection(viewModel: viewModel)
            case .logs:
                MySQLServerLogsView(viewModel: viewModel)
            case .configuration:
                MySQLServerConfigurationView(viewModel: viewModel)
            }
        }
    }

    private func propertiesTable(
        _ items: [ServerPropertiesViewModel.PropertyItem],
        selection: Binding<Set<String>>? = nil
    ) -> some View {
        Group {
            if let selection {
                Table(items, selection: selection) {
                    TableColumn("Property") { item in
                        Text(item.name)
                            .font(TypographyTokens.Table.name)
                    }
                    .width(min: 180, ideal: 240)

                    TableColumn("Value") { item in
                        Text(item.value)
                            .font(TypographyTokens.Table.secondaryName)
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .textSelection(.enabled)
                    }
                    .width(min: 240, ideal: 520)
                }
            } else {
                Table(items) {
                    TableColumn("Property") { item in
                        Text(item.name)
                            .font(TypographyTokens.Table.name)
                    }
                    .width(min: 180, ideal: 240)

                    TableColumn("Value") { item in
                        Text(item.value)
                            .font(TypographyTokens.Table.secondaryName)
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .textSelection(.enabled)
                    }
                    .width(min: 240, ideal: 520)
                }
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
    }

    private var postgresContent: some View {
        let availableSections: [ServerPropertiesViewModel.Section] = [.overview, .control, .variables, .status]
        return MaintenanceTabFrame(
            panelState: panelState,
            connectionText: tabStore.activeTab?.connection.connectionName ?? "Server",
            isInitialized: viewModel.isInitialized,
            statusBubble: viewModel.isLoading ? .init(label: "Loading\u{2026}", tint: .blue, isPulsing: true) : nil
        ) {
            HStack(spacing: SpacingTokens.md) {
                Picker(selection: $viewModel.selectedSection) {
                    ForEach(availableSections, id: \.self) { section in
                        Text(section.rawValue).tag(section)
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 400)
            }
        } content: {
            switch viewModel.selectedSection {
            case .overview:
                propertiesTable(viewModel.overviewItems)
            case .control:
                PostgresServerControlSection(
                    viewModel: viewModel,
                    customToolPath: projectStore.globalSettings.pgToolCustomPath
                )
            case .variables:
                propertiesTable(viewModel.filteredVariables, selection: $viewModel.selectedVariableID)
            case .status:
                propertiesTable(viewModel.filteredStatusVariables)
            default:
                EmptyView()
            }
        }
    }

    private var placeholder: some View {
        ContentUnavailableView {
            Label("Server Properties", systemImage: "gearshape.2")
        } description: {
            Text("Server-level properties and configuration are coming soon for this database engine.")
        }
    }
}
