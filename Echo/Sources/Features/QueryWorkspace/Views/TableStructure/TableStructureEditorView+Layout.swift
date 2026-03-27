import SwiftUI

extension TableStructureEditorView {

    internal func isSectionEnabled(_ section: TableStructureSection) -> Bool {
        switch section {
        case .partitions:
            return viewModel.partitionsAvailable == true
        case .inheritance:
            return viewModel.inheritanceAvailable == true
        default:
            return true
        }
    }

    internal var header: some View {
        TabSectionToolbar {
            structureSectionPicker
        } controls: {
            sectionAddButton
                .frame(minWidth: 70, alignment: .trailing)
            actionButtons
        }
    }

    private var structureSectionPicker: some View {
        Picker(selection: $selectedSection) {
            ForEach(TableStructureSection.sections(for: viewModel.databaseType)) { section in
                Text(section.displayName).tag(section)
            }
        } label: {
            EmptyView()
        }
        .pickerStyle(.segmented)
        .fixedSize()
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
                activeSheet = .index(IndexEditorPresentation(indexID: newIndex.id))
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

        case .partitions, .inheritance:
            EmptyView()
        }
    }

    internal var content: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading && viewModel.columns.isEmpty {
                TabInitializingPlaceholder(
                    icon: "square.stack.3d.up",
                    title: "Loading Structure",
                    subtitle: "Fetching table details\u{2026}"
                )
            } else {
                Group {
                    switch selectedSection {
                    case .columns:
                        columnsContent

                    case .indexes:
                        indexesContent

                    case .constraints:
                        constraintsContent

                    case .relations:
                        relationsContent

                    case .partitions:
                        if isSectionEnabled(.partitions) {
                            TableStructurePartitionsView(viewModel: viewModel)
                        } else {
                            ContentUnavailableView {
                                Label("No Partitions", systemImage: "square.split.2x2")
                            } description: {
                                Text("This table is not partitioned.")
                            }
                        }

                    case .inheritance:
                        if isSectionEnabled(.inheritance) {
                            TableStructureInheritanceView(viewModel: viewModel)
                        } else {
                            ContentUnavailableView {
                                Label("No Inheritance", systemImage: "arrow.triangle.branch")
                            } description: {
                                Text("This table does not use inheritance.")
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        Button {
            scriptPreviewStatements = viewModel.generateStatements()
            activeSheet = .scriptPreview
        } label: {
            Label("Script", systemImage: "doc.text")
        }
        .controlSize(.small)
        .buttonStyle(.bordered)
        .disabled(!viewModel.hasPendingChanges || viewModel.isApplying)

        if viewModel.isApplying {
            ProgressView()
                .controlSize(.small)
        } else {
            Button {
                applyChanges()
            } label: {
                Label("Apply", systemImage: "checkmark.circle")
            }
            .controlSize(.small)
            .buttonStyle(.bordered)
            .disabled(!viewModel.hasPendingChanges)
            .keyboardShortcut(.return, modifiers: [.command, .shift])
        }
    }
}
