import SwiftUI

/// Round 21 · Postgres: values in the grid. postgres-wire now formats every type exactly as psql
/// prints it (arrays `{1,2,3}`, bytea `\x89504e47…`, jsonb, ranges, intervals). This page decides
/// whether the grid draws some of those more readably. Drawing only: copy, export and the spool keep
/// the server's text, and the formatting runs on visible cells at draw time, so it cannot slow a query.
@MainActor
enum PgValueDisplayRound {
    enum Arrays: String, CaseIterable {
        case server = "VA1 · As the server prints it (today)"
        case list = "VA2 · Plain list without braces"
        case chips = "VA3 · Chips"
        case counted = "VA4 · Count, then the first items"
    }
    enum JSON: String, CaseIterable {
        case server = "VJ1 · One line as sent (today)"
        case coloured = "VJ2 · One line with key colour"
        case summary = "VJ3 · Summary: { 4 keys }"
    }
    enum Binary: String, CaseIterable {
        case hex = "VB1 · Hex \\x… (today)"
        case size = "VB2 · Size only"
        case kind = "VB3 · Kind and size"
    }
    enum Numbers: String, CaseIterable {
        case server = "VN1 · Right aligned as sent (today)"
        case decimal = "VN2 · Aligned on the decimal point"
        case grouped = "VN3 · Decimal aligned, digits grouped"
    }

    private static let width: CGFloat = 660
    private static let height: CGFloat = 300

    static let spec = RoundSpec(
        controls: [
            .of("arrays", "Arrays", Arrays.self, default: .counted,
                question: "Look at the tags column. Which option lets you read the values and see how many there are?",
                recommend: .counted,
                why: "The count answers the common question (how many?) without reading, and the items follow without braces or quotes. Chips look nice but take three times the width, so fewer columns fit; the server form is right for copy and stays there."),
            .of("json", "JSON", JSON.self, default: .coloured,
                question: "Look at the payload column. Can you find the key you want?",
                recommend: .coloured,
                why: "Colouring keys keeps the whole value on one line (you can still search it) and makes keys stand out. A summary hides what you usually look for; the full value opens in the inspector either way."),
            .of("binary", "Binary", Binary.self, default: .kind,
                question: "Look at the avatar column. What do you need to know from a bytea cell?",
                recommend: .kind,
                why: "Nobody reads hex in a grid; 'PNG image · 12 KB' says what it is and how big. The hex stays in the inspector and in copy. Kind comes from the first bytes, which are already in the cell."),
            .of("numbers", "Numbers", Numbers.self, default: .decimal,
                question: "Compare the total column. Can you compare the amounts at a glance?",
                recommend: .decimal,
                why: "Aligning on the decimal point lines up units, tens and cents without changing the digits. Grouping adds separators that are not in the data, which matters when people copy by eye; keep it off by default."),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "Every value as the server prints it; numbers right aligned.",
                  isEchoToday: true, designWidth: width, designHeight: height) { _ in
                PgValueExhibit(arrays: .server, json: .server, binary: .hex, numbers: .server)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls. Copy still copies the server's text.",
                  designWidth: width, designHeight: height) { values in
                PgValueExhibit(arrays: Arrays(rawValue: values["arrays"]) ?? .counted,
                               json: JSON(rawValue: values["json"]) ?? .coloured,
                               binary: Binary(rawValue: values["binary"]) ?? .kind,
                               numbers: Numbers(rawValue: values["numbers"]) ?? .decimal)
            },
        ],
        questions: [
            .init(id: "copy", title: "What copy copies",
                  question: "When a cell is drawn differently, what does ⌘C put on the clipboard?",
                  choices: [
                      .init(id: "server", name: "CP1 · The server's text, always"),
                      .init(id: "drawn", name: "CP2 · What you see"),
                      .init(id: "both", name: "CP3 · The server's text; Copy as Shown in the menu"),
                  ],
                  recommended: "both",
                  why: "Pasting into SQL or another tool needs the server's form ({a,b}, \\x…); the menu item covers pasting into a message or document."),
            .init(id: "emptyNull", title: "Empty text and NULL",
                  question: "An empty string and NULL both look blank to many tools. How should the grid tell them apart?",
                  choices: [
                      .init(id: "today", name: "EN1 · NULL in grey, empty shows nothing (today)"),
                      .init(id: "mark", name: "EN2 · NULL in grey, empty as a faint ‘empty’"),
                  ],
                  recommended: "today",
                  why: "The grey NULL already makes the difference visible, and a word in empty cells adds noise to text-heavy tables."),
            .init(id: "special", title: "Ranges, intervals and infinity",
                  question: "Should ranges ([10,20)), intervals (1 day 02:00:00) and 'infinity' dates be reworded?",
                  choices: [
                      .init(id: "keep", name: "SP1 · Keep the server's form"),
                      .init(id: "reword", name: "SP2 · Reword (10 to 20, 1 d 2 h, ∞)"),
                  ],
                  recommended: "keep",
                  why: "These forms are what you write in a WHERE clause, and the bracket says whether the end is included; rewording loses that."),
            .init(id: "scope", title: "Other databases",
                  question: "Should the same drawing apply to SQL Server and MySQL columns of the same kind?",
                  choices: [
                      .init(id: "all", name: "SC1 · Yes, by kind (binary, JSON, numbers)"),
                      .init(id: "pg", name: "SC2 · Postgres only for now"),
                  ],
                  recommended: "all",
                  why: "The grid decides by value kind, not by database, so one rule is less to learn; arrays exist only in Postgres anyway."),
        ],
        exhibitTopic: ("Easier to read?", "Compare the same rows in both. Is the proposal easier to scan without hiding anything?",
                       "proposal",
                       "It says what binary cells are, counts arrays and lines up amounts, while copy and export keep exactly what the server sent."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "VA4, VJ2, VB3, VN2.",
                  values: ["arrays": Arrays.counted.rawValue, "json": JSON.coloured.rawValue,
                           "binary": Binary.kind.rawValue, "numbers": Numbers.decimal.rawValue],
                  isRecommended: true),
            .init(id: "rich", name: "Richest", summary: "VA3, VJ3, VB3, VN3.",
                  values: ["arrays": Arrays.chips.rawValue, "json": JSON.summary.rawValue,
                           "binary": Binary.kind.rawValue, "numbers": Numbers.grouped.rawValue]),
            .init(id: "today", name: "Like Echo today", summary: "VA1, VJ1, VB1, VN1.",
                  values: ["arrays": Arrays.server.rawValue, "json": JSON.server.rawValue,
                           "binary": Binary.hex.rawValue, "numbers": Numbers.server.rawValue]),
        ]
    )
}

