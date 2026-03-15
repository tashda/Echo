import Foundation
import SwiftUI

@MainActor
@Observable
final class JsonViewerViewModel {
    let rootNode: JsonOutlineNode
    let rawJSON: String
    let columnName: String

    var searchText: String = "" {
        didSet { rebuildFilteredNodes(); rebuildFlatList() }
    }

    private(set) var expandedNodeIDs: Set<UUID> = []
    private(set) var filteredNodeIDs: Set<UUID>?
    private(set) var flatRows: [FlatRow] = []

    struct FlatRow: Identifiable {
        let id: UUID
        let node: JsonOutlineNode
        let depth: Int
        let parentPath: String
    }

    init(rootNode: JsonOutlineNode, rawJSON: String, columnName: String) {
        self.rootNode = rootNode
        self.rawJSON = rawJSON
        self.columnName = columnName
        // For large JSON, only expand root level to keep init fast
        let nodeCount = Self.estimateNodeCount(rootNode, limit: 500)
        let initialDepth = nodeCount > 200 ? 1 : 2
        expandAll(node: rootNode, maxDepth: initialDepth, currentDepth: 0)
        rebuildFlatList()
    }

    private static func estimateNodeCount(_ node: JsonOutlineNode, limit: Int) -> Int {
        var count = 1
        for child in node.children {
            count += estimateNodeCount(child, limit: limit - count)
            if count >= limit { return count }
        }
        return count
    }

    // MARK: - Expand / Collapse

    func toggle(_ nodeID: UUID) {
        if expandedNodeIDs.contains(nodeID) {
            expandedNodeIDs.remove(nodeID)
        } else {
            expandedNodeIDs.insert(nodeID)
        }
        rebuildFlatList()
    }

    func isExpanded(_ nodeID: UUID) -> Bool {
        expandedNodeIDs.contains(nodeID)
    }

    func expandAll() {
        expandedNodeIDs.removeAll()
        expandAll(node: rootNode, maxDepth: .max, currentDepth: 0)
        rebuildFlatList()
    }

    func collapseAll() {
        expandedNodeIDs.removeAll()
        rebuildFlatList()
    }

    private func expandAll(node: JsonOutlineNode, maxDepth: Int, currentDepth: Int) {
        guard currentDepth < maxDepth, node.hasChildren else { return }
        expandedNodeIDs.insert(node.id)
        for child in node.children {
            expandAll(node: child, maxDepth: maxDepth, currentDepth: currentDepth + 1)
        }
    }

    // MARK: - Flat List

    private func rebuildFlatList() {
        var rows: [FlatRow] = []
        if rootNode.hasChildren {
            for child in rootNode.children {
                appendRows(node: child, depth: 0, parentPath: "$", into: &rows)
            }
        } else {
            rows.append(FlatRow(id: rootNode.id, node: rootNode, depth: 0, parentPath: "$"))
        }
        flatRows = rows
    }

    private func appendRows(node: JsonOutlineNode, depth: Int, parentPath: String, into rows: inout [FlatRow]) {
        guard isVisible(node.id) else { return }
        let nodePath = node.jsonPath(parentPath: parentPath)
        rows.append(FlatRow(id: node.id, node: node, depth: depth, parentPath: parentPath))
        if node.hasChildren && expandedNodeIDs.contains(node.id) {
            for child in node.children {
                appendRows(node: child, depth: depth + 1, parentPath: nodePath, into: &rows)
            }
        }
    }

    // MARK: - Search

    func isVisible(_ nodeID: UUID) -> Bool {
        guard let filtered = filteredNodeIDs else { return true }
        return filtered.contains(nodeID)
    }

    private func rebuildFilteredNodes() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            filteredNodeIDs = nil
            return
        }
        var matched = Set<UUID>()
        collectMatching(node: rootNode, query: query, ancestors: [], matched: &matched)
        filteredNodeIDs = matched

        for id in matched {
            expandedNodeIDs.insert(id)
        }
    }

    private func collectMatching(
        node: JsonOutlineNode,
        query: String,
        ancestors: [UUID],
        matched: inout Set<UUID>
    ) {
        let nodeMatches = nodeMatchesQuery(node, query: query)
        let path = ancestors + [node.id]

        if nodeMatches {
            for id in path { matched.insert(id) }
        }

        for child in node.children {
            collectMatching(node: child, query: query, ancestors: path, matched: &matched)
        }
    }

    private func nodeMatchesQuery(_ node: JsonOutlineNode, query: String) -> Bool {
        if node.title.lowercased().contains(query) { return true }
        if node.subtitle.lowercased().contains(query) { return true }
        return false
    }

    // MARK: - Formatted Output

    private(set) var formattedJSON: String?
    private var formattingTask: Task<Void, Never>?

    func prepareFormattedJSON() {
        guard formattedJSON == nil, formattingTask == nil else { return }
        let raw = rawJSON

        // Small JSON — format synchronously
        if raw.utf8.count < 4_096 {
            formattedJSON = Self.prettyPrint(raw)
            return
        }

        formattingTask = Task {
            let result = await Task.detached(priority: .userInitiated) {
                Self.prettyPrint(raw)
            }.value
            guard !Task.isCancelled else { return }
            formattedJSON = result
        }
    }

    private nonisolated static func prettyPrint(_ raw: String) -> String {
        guard let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed),
              let prettyData = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let pretty = String(data: prettyData, encoding: .utf8) else {
            return raw
        }
        return pretty
    }
}
