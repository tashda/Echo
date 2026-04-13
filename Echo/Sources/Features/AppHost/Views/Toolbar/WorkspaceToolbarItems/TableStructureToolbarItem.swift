import SwiftUI

/// Toolbar controls for Structure tab — shown only when active tab is a Structure editor.
/// Provides Add, Script, and Apply buttons with dynamic visibility based on pending changes.
struct TableStructureToolbarItem: View {
    private struct ApplyReviewPresentation: Identifiable {
        let id = UUID()
        let tableName: String
        let statements: [String]
    }

    @Environment(TabStore.self) private var tabStore
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(AppState.self) private var appState
    @State private var applyReview: ApplyReviewPresentation?

    var body: some View {
        if let tab = tabStore.activeTab, let vm = tab.structureEditor {
            structureControls(viewModel: vm, tab: tab)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func structureControls(viewModel: TableStructureEditorViewModel, tab: WorkspaceTab) -> some View {
        HStack(spacing: SpacingTokens.sm) {
            addButton
                .glassEffect(.regular.interactive())

            if viewModel.hasPendingChanges {
                HStack(spacing: SpacingTokens.none) {
                    scriptButton(viewModel: viewModel)
                    applyButton(viewModel: viewModel, tab: tab)
                }
                .glassEffect(.regular.interactive())
            }
        }
        .sheet(item: $applyReview) { review in
            StructureApplyReviewSheet(
                tableName: review.tableName,
                statements: review.statements
            ) {
                await applyChanges(viewModel: viewModel, tab: tab)
            }
        }
    }

    private var addButton: some View {
        Menu {
            Button {
                if let vm = tabStore.activeTab?.structureEditor {
                    vm.requestAddAction(.column, section: .columns)
                }
            } label: {
                Label("Add Column", systemImage: "tablecells")
            }

            Button {
                if let vm = tabStore.activeTab?.structureEditor {
                    vm.requestAddAction(.index, section: .indexes)
                }
            } label: {
                Label("Add Index", systemImage: "list.bullet.rectangle")
            }

            Divider()

            Button {
                if let vm = tabStore.activeTab?.structureEditor {
                    vm.requestAddAction(.foreignKey, section: .relations)
                }
            } label: {
                Label("Add Foreign Key", systemImage: "link")
            }

            Button {
                if let vm = tabStore.activeTab?.structureEditor {
                    vm.requestAddAction(.uniqueConstraint, section: .constraints)
                }
            } label: {
                Label("Add Unique Constraint", systemImage: "checkmark.shield")
            }

            Button {
                if let vm = tabStore.activeTab?.structureEditor {
                    vm.requestAddAction(.checkConstraint, section: .constraints)
                }
            } label: {
                Label("Add Check Constraint", systemImage: "checkmark.rectangle.stack")
            }
        } label: {
            Label("Add", systemImage: "plus")
                .labelStyle(.iconOnly)
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .help("Add item to table structure")
        .accessibilityLabel("Add")
    }

    private func scriptButton(viewModel: TableStructureEditorViewModel) -> some View {
        Button {
            let statements = viewModel.generateStatements()
            guard !statements.isEmpty else { return }
            appState.showStructureScriptPreview(statements: statements)
        } label: {
            Label("Script", systemImage: "doc.text")
        }
        .labelStyle(.iconOnly)
        .help("View generated SQL script")
        .accessibilityLabel("View script")
        .disabled(viewModel.isApplying)
    }

    private func applyButton(viewModel: TableStructureEditorViewModel, tab: WorkspaceTab) -> some View {
        Button {
            let statements = viewModel.generateStatements()
            guard !statements.isEmpty else { return }
            applyReview = ApplyReviewPresentation(tableName: viewModel.tableName, statements: statements)
        } label: {
            Label("Apply", systemImage: "checkmark")
        }
        .labelStyle(.iconOnly)
        .help("Apply changes to database")
        .accessibilityLabel("Apply changes")
        .disabled(viewModel.isApplying)
        .keyboardShortcut(.return, modifiers: [.command, .shift])
    }

    private func applyChanges(viewModel: TableStructureEditorViewModel, tab: WorkspaceTab) async -> Bool {
        await viewModel.applyChanges()

        if let error = viewModel.lastError {
            environmentState.notificationEngine?.post(
                category: .generalError,
                message: error
            )
            return false
        } else if viewModel.lastSuccessMessage != nil {
            environmentState.notificationEngine?.post(
                category: .generalSuccess,
                message: "Structure of \(viewModel.tableName) updated"
            )
            await environmentState.refreshDatabaseStructure(
                for: tab.connectionSessionID,
                scope: .selectedDatabase,
                databaseOverride: tab.connection.database.isEmpty ? nil : tab.connection.database
            )
            return true
        }

        return false
    }
}
