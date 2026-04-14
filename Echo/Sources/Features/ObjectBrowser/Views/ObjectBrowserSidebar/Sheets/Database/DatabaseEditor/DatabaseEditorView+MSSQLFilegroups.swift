import SwiftUI
import SQLServerKit

// MARK: - Filegroups Page

extension DatabaseEditorView {

    @ViewBuilder
    func mssqlFilegroupsPage() -> some View {
        Section("Row Data Filegroups") {
            ForEach(viewModel.mssqlFilegroups.filter { !$0.isMemoryOptimized && !$0.isFilestream }, id: \.dataSpaceID) { fg in
                filegroupRow(fg)
            }
        }

        let filestreamGroups = viewModel.mssqlFilegroups.filter(\.isFilestream)
        if !filestreamGroups.isEmpty {
            Section("FILESTREAM Filegroups") {
                ForEach(filestreamGroups, id: \.dataSpaceID) { fg in
                    filegroupRow(fg)
                }
            }
        }

        let memOptGroups = viewModel.mssqlFilegroups.filter(\.isMemoryOptimized)
        if !memOptGroups.isEmpty {
            Section("Memory-Optimized Filegroups") {
                ForEach(memOptGroups, id: \.dataSpaceID) { fg in
                    filegroupRow(fg)
                }
            }
        }
    }

    @ViewBuilder
    private func filegroupRow(_ fg: SQLServerFilegroup) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                HStack(spacing: SpacingTokens.xs) {
                    Text(fg.name)
                        .font(TypographyTokens.body)
                    if fg.isDefault {
                        Text("Default")
                            .font(TypographyTokens.caption)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ColorTokens.Background.tertiary, in: .capsule)
                    }
                    if fg.isReadOnly {
                        Text("Read-Only")
                            .font(TypographyTokens.caption)
                            .foregroundStyle(ColorTokens.Status.warning)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ColorTokens.Status.warning.opacity(0.1), in: .capsule)
                    }
                }
                Text("\(fg.fileCount) file\(fg.fileCount == 1 ? "" : "s")")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
            Spacer()
        }
    }
}