struct PgValueExhibit: View {
    typealias R = PgValueDisplayRound
    let arrays: R.Arrays
    let json: R.JSON
    let binary: R.Binary
    let numbers: R.Numbers

    private struct Row {
        let tags: [String]
        let payload: [(String, String)]
        let avatar: (hex: String, kind: String, size: String)?
        let total: String
    }

    private let rows: [Row] = [
        Row(tags: ["new", "gift", "express"], payload: [("sku", "\"A-100\""), ("qty", "2"), ("gift", "true"), ("note", "null")],
            avatar: ("\\x89504e470d0a1a0a0000000d49484452…", "PNG image", "12 KB"), total: "1249.5"),
        Row(tags: ["repeat"], payload: [("sku", "\"B-7\""), ("qty", "1")],
            avatar: ("\\xffd8ffe000104a46494600010101…", "JPEG image", "48 KB"), total: "38.00"),
        Row(tags: [], payload: [("sku", "\"C-42\""), ("qty", "12"), ("coupon", "\"FALL\"")],
            avatar: nil, total: "12045.75"),
        Row(tags: ["b2b", "net 30", "priority", "eu"], payload: [("sku", "\"D-1\""), ("qty", "400")],
            avatar: ("\\x255044462d312e370a25…", "PDF", "220 KB"), total: "7.2"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Grid(alignment: .leading, horizontalSpacing: SpacingTokens.md, verticalSpacing: SpacingTokens.xs) {
                GridRow {
                    header("tags text[]")
                    header("payload jsonb")
                    header("avatar bytea")
                    header("total numeric").gridColumnAlignment(.trailing)
                }
                Divider()
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        tagsCell(row.tags).frame(width: 150, alignment: .leading)
                        jsonCell(row.payload).frame(width: 190, alignment: .leading)
                        binaryCell(row.avatar).frame(width: 130, alignment: .leading)
                        numberCell(row.total)
                    }
                }
            }
            .padding(SpacingTokens.sm)
            .workspaceCard()
            Text("Copy, export and the inspector keep the server's text in every option.")
                .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
            Spacer(minLength: SpacingTokens.none)
        }
        .padding(SpacingTokens.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ColorTokens.Workspace.canvas)
    }

    private func header(_ name: String) -> some View {
        Text(name).font(TypographyTokens.labelBold).foregroundStyle(ColorTokens.Text.secondary)
    }

    @ViewBuilder
    private func tagsCell(_ tags: [String]) -> some View {
        switch arrays {
        case .server:
            let quoted = tags.map { $0.contains(" ") ? "\"\($0)\"" : $0 }
            Text("{\(quoted.joined(separator: ","))}").font(TypographyTokens.standard).lineLimit(1)
        case .list:
            Text(tags.isEmpty ? "—" : tags.joined(separator: ", ")).font(TypographyTokens.standard).lineLimit(1)
        case .chips:
            HStack(spacing: SpacingTokens.xxxs) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag).font(TypographyTokens.detail)
                        .padding(.horizontal, SpacingTokens.xxs)
                        .background(ColorTokens.Text.primary.opacity(0.07), in: .capsule)
                }
            }
            .lineLimit(1)
        case .counted:
            HStack(spacing: SpacingTokens.xxs) {
                Text("\(tags.count)").font(TypographyTokens.detail).monospacedDigit()
                    .padding(.horizontal, SpacingTokens.xxs)
                    .background(ColorTokens.Text.primary.opacity(0.07), in: .capsule)
                Text(tags.joined(separator: ", ")).font(TypographyTokens.standard).lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private func jsonCell(_ pairs: [(String, String)]) -> some View {
        switch json {
        case .server:
            Text("{" + pairs.map { "\"\($0.0)\": \($0.1)" }.joined(separator: ", ") + "}")
                .font(TypographyTokens.standard).lineLimit(1)
        case .coloured:
            colouredJSON(pairs).font(TypographyTokens.standard).lineLimit(1)
        case .summary:
            Text("{ \(pairs.count) keys }").font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.secondary)
        }
    }

    private func colouredJSON(_ pairs: [(String, String)]) -> Text {
        var text = Text("{")
        for (index, pair) in pairs.enumerated() {
            if index > 0 { text = text + Text(", ") }
            text = text + Text("\"\(pair.0)\"").foregroundColor(ColorTokens.Status.info) + Text(": \(pair.1)")
        }
        return text + Text("}")
    }

    @ViewBuilder
    private func binaryCell(_ value: (hex: String, kind: String, size: String)?) -> some View {
        if let value {
            switch binary {
            case .hex: Text(value.hex).font(TypographyTokens.standard).lineLimit(1).truncationMode(.tail)
            case .size: Text(value.size).font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.secondary)
            case .kind: Label("\(value.kind) · \(value.size)", systemImage: value.kind == "PDF" ? "doc" : "photo")
                    .font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.secondary).lineLimit(1)
            }
        } else {
            Text("NULL").font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.tertiary)
        }
    }

    @ViewBuilder
    private func numberCell(_ value: String) -> some View {
        switch numbers {
        case .server:
            Text(value).font(TypographyTokens.standard).monospacedDigit()
        case .decimal, .grouped:
            let parts = value.split(separator: ".", omittingEmptySubsequences: false)
            let whole = numbers == .grouped ? grouped(String(parts[0])) : String(parts[0])
            let fraction = parts.count > 1 ? "." + parts[1] : ""
            HStack(spacing: SpacingTokens.none) {
                Text(whole).frame(width: 60, alignment: .trailing)
                Text(fraction).frame(width: 28, alignment: .leading)
            }
            .font(TypographyTokens.standard).monospacedDigit()
        }
    }

    private func grouped(_ digits: String) -> String {
        var result = ""
        for (index, character) in digits.reversed().enumerated() {
            if index > 0, index % 3 == 0 { result.append(",") }
            result.append(character)
        }
        return String(result.reversed())
    }
}
