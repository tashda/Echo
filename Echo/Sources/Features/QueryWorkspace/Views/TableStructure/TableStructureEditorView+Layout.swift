import SwiftUI

extension TableStructureEditorView {

    internal var header: some View {
        VStack(spacing: 0) {
            TabSectionToolbar {
                Picker("", selection: $selectedSection) {
                    ForEach(TableStructureSection.allCases) { section in
                        Text(section.displayName).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 400)
            } controls: {
                sectionAddButton
            }

            Divider()
        }
    }

    @ViewBuilder
    private var sectionAddButton: some View {
        switch selectedSection {
        case .columns:
            Button { presentNewColumn() } label: {
                Label("Add", systemImage: "plus")
            }
            .controlSize(.small)
            .buttonStyle(.bordered)

        case .indexes:
            Button {
                let newIndex = viewModel.addIndex()
                activeIndexEditor = IndexEditorPresentation(indexID: newIndex.id)
            } label: {
                Label("Add", systemImage: "plus")
            }
            .controlSize(.small)
            .buttonStyle(.bordered)

        case .constraints:
            Menu {
                if viewModel.primaryKey == nil {
                    Button("Primary Key") { presentPrimaryKeyEditor(isNew: true) }
                }
                Button("Unique Constraint") { presentNewUniqueConstraint() }
                Button("Check Constraint") { presentNewCheckConstraint() }
            } label: {
                Label("Add", systemImage: "plus")
            }
            .controlSize(.small)
            .buttonStyle(.bordered)

        case .relations:
            Button { presentNewForeignKey() } label: {
                Label("Add", systemImage: "plus")
            }
            .controlSize(.small)
            .buttonStyle(.bordered)
        }
    }

    internal var content: some View {
        VStack(spacing: 0) {
            if let message = viewModel.lastError {
                StatusToastView(icon: "exclamationmark.triangle.fill", message: message, style: .error)
                    .padding(.top, SpacingTokens.sm)
            } else if let success = viewModel.lastSuccessMessage {
                StatusToastView(icon: "checkmark.circle.fill", message: success, style: .success)
                    .padding(.top, SpacingTokens.sm)
            }

            if viewModel.isLoading && viewModel.columns.isEmpty {
                Spacer()
                ProgressView("Loading structure\u{2026}")
                    .controlSize(.small)
                Spacer()
            } else {
                switch selectedSection {
                case .columns:
                    columnsContent

                case .indexes:
                    indexesContent

                case .constraints:
                    constraintsContent

                case .relations:
                    relationsContent
                }
            }

            bottomBar
        }
    }

    private var bottomBar: some View {
        HStack(spacing: SpacingTokens.sm) {
            Spacer()

            Button {
                showScriptPreview = true
            } label: {
                Label("Script Changes", systemImage: "doc.text")
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.hasPendingChanges || viewModel.isApplying)

            Button {
                applyChanges()
            } label: {
                if viewModel.isApplying {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("Apply Changes", systemImage: "checkmark.circle")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.hasPendingChanges || viewModel.isApplying)
            .keyboardShortcut(.return, modifiers: [.command, .shift])
        }
        .padding(.horizontal, SpacingTokens.lg)
        .padding(.vertical, SpacingTokens.sm)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}
