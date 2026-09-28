import AppKit
import SQLServerKit
import SwiftUI

extension TuningAdvisorView {
    var recommendationTable: some View {
        Table(viewModel.recommendations, selection: $viewModel.selectedRecommendationID) {
            TableColumn("Table") { rec in
                Text("\(rec.schemaName).\(rec.tableName)").font(TypographyTokens.Table.name)
            }
            .width(min: 200, ideal: 300)

            TableColumn("Impact %") { rec in
                Text(String(format: "%.1f", rec.avgTotalUserCost))
                    .font(TypographyTokens.Table.percentage)
                    .foregroundStyle(impactColor(rec.avgTotalUserCost))
            }
            .width(80)

            TableColumn("User Seeks") { rec in
                Text("\(rec.userSeeks)").font(TypographyTokens.Table.numeric)
            }
            .width(100)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
    }

    var recommendationDetailView: some View {
        ScrollView {
            if let recommendation = viewModel.selectedRecommendation {
                VStack(alignment: .leading, spacing: SpacingTokens.lg) {
                    recommendationHeader(recommendation)
                    Divider()
                    VStack(alignment: .leading, spacing: SpacingTokens.md) {
                        columnSection("Equality Columns", recommendation.equalityColumns, icon: "equal.circle")
                        columnSection("Inequality Columns", recommendation.inequalityColumns, icon: "not.equal.circle")
                        columnSection("Included Columns", recommendation.includedColumns, icon: "plus.circle")
                    }
                    recommendationScript(recommendation)
                }
                .padding(SpacingTokens.md)
            } else {
                ContentUnavailableView("Select a recommendation to see details", systemImage: "info.circle")
            }
        }
        .background(ColorTokens.Background.secondary)
    }

    private func recommendationHeader(_ recommendation: SQLServerMissingIndexRecommendation) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                Text("\(recommendation.schemaName).\(recommendation.tableName)").font(TypographyTokens.title)
                Text("Database: \(recommendation.databaseName)").foregroundStyle(ColorTokens.Text.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: SpacingTokens.xs) {
                Text("\(String(format: "%.1f", recommendation.avgTotalUserCost))% Impact")
                    .font(TypographyTokens.headline)
                    .foregroundStyle(impactColor(recommendation.avgTotalUserCost))
                Text("\(recommendation.userSeeks) seeks, \(recommendation.userScans) scans")
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }
    }

    private func columnSection(_ title: String, _ columns: [String], icon: String) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Label(title, systemImage: icon).font(TypographyTokens.headline)
            if columns.isEmpty {
                Text("None").foregroundStyle(ColorTokens.Text.secondary).italic()
            } else {
                FlowLayout(spacing: SpacingTokens.xs) {
                    ForEach(columns, id: \.self) { column in
                        Text(column)
                            .padding(.horizontal, SpacingTokens.sm)
                            .padding(.vertical, SpacingTokens.xxxs)
                            .background(Capsule().fill(ColorTokens.accent.opacity(0.1)))
                            .overlay(Capsule().stroke(ColorTokens.accent.opacity(0.2), lineWidth: SpacingTokens.micro))
                    }
                }
            }
        }
    }

    private func recommendationScript(_ recommendation: SQLServerMissingIndexRecommendation) -> some View {
        GroupBox("SQL Recommendation") {
            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                Text(generateCreateIndexSQL(recommendation))
                    .font(TypographyTokens.code)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Divider()
                HStack(spacing: SpacingTokens.sm) {
                    errorMessage
                    Spacer()
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(generateCreateIndexSQL(recommendation), forType: .string)
                    } label: {
                        Label("Copy Script", systemImage: "doc.on.doc")
                    }
                    Button {
                        let sql = generateCreateIndexSQL(recommendation)
                        Task { await viewModel.createIndex(sql: sql, indexName: extractIndexName(sql)) }
                    } label: {
                        Label("Create Index", systemImage: "bolt.fill")
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isCreatingIndex)
                }
            }
            .padding(SpacingTokens.sm)
        }
    }

    @ViewBuilder
    private var errorMessage: some View {
        if let error = viewModel.errorMessage {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(ColorTokens.Status.warning)
            Text(error)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Status.error)
                .lineLimit(2)
        }
    }

    var emptyState: some View {
        TabContentUnavailableView("No Recommendations", systemImage: "checkmark.circle") {
            Text("Your database performance looks good! No major missing indexes detected.")
        }
    }

    private func impactColor(_ impact: Double) -> Color {
        if impact > 80 { return ColorTokens.Status.error }
        if impact > 50 { return ColorTokens.Status.warning }
        return ColorTokens.Status.info
    }

    private func extractIndexName(_ sql: String) -> String {
        guard let start = sql.range(of: "["), let end = sql.range(of: "]") else { return "index" }
        return String(sql[start.upperBound..<end.lowerBound])
    }

    private func generateCreateIndexSQL(_ recommendation: SQLServerMissingIndexRecommendation) -> String {
        let name = "IX_\(recommendation.tableName)_\(UUID().uuidString.prefix(6))"
        let keys = recommendation.equalityColumns + recommendation.inequalityColumns
        var sql = "CREATE INDEX [\(name)] ON [\(recommendation.schemaName)].[\(recommendation.tableName)] ("
        sql += keys.map { "[\($0)]" }.joined(separator: ", ") + ")"
        if !recommendation.includedColumns.isEmpty {
            sql += "\nINCLUDE (" + recommendation.includedColumns.map { "[\($0)]" }.joined(separator: ", ") + ")"
        }
        return sql
    }
}
