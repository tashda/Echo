import SwiftUI

struct MSSQLMaintenanceView: View {
    @Bindable var viewModel: MSSQLMaintenanceViewModel
    @Environment(AppState.self) private var appState

    @State private var sidebarFraction: CGFloat = 0.18

    var body: some View {
        Group {
            if !viewModel.isInitialized {
                TabInitializingPlaceholder(
                    icon: "wrench.and.screwdriver",
                    title: "Initializing Maintenance",
                    subtitle: "Loading database health data\u{2026}"
                )
            } else {
                NativeSplitView(
                    isVertical: true,
                    firstMinFraction: 0.12,
                    secondMinFraction: 0.60,
                    fraction: $sidebarFraction
                ) {
                    maintenanceSidebar
                        .frame(minWidth: 180, maxWidth: 280)
                } second: {
                    maintenanceContent
                }
            }
        }
        .task(id: viewModel.selectedSection) {
            if viewModel.isInitialized {
                await viewModel.loadCurrentSection()
            }
        }
        .task(id: viewModel.selectedDatabase) {
            if viewModel.isInitialized {
                await viewModel.loadCurrentSection()
            }
        }
        .task {
            await viewModel.loadDatabases()
        }
    }

    private var maintenanceSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            databasePicker
                .padding(.horizontal, SpacingTokens.md)
                .padding(.top, SpacingTokens.md)
                .padding(.bottom, SpacingTokens.sm)

            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                    ForEach(MSSQLMaintenanceViewModel.MaintenanceSection.allCases) { section in
                        sidebarRow(section)
                    }
                }
                .padding(.horizontal, SpacingTokens.xs)
            }
        }
        .background(ColorTokens.Background.secondary.opacity(0.3))
    }

    private var databasePicker: some View {
        Picker("", selection: Binding(
            get: { viewModel.selectedDatabase ?? "" },
            set: { db in Task { await viewModel.selectDatabase(db) } }
        )) {
            if viewModel.selectedDatabase == nil {
                Text("Select Database...").tag("")
            }
            ForEach(viewModel.databaseList, id: \.self) { db in
                Text(db).tag(db)
            }
        }
        .pickerStyle(.menu)
        .controlSize(.regular)
        .labelsHidden()
        .frame(maxWidth: .infinity)
    }

    private func sidebarRow(_ section: MSSQLMaintenanceViewModel.MaintenanceSection) -> some View {
        let isSelected = viewModel.selectedSection == section
        
        return Button {
            viewModel.selectedSection = section
        } label: {
            HStack(spacing: SpacingTokens.sm) {
                Image(systemName: section.icon)
                    .font(.body)
                    .frame(width: 18, alignment: .center)
                
                Text(section.rawValue)
                    .font(TypographyTokens.standard)
                
                Spacer()
            }
            .padding(.horizontal, SpacingTokens.sm)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .background(isSelected ? ColorTokens.accent.opacity(0.15) : Color.clear)
            .cornerRadius(6)
            .foregroundStyle(isSelected ? ColorTokens.accent : ColorTokens.Text.primary)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var maintenanceContent: some View {
        VStack(spacing: 0) {
            switch viewModel.selectedSection {
            case .health:
                MSSQLMaintenanceHealthView(viewModel: viewModel)
            case .indexes:
                MSSQLMaintenanceIndexesView(viewModel: viewModel)
            case .backups:
                MSSQLMaintenanceBackupsView(viewModel: viewModel)
            case .extendedEvents:
                if let xeVM = viewModel.extendedEventsVM {
                    ExtendedEventsView(viewModel: xeVM)
                } else {
                    Text("Extended Events not available")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
