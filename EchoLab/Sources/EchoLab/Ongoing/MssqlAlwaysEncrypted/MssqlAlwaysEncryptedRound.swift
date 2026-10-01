import SwiftUI

/// Round 29 · SQL Server: Always Encrypted columns. sqlserver-nio can now ask SQL Server which result
/// columns are Always Encrypted (and their real type, deterministic or randomized, and the key path),
/// but Echo has no column master keys, so the values stay ciphertext. Today such a column looks like
/// any varbinary: the grid shows its bytes as hex and lets you edit them. Touches FTR-2.3 (values in
/// the grid) and the cell editor.
@MainActor
enum MssqlAlwaysEncryptedRound {
    enum Cell: String, CaseIterable {
        case lockWord = "EV1 · 🔒 Encrypted, dimmed"
        case word = "EV2 · Encrypted, dimmed, no icon"
        case dimmedHex = "EV3 · The ciphertext, dimmed, with a lock"
        case today = "EV4 · Echo today: the ciphertext as hex"
    }
    enum Header: String, CaseIterable {
        case lock = "EH1 · A lock after the name; details on hover"
        case none = "EH2 · Plain header; details on hover over a cell"
    }
    enum Editing: String, CaseIterable {
        case explain = "ED1 · Read-only, and trying to edit says why"
        case silent = "ED2 · Read-only, nothing said"
    }
    enum Moment: String, CaseIterable {
        case grid = "The grid"
        case hover = "Hovering SSN's header"
        case edit = "Double-clicking an SSN cell"
    }

    private static let width: CGFloat = 640
    private static let height: CGFloat = 300

    static let spec = RoundSpec(
        controls: [
            .of("moment", "Moment", Moment.self, default: .grid),
            .of("cell", "Encrypted cell", Cell.self, default: .lockWord,
                question: "Look at SSN and Salary. How should a value Echo cannot decrypt read?",
                recommend: .lockWord,
                why: "It says what the value is. The ciphertext is noise to a person, and hex reads like data you could copy into a WHERE clause, which would not work. The lock makes encrypted cells easy to spot when scanning a wide result."),
            .of("header", "Column header", Header.self, default: .lock,
                question: "Set Moment to hovering the header. Should the header say the column is encrypted?",
                recommend: .lock,
                why: "You learn it before reading any cell, and the hover is where the details belong: the real type (nvarchar(11)), deterministic or randomized, and the key path, which is what you need to get the key."),
            .of("editing", "Editing", Editing.self, default: .explain,
                question: "Set Moment to double-clicking a cell. What should happen?",
                recommend: .explain,
                why: "Changing a value needs the column master key, which Echo cannot use. Saying so (and naming the key) answers the obvious question; a cell that silently ignores the double-click looks broken."),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today",
                  summary: "Encrypted columns look like varbinary: their ciphertext as hex, editable like any cell.",
                  isEchoToday: true, designWidth: width, designHeight: height) { values in
                MssqlEncryptedGrid(cell: .today, header: .none, editing: nil,
                                   moment: Moment(rawValue: values["moment"]) ?? .grid, today: true)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls.",
                  designWidth: width, designHeight: height) { values in
                MssqlEncryptedGrid(cell: Cell(rawValue: values["cell"]) ?? .lockWord,
                                   header: Header(rawValue: values["header"]) ?? .lock,
                                   editing: Editing(rawValue: values["editing"]) ?? .explain,
                                   moment: Moment(rawValue: values["moment"]) ?? .grid, today: false)
            },
        ],
        questions: [
            .init(id: "copy", title: "Copy",
                  question: "What should Copy put on the clipboard for an encrypted cell?",
                  choices: [
                      .init(id: "hex", name: "CP1 · The ciphertext as hex (0x01…)", summary: "What is stored; SSMS copies the same without keys."),
                      .init(id: "word", name: "CP2 · The word Encrypted"),
                  ],
                  recommended: "hex",
                  why: "Copy should give the value, and the ciphertext is the value Echo has; it pastes into another tool unchanged and can be compared. A word would look like data and lose what is there."),
            .init(id: "metadata", title: "When Echo asks",
                  question: "Telling encrypted columns apart needs one login option (TDS column encryption). Should Echo always ask for it on SQL Server?",
                  choices: [
                      .init(id: "always", name: "AO1 · Always, no setting"),
                      .init(id: "setting", name: "AO2 · A per-connection switch, off by default"),
                  ],
                  recommended: "always",
                  why: "It only adds a description to results and costs nothing; servers before 2016 ignore it. The driver runs its whole test suite with it on in CI. A switch nobody knows to turn on would leave the hex in place."),
        ],
        exhibitTopic: ("Build it?", "Step through Moment in both. Does the proposal make clear what these columns are, and why you cannot change them?",
                       "proposal",
                       "It names encrypted columns for what they are and explains the one thing you cannot do, where Echo today shows bytes and lets you edit them."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "EV1, EH1, ED1.",
                  values: ["cell": Cell.lockWord.rawValue, "header": Header.lock.rawValue, "editing": Editing.explain.rawValue],
                  isRecommended: true),
        ]
    )
}

