import SwiftUI

struct QueryBuilderTableNode: View {
    let table: VisualQueryBuilderViewModel.TableNode
    let zoom: CGFloat
    let onToggleColumn: (String) -> Void
    let onRemove: () -> Void
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(table.name)
                    .font(TypographyTokens.standard.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
                Text(table.alias)
                    .font(TypographyTokens.compact)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, SpacingTokens.xs)
            .padding(.vertical, SpacingTokens.xxs2)
            .background(Color.accentColor.opacity(0.85))

            Divider()

            // Columns
            VStack(alignment: .leading, spacing: 0) {
                ForEach(table.columns, id: \.name) { column in
                    HStack(spacing: SpacingTokens.xs) {
                        Toggle(isOn: Binding(
                            get: { table.selectedColumns.contains(column.name) },
                            set: { _ in onToggleColumn(column.name) }
                        )) {
                            EmptyView()
                        }
                        .toggleStyle(.checkbox)
                        .labelsHidden()

                        if column.isPrimaryKey {
                            Image(systemName: "key.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.yellow)
                        }

                        Text(column.name)
                            .font(TypographyTokens.compact)
                            .foregroundStyle(
                                table.selectedColumns.contains(column.name)
                                ? ColorTokens.Text.primary
                                : ColorTokens.Text.tertiary
                            )
                            .lineLimit(1)

                        Spacer()

                        Text(column.dataType)
                            .font(TypographyTokens.compact)
                            .foregroundStyle(ColorTokens.Text.quaternary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, SpacingTokens.xs)
                    .padding(.vertical, 2)
                }
            }
            .padding(.vertical, SpacingTokens.xxs2)
        }
        .frame(width: 220)
        .background(ColorTokens.Background.primary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(ColorTokens.Separator.secondary, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .contextMenu {
            Button("Select All Columns") { onSelectAll() }
            Button("Deselect All Columns") { onDeselectAll() }
            Divider()
            Button("Remove from Query", role: .destructive) { onRemove() }
        }
    }
}
