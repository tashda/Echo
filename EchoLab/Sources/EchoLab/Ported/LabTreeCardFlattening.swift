import SwiftUI

/// One visible line of a server card.
struct LabFlatRow: Identifiable {
    enum Kind { case node, section }
    enum SchemaDisplay { case none, prefix, trailing }

    let node: LabTreeNode
    let kind: Kind
    let depth: Int
    /// Every ancestor, outermost first (sections included).
    let ancestors: [String]
    /// The ancestor that owns each indent guide column, one per depth level.
    let guideOwners: [String]
    let schemaDisplay: SchemaDisplay

    var id: String { node.id }
    var isContainer: Bool { !node.children.isEmpty || node.count != nil }
    var hasChildren: Bool { !node.children.isEmpty }
}

/// Turns a server's blueprint into visible rows, applying the page's structure controls.
enum LabTreeFlattening {
    static func rows(for server: LabTreeServer, look: LabTreeLook, expanded: Set<String>) -> [LabFlatRow] {
        var rows: [LabFlatRow] = []
        switch look.topLevel {
        case .folders:
            append(server.children, depth: 0, ancestors: [], guideOwners: [], display: .none, look: look, expanded: expanded, into: &rows)
        case .sections:
            // Server folders become headings; their children start at the left edge.
            for section in server.children {
                rows.append(LabFlatRow(node: section, kind: .section, depth: 0, ancestors: [], guideOwners: [], schemaDisplay: .none))
                guard expanded.contains(section.id) else { continue }
                let (children, display) = presented(section, look: look)
                append(children, depth: 0, ancestors: [section.id], guideOwners: [], display: display, look: look, expanded: expanded, into: &rows)
            }
        }
        return rows
    }

    private static func append(
        _ nodes: [LabTreeNode],
        depth: Int,
        ancestors: [String],
        guideOwners: [String],
        display: LabFlatRow.SchemaDisplay,
        look: LabTreeLook,
        expanded: Set<String>,
        into rows: inout [LabFlatRow]
    ) {
        for node in nodes {
            rows.append(LabFlatRow(node: node, kind: .node, depth: depth, ancestors: ancestors, guideOwners: guideOwners, schemaDisplay: node.schema == nil ? .none : display))
            guard expanded.contains(node.id), !node.children.isEmpty else { continue }
            let (children, childDisplay) = presented(node, look: look)
            append(children, depth: depth + 1, ancestors: ancestors + [node.id], guideOwners: guideOwners + [node.id], display: childDisplay, look: look, expanded: expanded, into: &rows)
        }
    }

    /// A folder's children as shown: grouped under schema rows when asked and there is more than
    /// one schema; otherwise the objects, with the schema shown only where it tells you something.
    private static func presented(_ node: LabTreeNode, look: LabTreeLook) -> ([LabTreeNode], LabFlatRow.SchemaDisplay) {
        var schemas: [String] = []
        for child in node.children {
            if let schema = child.schema, !schemas.contains(schema) { schemas.append(schema) }
        }
        guard !schemas.isEmpty else { return (node.children, .none) }
        let isMixed = schemas.count > 1
        switch look.schema {
        case .prefix:
            return (node.children, .prefix)
        case .trailing:
            return (node.children, isMixed ? .trailing : .none)
        case .groups:
            guard isMixed else { return (node.children, .none) }
            let groups = schemas.map { schema in
                let members = node.children.filter { $0.schema == schema }
                return LabTreeNode(id: "\(node.id)#\(schema)", title: schema, role: .schema, count: members.count, children: members.map {
                    var member = $0
                    member.schema = nil
                    return member
                })
            }
            return (groups, .none)
        }
    }
}
