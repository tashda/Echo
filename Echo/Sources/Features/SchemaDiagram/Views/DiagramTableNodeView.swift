import SwiftUI
import EchoSense

struct SchemaDiagramNodeView: View {
    @Bindable var node: SchemaDiagramNodeModel
    let zoom: CGFloat
    let palette: DiagramPalette
    @Binding var isDraggingNode: Bool
    let onPositionCommitted: () -> Void

    @State private var dragStartPosition: CGPoint?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
                .foregroundStyle(palette.nodeBorder)
            columnsList
        }
        .frame(minWidth: 200)
        .fixedSize(horizontal: true, vertical: false)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.nodeBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(palette.nodeBorder, lineWidth: 1)
        )
        .shadow(color: palette.nodeShadow, radius: 16, x: 0, y: 6)
        .highPriorityGesture(dragGesture)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            if let db = node.databaseName {
                Text(db)
                    .font(TypographyTokens.detail.weight(.medium))
                    .foregroundStyle(palette.headerSubtitle.opacity(0.7))
            }
            Text(node.name)
                .font(TypographyTokens.prominent.weight(.semibold))
                .foregroundStyle(palette.headerTitle)
            Text(node.schema)
                .font(TypographyTokens.detail.weight(.medium))
                .foregroundStyle(palette.headerSubtitle)
        }
        .padding(.horizontal, SpacingTokens.sm2)
        .padding(.vertical, SpacingTokens.xs2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.headerBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(palette.headerBorder, lineWidth: 1)
                )
        )
    }

    private var columnsList: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            ForEach(node.columns) { column in
                ColumnRow(nodeID: node.id, column: column, palette: palette)
            }
        }
        .padding(.horizontal, SpacingTokens.sm2)
        .padding(.vertical, SpacingTokens.sm)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if dragStartPosition == nil {
                    dragStartPosition = node.position
                }
                if !isDraggingNode {
                    isDraggingNode = true
                }
                let origin = dragStartPosition ?? node.position
                // Clamp the zoom divisor to prevent excessive movement at low zoom
                let effectiveZoom = max(zoom, 0.5)
                let delta = CGSize(
                    width: value.translation.width / effectiveZoom,
                    height: value.translation.height / effectiveZoom
                )
                let newPosition = CGPoint(
                    x: origin.x + delta.width,
                    y: origin.y + delta.height
                )
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    node.position = newPosition
                }
            }
            .onEnded { value in
                let origin = dragStartPosition ?? node.position
                let effectiveZoom = max(zoom, 0.5)
                let delta = CGSize(
                    width: value.translation.width / effectiveZoom,
                    height: value.translation.height / effectiveZoom
                )
                let newPosition = CGPoint(
                    x: origin.x + delta.width,
                    y: origin.y + delta.height
                )
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    node.position = newPosition
                }
                dragStartPosition = nil
                isDraggingNode = false
                onPositionCommitted()
            }
    }
}

private struct ColumnRow: View {
    let nodeID: String
    let column: SchemaDiagramColumn
    let palette: DiagramPalette

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: columnIconName)
                .font(TypographyTokens.label.weight(.medium))
                .foregroundStyle(iconColor)
                .frame(width: 12)
            Text(column.name)
                .lineLimit(1)
                .font(TypographyTokens.caption2.weight(column.isPrimaryKey ? .semibold : .regular))
                .foregroundStyle(palette.columnText)
            Spacer(minLength: SpacingTokens.lg)
            if !column.isNullable {
                Text("NN")
                    .font(TypographyTokens.detail.weight(.medium))
                    .foregroundStyle(palette.accent.opacity(0.6))
            }
            Text(column.dataType)
                .lineLimit(1)
                .font(TypographyTokens.detail)
                .foregroundStyle(palette.columnDetail)
        }
        .padding(.vertical, SpacingTokens.xxs)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(columnHighlightColor)
        )
        .anchorPreference(key: DiagramColumnAnchorPreferenceKey.self, value: .bounds) {
            [DiagramColumnAnchor(nodeID: nodeID, columnName: column.name, bounds: $0)]
        }
    }

    private var columnIconName: String {
        if column.isPrimaryKey {
            return "key.fill"
        }
        if column.isForeignKey {
            return "arrow.turn.down.right"
        }
        return "circle.fill"
    }

    private var iconColor: Color {
        if column.isPrimaryKey || column.isForeignKey {
            return palette.accent
        }
        return palette.columnDetail
    }

    private var columnHighlightColor: Color {
        (column.isPrimaryKey || column.isForeignKey) ? palette.columnHighlight : Color.clear
    }
}

// MARK: - Index Node (separate bubble)

struct SchemaDiagramIndexNodeView: View {
    let index: SchemaDiagramIndex
    let palette: DiagramPalette
    var position: CGPoint
    let zoom: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            HStack(spacing: SpacingTokens.xs) {
                Image(systemName: index.isUnique ? "list.bullet.rectangle.fill" : "list.bullet.rectangle")
                    .font(TypographyTokens.detail.weight(.medium))
                    .foregroundStyle(palette.accent.opacity(0.7))
                Text(index.name)
                    .lineLimit(1)
                    .font(TypographyTokens.detail.weight(.semibold))
                    .foregroundStyle(palette.columnText)
                if index.isUnique {
                    Text("UQ")
                        .font(TypographyTokens.detail.weight(.bold))
                        .foregroundStyle(palette.accent.opacity(0.6))
                }
            }
            Text(index.columns.joined(separator: ", "))
                .lineLimit(2)
                .font(TypographyTokens.detail)
                .foregroundStyle(palette.columnDetail)
        }
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.vertical, SpacingTokens.xs2)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(palette.nodeBackground.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(palette.nodeBorder.opacity(0.6), lineWidth: 0.5)
        )
        .shadow(color: palette.nodeShadow.opacity(0.5), radius: 6, x: 0, y: 3)
        .fixedSize()
    }
}
