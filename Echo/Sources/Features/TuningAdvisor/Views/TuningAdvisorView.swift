import SwiftUI
import SQLServerKit

struct TuningAdvisorView: View {
    @Bindable var viewModel: TuningAdvisorViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            toolbar

            Picker("", selection: $viewModel.selectedTab) {
                ForEach(TuningAdvisorViewModel.TuningTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)
            .padding(SpacingTokens.xs)

            switch viewModel.selectedTab {
            case .missingIndexes:
                if viewModel.recommendations.isEmpty && !viewModel.isRefreshing {
                    emptyState
                } else {
                    VSplitView {
                        recommendationTable
                            .frame(minHeight: 150)
                        recommendationDetailView
                            .frame(minHeight: 150)
                    }
                }
            case .indexUsage:
                IndexUsageSection(stats: viewModel.indexUsageStats)
            }
        }
        .background(ColorTokens.Background.primary)
        .onAppear {
            viewModel.refresh()
        }
        .onChange(of: viewModel.selectedTab) { _, newTab in
            if newTab == .indexUsage && viewModel.indexUsageStats.isEmpty {
                viewModel.loadIndexUsageStats()
            }
        }
    }
    
    private var toolbar: some View {
        HStack {
            Button {
                viewModel.refresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.isRefreshing)
            
            if viewModel.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }
            
            Spacer()
        }
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Background.secondary)
    }
    
    private var recommendationTable: some View {
        Table(viewModel.recommendations, selection: $viewModel.selectedRecommendationID) {
            TableColumn("Table") { rec in
                Text("\(rec.schemaName).\(rec.tableName)")
            }
            .width(min: 200, ideal: 300)
            
            TableColumn("Impact %") { rec in
                Text(String(format: "%.1f", rec.avgTotalUserCost))
                    .foregroundStyle(impactColor(rec.avgTotalUserCost))
            }
            .width(80)
            
            TableColumn("User Seeks") { rec in
                Text("\(rec.userSeeks)")
            }
            .width(100)
        }
    }
    
    private var recommendationDetailView: some View {
        ScrollView {
            if let rec = viewModel.selectedRecommendation {
                VStack(alignment: .leading, spacing: SpacingTokens.lg) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                            Text("\(rec.schemaName).\(rec.tableName)")
                                .font(TypographyTokens.title)
                            Text("Database: \(rec.databaseName)")
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: SpacingTokens.xs) {
                            Text("\(String(format: "%.1f", rec.avgTotalUserCost))% Impact")
                                .font(TypographyTokens.headline)
                                .foregroundStyle(impactColor(rec.avgTotalUserCost))
                            Text("\(rec.userSeeks) seeks, \(rec.userScans) scans")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: SpacingTokens.md) {
                        columnSection("Equality Columns", rec.equalityColumns, icon: "equal.circle")
                        columnSection("Inequality Columns", rec.inequalityColumns, icon: "not.equal.circle")
                        columnSection("Included Columns", rec.includedColumns, icon: "plus.circle")
                    }
                    
                    GroupBox("SQL Recommendation") {
                        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                            Text(generateCreateIndexSQL(rec))
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Divider()

                            HStack(spacing: SpacingTokens.sm) {
                                if let error = viewModel.errorMessage {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(ColorTokens.Status.warning)
                                    Text(error)
                                        .font(TypographyTokens.detail)
                                        .foregroundStyle(ColorTokens.Status.error)
                                        .lineLimit(2)
                                }

                                Spacer()

                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(generateCreateIndexSQL(rec), forType: .string)
                                } label: {
                                    Label("Copy Script", systemImage: "doc.on.doc")
                                }

                                if !viewModel.isCreatingIndex {
                                    Button {
                                        let sql = generateCreateIndexSQL(rec)
                                        let name = extractIndexName(sql)
                                        Task { await viewModel.createIndex(sql: sql, indexName: name) }
                                    } label: {
                                        Label("Create Index", systemImage: "bolt.fill")
                                    }
                                    .buttonStyle(.bordered)
                                } else {
                                    Button {} label: {
                                        Label("Create Index", systemImage: "bolt.fill")
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(true)
                                }
                            }
                        }
                        .padding(SpacingTokens.sm)
                    }
                }
                .padding(SpacingTokens.md)
            } else {
                ContentUnavailableView("Select a recommendation to see details", systemImage: "info.circle")
            }
        }
        .background(ColorTokens.Background.secondary)
    }
    
    private func columnSection(_ title: String, _ columns: [String], icon: String) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Label(title, systemImage: icon)
                .font(TypographyTokens.headline)
            
            if columns.isEmpty {
                Text("None")
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                FlowLayout(spacing: SpacingTokens.xs) {
                    ForEach(columns, id: \.self) { column in
                        Text(column)
                            .padding(.horizontal, SpacingTokens.sm)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.accentColor.opacity(0.1)))
                            .overlay(Capsule().stroke(Color.accentColor.opacity(0.2), lineWidth: 1))
                    }
                }
            }
        }
    }
    
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Recommendations", systemImage: "checkmark.circle")
        } description: {
            Text("Your database performance looks good! No major missing indexes detected.")
        }
    }
    
    private func impactColor(_ impact: Double) -> Color {
        if impact > 80 { return .red }
        if impact > 50 { return .orange }
        return .accentColor
    }
    
    private func extractIndexName(_ sql: String) -> String {
        guard let start = sql.range(of: "["),
              let end = sql.range(of: "]") else { return "index" }
        return String(sql[start.upperBound..<end.lowerBound])
    }

    private func generateCreateIndexSQL(_ rec: SQLServerMissingIndexRecommendation) -> String {
        let name = "IX_\(rec.tableName)_\(UUID().uuidString.prefix(6))"
        var sql = "CREATE INDEX [\(name)] ON [\(rec.schemaName)].[\(rec.tableName)] ("
        
        let keys = rec.equalityColumns + rec.inequalityColumns
        sql += keys.map { "[\($0)]" }.joined(separator: ", ")
        sql += ")"
        
        if !rec.includedColumns.isEmpty {
            sql += "\nINCLUDE (" + rec.includedColumns.map { "[\($0)]" }.joined(separator: ", ") + ")"
        }
        
        return sql
    }
}
