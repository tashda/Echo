import SwiftUI
import SQLServerKit

// MARK: - MSSQL Files Page & File Binding Helpers

extension DatabaseEditorView {

    @ViewBuilder
    func mssqlFilesPage() -> some View {
        if viewModel.mssqlFiles.isEmpty {
            Section {
                Text("No file information available.")
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        } else {
            ForEach(Array(viewModel.mssqlFiles.enumerated()), id: \.offset) { index, file in
                Section(file.name) {
                    PropertyRow(title: "Type") {
                        Text(file.typeDescription)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                    if let fg = file.fileGroupName {
                        PropertyRow(title: "Filegroup") {
                            Text(fg)
                                .foregroundStyle(ColorTokens.Text.secondary)
                        }
                    }

                    PropertyRow(title: "Size") {
                        HStack(spacing: SpacingTokens.xs) {
                            TextField("", value: fileSizeMBBinding(index: index), format: .number, prompt: Text("100"))
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .onSubmit {
                                    let newSize = viewModel.fileSizeMBValues[index] ?? Int(file.sizeMB)
                                    Task { await viewModel.applyMSSQLFileOption(file: file, option: .sizeMB(newSize), session: session) }
                                }
                            Text("MB")
                                .foregroundStyle(ColorTokens.Text.secondary)
                        }
                    }

                    PropertyRow(title: "Max Size") {
                        HStack(spacing: SpacingTokens.xs) {
                            Picker("", selection: fileMaxSizeTypeBinding(index: index, file: file)) {
                                Text("Unlimited").tag(FileMaxSizeType.unlimited)
                                Text("MB").tag(FileMaxSizeType.mb)
                            }
                            .labelsHidden()
                            .frame(width: 110)

                            if currentFileMaxSizeType(index: index, file: file) == .mb {
                                TextField("", value: fileMaxSizeMBBinding(index: index, file: file), format: .number, prompt: Text("-1 for unlimited"))
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                                    .onSubmit {
                                        let newMax = viewModel.fileMaxSizeMBValues[index] ?? (file.maxSizeMB ?? 256)
                                        Task { await viewModel.applyMSSQLFileOption(file: file, option: .maxSizeMB(newMax), session: session) }
                                    }
                                Text("MB")
                                    .foregroundStyle(ColorTokens.Text.secondary)
                            }
                        }
                    }

                    PropertyRow(title: "Growth") {
                        HStack(spacing: SpacingTokens.xs) {
                            Picker("", selection: fileGrowthTypeBinding(index: index, file: file)) {
                                Text("MB").tag(FileGrowthType.mb)
                                Text("Percent").tag(FileGrowthType.percent)
                                Text("None").tag(FileGrowthType.none)
                            }
                            .labelsHidden()
                            .frame(width: 110)

                            if currentFileGrowthType(index: index, file: file) != .none {
                                TextField("", value: fileGrowthValueBinding(index: index, file: file), format: .number, prompt: Text("10"))
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                                    .onSubmit {
                                        Task { await viewModel.applyFileGrowthChange(index: index, file: file, session: session) }
                                    }
                                Text(currentFileGrowthType(index: index, file: file) == .percent ? "%" : "MB")
                                    .foregroundStyle(ColorTokens.Text.secondary)
                            }
                        }
                    }

                    PropertyRow(title: "Path") {
                        Text(file.physicalName)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                }
            }
        }
    }

    // MARK: - File Editing Helpers

    func currentFileMaxSizeType(index: Int, file: SQLServerDatabaseFile) -> FileMaxSizeType {
        viewModel.fileMaxSizeTypes[index] ?? (file.isMaxSizeUnlimited ? .unlimited : .mb)
    }

    func currentFileGrowthType(index: Int, file: SQLServerDatabaseFile) -> FileGrowthType {
        if let stored = viewModel.fileGrowthTypes[index] { return stored }
        if file.growthRaw == 0 { return .none }
        return file.isPercentGrowth ? .percent : .mb
    }

    // MARK: - File Editing Bindings

    func fileSizeMBBinding(index: Int) -> Binding<Int> {
        Binding(
            get: { viewModel.fileSizeMBValues[index] ?? Int(viewModel.mssqlFiles[index].sizeMB) },
            set: { viewModel.fileSizeMBValues[index] = $0 }
        )
    }

    func fileMaxSizeTypeBinding(index: Int, file: SQLServerDatabaseFile) -> Binding<FileMaxSizeType> {
        Binding(
            get: { viewModel.fileMaxSizeTypes[index] ?? (file.isMaxSizeUnlimited ? .unlimited : .mb) },
            set: { newType in
                viewModel.fileMaxSizeTypes[index] = newType
                switch newType {
                case .unlimited:
                    Task { await viewModel.applyMSSQLFileOption(file: file, option: .maxSizeUnlimited, session: session) }
                case .mb:
                    let currentMB = viewModel.fileMaxSizeMBValues[index] ?? file.maxSizeMB ?? 256
                    viewModel.fileMaxSizeMBValues[index] = currentMB
                    Task { await viewModel.applyMSSQLFileOption(file: file, option: .maxSizeMB(currentMB), session: session) }
                }
            }
        )
    }

    func fileMaxSizeMBBinding(index: Int, file: SQLServerDatabaseFile) -> Binding<Int> {
        Binding(
            get: { viewModel.fileMaxSizeMBValues[index] ?? file.maxSizeMB ?? 256 },
            set: { viewModel.fileMaxSizeMBValues[index] = $0 }
        )
    }

    func fileGrowthTypeBinding(index: Int, file: SQLServerDatabaseFile) -> Binding<FileGrowthType> {
        Binding(
            get: {
                if let stored = viewModel.fileGrowthTypes[index] { return stored }
                if file.growthRaw == 0 { return .none }
                return file.isPercentGrowth ? .percent : .mb
            },
            set: { newType in
                viewModel.fileGrowthTypes[index] = newType
                switch newType {
                case .none:
                    Task { await viewModel.applyMSSQLFileOption(file: file, option: .filegrowthNone, session: session) }
                case .mb:
                    let currentMB = viewModel.fileGrowthValues[index] ?? file.growthMB ?? 64
                    viewModel.fileGrowthValues[index] = currentMB
                    Task { await viewModel.applyMSSQLFileOption(file: file, option: .filegrowthMB(currentMB), session: session) }
                case .percent:
                    let currentPct = viewModel.fileGrowthValues[index] ?? file.growthPercent ?? 10
                    viewModel.fileGrowthValues[index] = currentPct
                    Task { await viewModel.applyMSSQLFileOption(file: file, option: .filegrowthPercent(currentPct), session: session) }
                }
            }
        )
    }

    func fileGrowthValueBinding(index: Int, file: SQLServerDatabaseFile) -> Binding<Int> {
        Binding(
            get: {
                if let stored = viewModel.fileGrowthValues[index] { return stored }
                if file.isPercentGrowth { return file.growthPercent ?? 10 }
                return file.growthMB ?? 64
            },
            set: { viewModel.fileGrowthValues[index] = $0 }
        )
    }
}