/// dbo.Patients: Id, SSN (deterministic), Salary and Notes (randomized), as a results card.
struct MssqlEncryptedGrid: View {
    typealias R = MssqlAlwaysEncryptedRound
    let cell: R.Cell
    let header: R.Header
    let editing: R.Editing?
    let moment: R.Moment
    let today: Bool

    private let columns = ["Id", "SSN", "Salary", "Notes"]
    private let encrypted: Set<Int> = [1, 2, 3]
    private let rows: [[String?]] = [
        ["1", "0x01A3F29C4D7E1B88C0…", "0x01772E0B95D4AF3C61…", nil],
        ["2", "0x01A3F29C4D7E1B88C0…", "0x0119C4E8A7302D5F94…", "0x01D2208F6B91C7E344…"],
        ["3", "0x01E06B2A5C9F33D718…", "0x0155B70C1E8A6F2D03…", nil],
    ]

    var body: some View {
        VStack(spacing: SpacingTokens.none) {
            Grid(alignment: .leading, horizontalSpacing: SpacingTokens.md, verticalSpacing: SpacingTokens.xxs) {
                GridRow {
                    ForEach(Array(columns.enumerated()), id: \.offset) { index, name in
                        headerCell(index, name)
                    }
                }
                Divider()
                ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                    GridRow {
                        ForEach(Array(row.enumerated()), id: \.offset) { column, value in
                            valueCell(row: rowIndex, column: column, value: value)
                        }
                    }
                }
            }
            .padding(SpacingTokens.sm)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            Spacer(minLength: SpacingTokens.none)
            PgFooter(database: "sql01 · Clinic") {
                PgPill { Text("3 rows") }
                PgPill { PgStatusLabel(text: "Done", color: ColorTokens.Status.success) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .workspaceCard()
    }

    @ViewBuilder
    private func headerCell(_ index: Int, _ name: String) -> some View {
        HStack(spacing: SpacingTokens.xxs) {
            Text(name).font(TypographyTokens.labelBold).foregroundStyle(ColorTokens.Text.secondary)
            if !today, header == .lock, encrypted.contains(index) {
                Image(systemName: "lock.fill").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
            }
        }
        .overlay(alignment: .topLeading) {
            if !today, moment == .hover, index == 1 {
                hoverCard.offset(x: 0, y: 22).zIndex(1)
            }
        }
        .zIndex(index == 1 ? 1 : 0)
    }

    private var hoverCard: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
            Label("Always Encrypted", systemImage: "lock.fill").font(TypographyTokens.labelBold)
            Text("nvarchar(11) · deterministic").font(TypographyTokens.detail)
            Text("AEAD_AES_256_CBC_HMAC_SHA_256").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
            Text("Key: MSSQL_CERTIFICATE_STORE, CurrentUser/My/0123…4567").font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        .padding(SpacingTokens.xs)
        .fixedSize()
        .background(ColorTokens.Background.secondary, in: RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.small))
        .shadow(radius: 4)
    }

    @ViewBuilder
    private func valueCell(row: Int, column: Int, value: String?) -> some View {
        let isEncrypted = encrypted.contains(column)
        Group {
            if value == nil {
                Text("NULL").font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.tertiary)
            } else if !isEncrypted || today || cell == .today {
                Text(value!).font(TypographyTokens.standard).lineLimit(1)
            } else {
                switch cell {
                case .lockWord:
                    Label("Encrypted", systemImage: "lock.fill").font(TypographyTokens.standard)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                case .word:
                    Text("Encrypted").font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.tertiary)
                case .dimmedHex:
                    Label(value!, systemImage: "lock.fill").font(TypographyTokens.standard).lineLimit(1)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                case .today:
                    EmptyView()
                }
            }
        }
        .overlay(alignment: .topLeading) {
            if moment == .edit, row == 0, column == 1 { editOverlay.offset(y: 20).zIndex(1) }
        }
        .zIndex(row == 0 && column == 1 ? 1 : 0)
    }

    @ViewBuilder
    private var editOverlay: some View {
        if today {
            // Today: an editable text field over the ciphertext.
            Text("0x01A3F29C4D7E1B88C0E2|").font(TypographyTokens.standard)
                .padding(.horizontal, SpacingTokens.xxs)
                .background(ColorTokens.Background.primary)
                .overlay(RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.extraSmall).stroke(ColorTokens.accent))
                .fixedSize()
        } else if editing == .explain {
            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                Label("Can't edit an encrypted value", systemImage: "lock.fill").font(TypographyTokens.labelBold)
                Text("Changing SSN needs the column master key (CurrentUser/My/0123…4567), which Echo cannot use.")
                    .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                    .frame(width: 260, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(SpacingTokens.xs)
            .background(ColorTokens.Background.secondary, in: RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.small))
            .shadow(radius: 4)
        }
    }
}
