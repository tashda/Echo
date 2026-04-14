import SwiftUI

/// A combo-style picker for MySQL data types. Shows common base types
/// in a native popup button. Parameterized types (varchar, decimal, etc.) show an
/// inline size/precision field. Includes a "Custom..." option for free-text entry.
struct MySQLDataTypePicker: View {
    @Binding var selection: String
    var prompt: String = "Select a data type"
    var compact: Bool = false

    static let defaultType = "varchar(255)"

    @State private var baseType = ""
    @State private var sizeParam = ""
    @State private var isCustom = false
    @FocusState private var textFieldFocused: Bool

    static let commonTypes: [(category: String, types: [String])] = [
        ("Integer", ["tinyint", "smallint", "mediumint", "int", "bigint", "boolean"]),
        ("Fixed-Point", ["decimal", "numeric"]),
        ("Floating-Point", ["float", "double"]),
        ("Bit", ["bit"]),
        ("Character", ["varchar", "char", "tinytext", "text", "mediumtext", "longtext"]),
        ("Binary", ["varbinary", "binary", "tinyblob", "blob", "mediumblob", "longblob"]),
        ("Date/Time", ["date", "time", "datetime", "timestamp", "year"]),
        ("JSON", ["json"]),
        ("Spatial", ["geometry", "point", "linestring", "polygon", "multipoint", "multilinestring", "multipolygon", "geometrycollection"]),
        ("Other", ["enum", "set"]),
    ]

    /// Types that accept parameters, with their placeholder hint and default.
    private static let parameterInfo: [String: (hint: String, defaultValue: String)] = [
        // Length types
        "varchar": ("1-65535", "255"),
        "char": ("0-255", "10"),
        "varbinary": ("1-65535", "255"),
        "binary": ("0-255", "50"),
        // Precision/scale types
        "decimal": ("precision,scale", "10,2"),
        "numeric": ("precision,scale", "10,2"),
        // Bit length
        "bit": ("1-64", "1"),
        // Fractional seconds precision (0-6)
        "time": ("0-6", "0"),
        "datetime": ("0-6", "0"),
        "timestamp": ("0-6", "0"),
    ]

    private static let customSentinel = "__custom__"

    private var allFlat: [String] { Self.commonTypes.flatMap(\.types) }

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
                        .onChange(of: sizeParam) { _, _ in syncToSelection() }
                    Text(")")
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            .onChange(of: baseType) { _, newValue in
                if newValue == Self.customSentinel {
                    isCustom = true
                    baseType = ""
                    selection = ""
                } else {
                    sizeParam = Self.parameterInfo[newValue.lowercased()]?.defaultValue ?? ""
                    syncToSelection()
                }
            }
            .onAppear { syncFromSelection() }
        }
    }

    private func syncFromSelection() {
        let parsed = parseType(selection)
        if allFlat.contains(where: { $0.lowercased() == parsed.base.lowercased() }) {
            baseType = allFlat.first { $0.lowercased() == parsed.base.lowercased() } ?? parsed.base
            sizeParam = parsed.param.isEmpty ? (Self.parameterInfo[baseType.lowercased()]?.defaultValue ?? "") : parsed.param
        } else if selection.isEmpty {
            baseType = "varchar"
            sizeParam = "255"
            syncToSelection()
        } else {
            isCustom = true
        }
    }

    private func syncToSelection() {
        let trimmedParam = sizeParam.trimmingCharacters(in: .whitespaces)
        if needsSizeField && !trimmedParam.isEmpty {
            selection = "\(baseType)(\(trimmedParam))"
        } else {
            selection = baseType
        }
    }

    private func parseType(_ type: String) -> (base: String, param: String) {
        guard let openParen = type.firstIndex(of: "("),
              let closeParen = type.lastIndex(of: ")") else {
            return (type, "")
        }
        let base = String(type[type.startIndex..<openParen])
        let param = String(type[type.index(after: openParen)..<closeParen])
        return (base, param)
    }
}
