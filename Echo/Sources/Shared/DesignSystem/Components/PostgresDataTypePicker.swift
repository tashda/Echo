import SwiftUI

/// A combo-style picker for PostgreSQL data types. Shows common base types
/// in a native popup button. Parameterized types (character varying, numeric, etc.)
/// show an inline size/precision field. Includes a "Custom..." option for free-text entry.
struct PostgresDataTypePicker: View {
    @Binding var selection: String
    var prompt: String = "Select a data type"
    var compact: Bool = false

    static let defaultType = "character varying(255)"

    @State private var baseType = ""
    @State private var sizeParam = ""
    @State private var isCustom = false
    @FocusState private var textFieldFocused: Bool

    static let commonTypes: [(category: String, types: [String])] = [
        ("Numeric", ["smallint", "integer", "bigint", "decimal", "numeric", "real", "double precision", "smallserial", "serial", "bigserial"]),
        ("Character", ["character varying", "character", "text", "name"]),
        ("Date/Time", ["timestamp without time zone", "timestamp with time zone", "date", "time without time zone", "time with time zone", "interval"]),
        ("Boolean", ["boolean"]),
        ("Binary", ["bytea"]),
        ("UUID", ["uuid"]),
        ("JSON", ["json", "jsonb"]),
        ("Array", ["integer[]", "text[]", "boolean[]", "uuid[]", "jsonb[]"]),
        ("Network", ["inet", "cidr", "macaddr", "macaddr8"]),
        ("Geometric", ["point", "line", "lseg", "circle", "box", "path", "polygon"]),
        ("Range", ["int4range", "int8range", "numrange", "tsrange", "tstzrange", "daterange"]),
        ("Multirange", ["int4multirange", "int8multirange", "nummultirange", "tsmultirange", "tstzmultirange", "datemultirange"]),
        ("Full Text Search", ["tsvector", "tsquery"]),
        ("Object Identifier", ["oid", "regclass", "regtype", "regproc", "regprocedure", "regnamespace", "regconfig", "regdictionary", "regrole"]),
        ("Other", ["xml", "money", "jsonpath", "bit", "bit varying", "pg_lsn", "pg_snapshot", "txid_snapshot"]),
    ]

    /// Types that accept parameters, with their placeholder hint and default.
    /// PostgreSQL docs: https://www.postgresql.org/docs/current/datatype.html
    private static let parameterInfo: [String: (hint: String, defaultValue: String)] = [
        // Length types
        "character varying": ("1-10485760", "255"),
        "character": ("1-10485760", "1"),
        "char": ("1-10485760", "1"),
        "bit": ("length", "1"),
        "bit varying": ("length", ""),
        // Precision/scale types
        "decimal": ("precision,scale", "18,2"),
        "numeric": ("precision,scale", "18,2"),
        // Fractional seconds precision (0-6)
        "timestamp without time zone": ("0-6", "6"),
        "timestamp with time zone": ("0-6", "6"),
        "time without time zone": ("0-6", "6"),
        "time with time zone": ("0-6", "6"),
        "interval": ("0-6", "6"),
    ]

    /// Maps common PostgreSQL aliases / internal type names to the canonical
    /// form used in `commonTypes`. When metadata returns e.g. "int4", we resolve
    /// it to "integer" so the picker shows a recognized type instead of custom.
    private static let aliases: [String: String] = [
        "varchar": "character varying",
        "char": "character",
        "bpchar": "character",
        "int2": "smallint",
        "int4": "integer",
        "int8": "bigint",
        "float4": "real",
        "float8": "double precision",
        "bool": "boolean",
        "timestamptz": "timestamp with time zone",
        "timestamp": "timestamp without time zone",
        "timetz": "time with time zone",
        "serial4": "serial",
        "serial8": "bigserial",
        "serial2": "smallserial",
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
            .onChange(of: selection) { _, _ in
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

    private var typeMenu: some View {
        Menu {
            ForEach(Self.commonTypes, id: \.category) { group in
                Section(group.category) {
                    ForEach(group.types, id: \.self) { type in
                        Button(type) { baseType = type }
                    }
                }
            }
            Divider()
            Button("Custom\u{2026}") {
                baseType = Self.customSentinel
            }
        } label: {
            Text(baseType.isEmpty ? prompt : baseType)
                .font(TypographyTokens.Table.category)
                .foregroundStyle(baseType.isEmpty ? ColorTokens.Text.tertiary : ColorTokens.Text.secondary)
        }
        .menuStyle(.borderlessButton)
    }

    private func syncFromSelection() {
        let parsed = parseType(selection)
        // Resolve aliases (e.g. "varchar" → "character varying") before matching
        let resolvedBase = Self.aliases[parsed.base.lowercased()] ?? parsed.base
        if allFlat.contains(where: { $0.lowercased() == resolvedBase.lowercased() }) {
            baseType = allFlat.first { $0.lowercased() == resolvedBase.lowercased() } ?? resolvedBase
            sizeParam = parsed.param.isEmpty ? (Self.parameterInfo[baseType.lowercased()]?.defaultValue ?? "") : parsed.param
        } else if selection.isEmpty {
            baseType = "character varying"
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
