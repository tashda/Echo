import SwiftUI
import SQLServerKit

// MARK: - MSSQL File Editing State Types & Bindings

extension DatabasePropertiesSheet {

    // MARK: - File Editing State Types

    enum FileMaxSizeType: Hashable {
        case unlimited
        case mb
    }

    enum FileGrowthType: Hashable {
        case mb
        case percent
        case none
    }

    // MARK: - File Editing Helpers

    func currentFileMaxSizeType(index: Int, file: SQLServerDatabaseFile) -> FileMaxSizeType {
        fileMaxSizeTypes[index] ?? (file.isMaxSizeUnlimited ? .unlimited : .mb)
    }

    func currentFileGrowthType(index: Int, file: SQLServerDatabaseFile) -> FileGrowthType {
        if let stored = fileGrowthTypes[index] { return stored }
        if file.growthRaw == 0 { return .none }
        return file.isPercentGrowth ? .percent : .mb
    }

    // MARK: - File Editing Bindings

    func fileSizeMBBinding(index: Int) -> Binding<Int> {
        Binding(
            get: { fileSizeMBValues[index] ?? Int(mssqlFiles[index].sizeMB) },
            set: { fileSizeMBValues[index] = $0 }
        )
    }

    func fileMaxSizeTypeBinding(index: Int, file: SQLServerDatabaseFile) -> Binding<FileMaxSizeType> {
        Binding(
            get: { fileMaxSizeTypes[index] ?? (file.isMaxSizeUnlimited ? .unlimited : .mb) },
            set: { newType in
                fileMaxSizeTypes[index] = newType
                switch newType {
                case .unlimited:
                    applyMSSQLFileOption(file: file, option: .maxSizeUnlimited)
                case .mb:
                    let currentMB = fileMaxSizeMBValues[index] ?? file.maxSizeMB ?? 256
                    fileMaxSizeMBValues[index] = currentMB
                    applyMSSQLFileOption(file: file, option: .maxSizeMB(currentMB))
                }
            }
        )
    }

    func fileMaxSizeMBBinding(index: Int, file: SQLServerDatabaseFile) -> Binding<Int> {
        Binding(
            get: { fileMaxSizeMBValues[index] ?? file.maxSizeMB ?? 256 },
            set: { fileMaxSizeMBValues[index] = $0 }
        )
    }

    func fileGrowthTypeBinding(index: Int, file: SQLServerDatabaseFile) -> Binding<FileGrowthType> {
        Binding(
            get: {
                if let stored = fileGrowthTypes[index] { return stored }
                if file.growthRaw == 0 { return .none }
                return file.isPercentGrowth ? .percent : .mb
            },
            set: { newType in
                fileGrowthTypes[index] = newType
                switch newType {
                case .none:
                    applyMSSQLFileOption(file: file, option: .filegrowthNone)
                case .mb:
                    let currentMB = fileGrowthValues[index] ?? file.growthMB ?? 64
                    fileGrowthValues[index] = currentMB
                    applyMSSQLFileOption(file: file, option: .filegrowthMB(currentMB))
                case .percent:
                    let currentPct = fileGrowthValues[index] ?? file.growthPercent ?? 10
                    fileGrowthValues[index] = currentPct
                    applyMSSQLFileOption(file: file, option: .filegrowthPercent(currentPct))
                }
            }
        )
    }

    func fileGrowthValueBinding(index: Int, file: SQLServerDatabaseFile) -> Binding<Int> {
        Binding(
            get: {
                if let stored = fileGrowthValues[index] { return stored }
                if file.isPercentGrowth { return file.growthPercent ?? 10 }
                return file.growthMB ?? 64
            },
            set: { fileGrowthValues[index] = $0 }
        )
    }

    func applyFileGrowthChange(index: Int, file: SQLServerDatabaseFile) {
        let growthType = fileGrowthTypes[index] ?? (file.isPercentGrowth ? .percent : .mb)
        let value = fileGrowthValues[index] ?? (file.isPercentGrowth ? file.growthPercent ?? 10 : file.growthMB ?? 64)
        switch growthType {
        case .mb:
            applyMSSQLFileOption(file: file, option: .filegrowthMB(value))
        case .percent:
            applyMSSQLFileOption(file: file, option: .filegrowthPercent(value))
        case .none:
            applyMSSQLFileOption(file: file, option: .filegrowthNone)
        }
    }
}
