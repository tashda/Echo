import SwiftUI

struct StructureApplyReviewSheet: View {
    private struct StatementDescriptor: Identifiable {
        let id = UUID()
        let title: String
        let symbol: String
        let statement: String
    }

    let tableName: String
    let statements: [String]
    let onApply: () async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var isApplying = false
    @State private var errorMessage: String?

    private var descriptors: [StatementDescriptor] {
        statements.map { statement in
            StatementDescriptor(
                title: statementTitle(for: statement),
                symbol: statementSymbol(for: statement),
                statement: statement
            )
        }
    }

    var body: some View {
        SheetLayout(
            title: "Review Changes",
            icon: "list.clipboard",
            subtitle: "Echo will apply \(statements.count) change\(statements.count == 1 ? "" : "s") to \(tableName).",
            primaryAction: "Apply Changes",
            canSubmit: !statements.isEmpty && !isApplying,
            isSubmitting: isApplying,
            errorMessage: errorMessage,
            onSubmit: { await submit() },
            onCancel: { dismiss() }
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.md) {
                    overviewCard

                    ForEach(Array(descriptors.enumerated()), id: \.element.id) { offset, descriptor in
                        statementCard(descriptor, index: offset + 1)
                    }
                }
                .padding(SpacingTokens.lg)
            }
            .background(ColorTokens.Background.secondary.opacity(0.35))
        }
        .frame(minWidth: 700, idealWidth: 820, minHeight: 480, idealHeight: 620)
    }

    private var overviewCard: some View {
        HStack(spacing: SpacingTokens.sm) {
            Image(systemName: "server.rack")
                .font(TypographyTokens.prominent)
                .foregroundStyle(ColorTokens.Status.info)

            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                Text(tableName)
                    .font(TypographyTokens.prominent.weight(.semibold))
                Text("Review the exact SQL below before Echo sends it to the server.")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }

            Spacer()

            CountBadge(count: statements.count, tint: ColorTokens.Status.info, opacity: 0.12)
        }
        .padding(SpacingTokens.md)
        .background(ColorTokens.Background.primary, in: RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.medium, style: .continuous)
                .strokeBorder(ColorTokens.Text.primary.opacity(0.08))
        }
    }

    private func statementCard(_ descriptor: StatementDescriptor, index: Int) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            HStack(spacing: SpacingTokens.xs) {
                Image(systemName: descriptor.symbol)
                    .font(TypographyTokens.standard)
                    .foregroundStyle(ColorTokens.Status.info)

                Text("\(index). \(descriptor.title)")
                    .font(TypographyTokens.standard.weight(.semibold))
                    .foregroundStyle(ColorTokens.Text.primary)

                Spacer()
            }

            Text(descriptor.statement)
                .font(TypographyTokens.code)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SpacingTokens.md)
                .background(ColorTokens.Background.secondary.opacity(0.45), in: RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.small, style: .continuous))
        }
        .padding(SpacingTokens.md)
        .background(ColorTokens.Background.primary, in: RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.medium, style: .continuous)
                .strokeBorder(ColorTokens.Text.primary.opacity(0.08))
        }
    }

    private func submit() async {
        isApplying = true
        errorMessage = nil
        let didApply = await onApply()
        isApplying = false

        if didApply {
            dismiss()
        } else {
            errorMessage = "Failed to apply the reviewed changes."
        }
    }

    private func statementTitle(for statement: String) -> String {
        let uppercased = statement.uppercased()

        if uppercased.contains(" ADD COLUMN ") { return "Add Column" }
        if uppercased.contains(" DROP COLUMN ") { return "Drop Column" }
        if uppercased.contains(" ALTER COLUMN ") { return "Alter Column" }
        if uppercased.contains(" RENAME COLUMN ") || uppercased.contains("SP_RENAME") { return "Rename Column" }
        if uppercased.contains("CREATE") && uppercased.contains("INDEX") { return "Create Index" }
        if uppercased.contains("DROP INDEX") { return "Drop Index" }
        if uppercased.contains("PRIMARY KEY") { return "Primary Key Change" }
        if uppercased.contains("FOREIGN KEY") { return "Foreign Key Change" }
        if uppercased.contains("CHECK") && uppercased.contains("CONSTRAINT") { return "Check Constraint Change" }
        if uppercased.contains("UNIQUE") && uppercased.contains("CONSTRAINT") { return "Unique Constraint Change" }
        if uppercased.contains("ADD CONSTRAINT") { return "Add Constraint" }
        if uppercased.contains("DROP CONSTRAINT") { return "Drop Constraint" }
        return "Schema Change"
    }

    private func statementSymbol(for statement: String) -> String {
        let uppercased = statement.uppercased()

        if uppercased.contains("INDEX") { return "list.bullet.rectangle" }
        if uppercased.contains("FOREIGN KEY") { return "link" }
        if uppercased.contains("PRIMARY KEY") { return "key" }
        if uppercased.contains("CHECK") || uppercased.contains("UNIQUE") || uppercased.contains("CONSTRAINT") {
            return "checkmark.shield"
        }
        return "tablecells"
    }
}
