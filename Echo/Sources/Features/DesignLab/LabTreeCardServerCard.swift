#if DEBUG
import SwiftUI

/// One server on the real workspace card, with its header and rows in the given style.
struct LabTreeServerCard: View {
    let server: LabTreeServer
    let style: LabTreeCardStyle
    let look: LabTreeLook
    @Binding var expanded: Set<String>
    @Binding var selected: String?

    var body: some View {
        let spec = style.spec
        let rows = LabTreeFlattening.rows(for: server, look: look, expanded: expanded)
        let selectedRow = rows.first { $0.id == selected }
        let path = Set(selectedRow?.ancestors ?? [])

        VStack(alignment: .leading, spacing: 0) {
            LabTreeCardHeader(server: server, header: spec.header)
            ForEach(rows) { row in
                switch row.kind {
                case .section:
                    LabTreeSectionRow(row: row, spec: spec, isExpanded: expanded.contains(row.id)) { toggle(row.id) }
                case .node:
                    LabTreeCardRow(
                        row: row,
                        spec: spec,
                        look: look,
                        serverColor: server.color,
                        isExpanded: expanded.contains(row.id),
                        isSelected: selected == row.id,
                        isOnPath: path.contains(row.id),
                        accentGuideOwner: selectedRow?.guideOwners.last,
                        onTap: { tap(row) }
                    )
                }
            }
        }
        .padding(.bottom, 4)
        .workspaceCard()
    }

    private func tap(_ row: LabFlatRow) {
        selected = row.id
        if row.hasChildren { toggle(row.id) }
    }

    private func toggle(_ id: String) {
        withAnimation(LabSpeed.standard.spring()) {
            if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) }
        }
    }
}

/// A server folder drawn as a Finder-style heading (the "Sections" control).
struct LabTreeSectionRow: View {
    let row: LabFlatRow
    let spec: LabTreeSpec
    let isExpanded: Bool
    let onTap: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            Text(row.node.title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            if let count = row.node.count ?? (row.node.children.isEmpty ? nil : row.node.children.count) {
                Text("\(count)").font(.system(size: 11).monospacedDigit()).foregroundStyle(.tertiary)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.tertiary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .opacity(isHovering || !isExpanded ? 1 : 0)
        }
        .padding(.leading, spec.outerPadding + spec.innerPadding)
        .padding(.trailing, spec.outerPadding + 8)
        .padding(.top, 8)
        .frame(height: 30)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture(perform: onTap)
    }
}

/// The server's name at the top of its card, in each style's treatment.
struct LabTreeCardHeader: View {
    let server: LabTreeServer
    let header: LabTreeSpec.Header

    var body: some View {
        Group {
            switch header {
            case .today:
                Text(server.name).font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12).padding(.bottom, 2)
            case .boldWithVersion:
                HStack(alignment: .firstTextBaseline) {
                    Text(server.name).font(.system(size: 13, weight: .bold))
                    Spacer(minLength: 4)
                    Text(server.product).font(.system(size: 11)).foregroundStyle(.tertiary)
                }
                .padding(.top, 12).padding(.bottom, 4)
            case .monogram:
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(server.color.gradient)
                        .frame(width: 24, height: 24)
                        .overlay { Text(server.monogram).font(.system(size: 10, weight: .bold)).foregroundStyle(.white) }
                    VStack(alignment: .leading, spacing: 0) {
                        Text(server.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                        Text("\(server.product) · \(server.host)").font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, 10).padding(.bottom, 6)
            case .compact:
                HStack(alignment: .firstTextBaseline) {
                    Text(server.name).font(.system(size: 12, weight: .semibold))
                    Spacer(minLength: 4)
                    Text(server.product).font(.system(size: 10)).foregroundStyle(.tertiary)
                }
                .padding(.top, 9).padding(.bottom, 3)
            case .dot:
                HStack(spacing: 7) {
                    Circle().fill(server.color).frame(width: 8, height: 8)
                    Text(server.name).font(.system(size: 13, weight: .bold))
                    Spacer(minLength: 0)
                }
                .padding(.top, 12).padding(.bottom, 4)
            }
        }
        .padding(.horizontal, 12)
    }
}
#endif
