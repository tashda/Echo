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
    
    /// The page's Add as the tab's special button in the window toolbar (round 37.5).
    internal var sectionAddItem: TabToolbarItem? {
        switch selectedSection {
        case .columns:
            TabToolbarItem(id: "addColumn", title: "Add Column", symbol: "plus") { presentNewColumn() }
        case .indexes:
            TabToolbarItem(id: "addIndex", title: "Add Index", symbol: "plus") { presentNewIndex() }
        case .constraints:
            TabToolbarItem(id: "addConstraint", title: "Add", symbol: "plus", menu: constraintItems)
        case .relations:
            TabToolbarItem(id: "addForeignKey", title: "Add Foreign Key", symbol: "plus") { presentNewForeignKey() }
        case .partitions, .inheritance:
            nil
        }
    }

    private var constraintItems: [TabToolbarItem] {
        var items: [TabToolbarItem] = []
        if viewModel.primaryKey == nil {
            items.append(TabToolbarItem(id: "primaryKey", title: "Primary Key", symbol: "key") { presentPrimaryKeyEditor(isNew: true) })
        }
        items.append(TabToolbarItem(id: "unique", title: "Unique Constraint", symbol: "checkmark.shield") { presentNewUniqueConstraint() })
        items.append(TabToolbarItem(id: "check", title: "Check Constraint", symbol: "checkmark.rectangle.stack") { presentNewCheckConstraint() })
        return items
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
