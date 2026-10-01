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
    
    @ViewBuilder
    internal var sectionAddButton: some View {
        switch selectedSection {
        case .columns:
            ToolTabPrimaryButton(title: "Add Column", systemImage: "plus") { presentNewColumn() }
        case .indexes:
            ToolTabPrimaryButton(title: "Add Index", systemImage: "plus") { presentNewIndex() }
        case .constraints:
            ToolTabPrimaryMenu(title: "Add", systemImage: "plus") {
                if viewModel.primaryKey == nil {
                    Button("Primary Key") { presentPrimaryKeyEditor(isNew: true) }
                }
                Button("Unique Constraint") { presentNewUniqueConstraint() }
                Button("Check Constraint") { presentNewCheckConstraint() }
            }
        case .relations:
            ToolTabPrimaryButton(title: "Add Foreign Key", systemImage: "plus") { presentNewForeignKey() }
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
}
