import Foundation

extension DiagramBuilder {
    struct PlaceholderAccumulator {
        var columns: [String] = []
        var columnSet: Set<String> = []
        var foreignKeys: [TableStructureDetails.ForeignKey] = []

        mutating func addColumn(_ name: String) {
            guard !name.isEmpty else { return }
            let key = name.lowercased()
            if columnSet.insert(key).inserted {
                columns.append(name)
            }
        }

        mutating func addColumns(_ names: [String]) {
            for name in names {
                addColumn(name)
            }
        }

        mutating func addForeignKey(_ foreignKey: TableStructureDetails.ForeignKey) {
            foreignKeys.append(foreignKey)
        }
    }
}
