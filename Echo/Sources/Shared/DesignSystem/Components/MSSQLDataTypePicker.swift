import SwiftUI

/// A combo-style picker for Microsoft SQL Server data types. Shows common base types
/// in a native popup button. Parameterized types (nvarchar, decimal, etc.) show an
/// inline size/precision field. Includes a "Custom..." option for free-text entry.
struct MSSQLDataTypePicker: View {
    @Binding var selection: String
    var prompt: String = "Select a data type"
    var compact: Bool = false

    static let defaultType = "nvarchar(255)"

    @State private var baseType = ""
    @State private var sizeParam = ""
    @State private var isCustom = false
    @State private var isSyncing = false
    @FocusState private var textFieldFocused: Bool

    static let commonTypes: [(category: String, types: [String])] = [
        ("Exact Numeric", ["bit", "tinyint", "smallint", "int", "bigint", "decimal", "numeric", "money", "smallmoney"]),
        ("Approximate Numeric", ["float", "real"]),
        ("Unicode Strings", ["nvarchar", "nchar", "ntext"]),
        ("Non-Unicode Strings", ["varchar", "char", "text"]),
        ("Date/Time", ["datetime2", "datetime", "date", "time", "datetimeoffset", "smalldatetime"]),
        ("Binary", ["varbinary", "binary", "image", "rowversion"]),
        ("Spatial", ["geometry", "geography"]),
        ("Document", ["json", "xml"]),
        ("Other", ["uniqueidentifier", "sql_variant", "hierarchyid", "sysname", "vector"]),
    ]

    /// Types that accept parameters, with their placeholder hint.
    /// - length: nvarchar(255), char(10), etc.
    /// - precision: decimal(18,2), numeric(18,2)
    /// - scale: float(53), datetime2(7), time(7), datetimeoffset(7)
    private static let parameterInfo: [String: (hint: String, defaultValue: String)] = [
        // Length types
        "nvarchar": ("max or 1-4000", "255"),
        "nchar": ("1-4000", "10"),
        "varchar": ("max or 1-8000", "255"),
        "char": ("1-8000", "10"),
        "varbinary": ("max or 1-8000", "255"),
        "binary": ("1-8000", "50"),
        // Precision/scale types
        "decimal": ("precision,scale", "18,2"),
        "numeric": ("precision,scale", "18,2"),
        // Fractional seconds precision (0-7)
        "float": ("1-53", "53"),
        "datetime2": ("0-7", "7"),
        "time": ("0-7", "7"),
        "datetimeoffset": ("0-7", "7"),
    ]

    private static let customSentinel = "__custom__"

    private static let allFlat: [String] = commonTypes.flatMap(\.types)

    private var currentParamInfo: (hint: String, defaultValue: String)? {
        Self.parameterInfo[baseType.lowercased()]
    }

    private var needsSizeField: Bool {
        currentParamInfo != nil
    }

    var body: some View {
        if isCustom {
            HStack(spacing: SpacingTokens.xxs) {
                TextField("", text: $selection, prompt: Text(prompt))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .focused($textFieldFocused)
                    .onAppear { textFieldFocused = true }
                Button {
                    isCustom = false
                    syncFromSelection()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
                .buttonStyle(.plain)
            }
            .onChange(of: selection) { _, _ in
                // Re-sync if selection changed externally (e.g. context menu)
                if !textFieldFocused { syncFromSelection() }
            }
        } else {
            HStack(spacing: SpacingTokens.xxs) {
                Picker("", selection: $baseType) {
                    if baseType.isEmpty {
                        Text(prompt).tag("")
                    }
                    ForEach(Self.commonTypes, id: \.category) { group in
                        Section(group.category) {
                            ForEach(group.types, id: \.self) { type in
                                Text(type).tag(type)
                            }
                        }
                    }
                    Divider()
                    Text("Custom\u{2026}").tag(Self.customSentinel)
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .controlSize(compact ? .mini : .regular)

                if let info = currentParamInfo {
                    Text("(")
                        .foregroundStyle(ColorTokens.Text.tertiary)
                    TextField("", text: $sizeParam, prompt: Text(info.hint))
                        .textFieldStyle(.plain)
                        .frame(width: 60)
                        .multilineTextAlignment(.center)
                        .onChange(of: sizeParam) { _, _ in
                            guard !isSyncing else { return }
                            syncToSelection()
                        }
                    Text(")")
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            .onChange(of: baseType) { _, newValue in
                guard !isSyncing else { return }
                if newValue == Self.customSentinel {
                    isCustom = true
                    baseType = ""
                    selection = ""
                } else {
                    let currentSelection = Self.selectionState(for: selection)
                    if currentSelection.baseType.caseInsensitiveCompare(newValue) == .orderedSame {
                        sizeParam = currentSelection.sizeParam
                        return
                    }
                    sizeParam = Self.parameterInfo[newValue.lowercased()]?.defaultValue ?? ""
                    syncToSelection()
                }
            }
            .onAppear { syncFromSelection() }
        }
    }

    private func syncFromSelection() {
        isSyncing = true
        defer { isSyncing = false }
        let resolvedState = Self.selectionState(for: selection)
        baseType = resolvedState.baseType
        sizeParam = resolvedState.sizeParam
        isCustom = resolvedState.isCustom
    }

    private func syncToSelection() {
        let trimmedParam = sizeParam.trimmingCharacters(in: .whitespaces)
        let newValue: String
        if needsSizeField && !trimmedParam.isEmpty {
            newValue = "\(baseType)(\(trimmedParam))"
        } else {
            newValue = baseType
        }
        guard newValue != selection else { return }
        selection = newValue
    }

    internal static func selectionState(for selection: String) -> (baseType: String, sizeParam: String, isCustom: Bool) {
        let trimmedSelection = selection.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSelection.isEmpty else {
            return ("", "", false)
        }

        let parsed = parseType(trimmedSelection)
        guard let matchedType = allFlat.first(where: { $0.lowercased() == parsed.base.lowercased() }) else {
            return ("", "", true)
        }

        // Preserve metadata-provided bare types such as `nvarchar` so opening the
        // editor doesn't rewrite them to an arbitrary default like `nvarchar(255)`.
        return (matchedType, parsed.param, false)
    }

    private static func parseType(_ type: String) -> (base: String, param: String) {
        guard let openParen = type.firstIndex(of: "("),
              let closeParen = type.lastIndex(of: ")") else {
            return (type, "")
        }
        let base = String(type[type.startIndex..<openParen])
        let param = String(type[type.index(after: openParen)..<closeParen])
        return (base, param)
    }
}
