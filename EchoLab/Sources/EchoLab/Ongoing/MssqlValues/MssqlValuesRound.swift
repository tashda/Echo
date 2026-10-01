import SwiftUI

/// Round 22 · SQL Server: values in the grid. Two defects that the owner cannot see until they bite:
/// when every column is a "simple" type, each value after row 200 shows raw wire bytes (the spool
/// stores TDS bytes but reads them back as UTF-8), and in every row the driver dropped fractional
/// seconds and time zone offsets, printed money through floating point, and put a geography point's
/// latitude first. sqlserver-nio now formats each cell exactly (CONVERT style 121, what SSMS shows)
/// and exposes a cell formatter so spooled rows read like live ones. Touches FTR-2.3 (values drawn
/// in the grid) and the result spool.
@MainActor
enum MssqlValuesRound {
    enum Dates: String, CaseIterable {
        case sqlServer = "DF1 · SQL Server style: 2026-09-30 12:34:56.123"
        case iso = "DF2 · ISO 8601: 2026-09-30T12:34:56.123"
        case today = "DF3 · Echo today: 2026-09-30T12:34:56Z"
    }
    enum Offsets: String, CaseIterable {
        case asStored = "DO1 · As stored, with its offset"
        case local = "DO2 · Converted to this Mac's time zone"
    }
    enum Rows: String, CaseIterable {
        case preview = "Rows 199–202"
        case far = "Rows 999–1,002"
    }

    private static let width: CGFloat = 700
    private static let height: CGFloat = 300

    static let spec = RoundSpec(
        controls: [
            .of("rows", "Rows", Rows.self, default: .preview),
            .of("dates", "Dates and times", Dates.self, default: .sqlServer,
                question: "Look at the ordered_at and delivered_at columns. Which form should dates and times take?",
                recommend: .sqlServer,
                why: "It is exactly what SQL Server returns from CONVERT(…, 121) and what SSMS and Azure Data Studio show, so a value you copy matches a WHERE clause and other tools. ISO's T reads like an API payload; today's form drops milliseconds and appends a Z that is not in the data."),
            .of("offsets", "datetimeoffset", Offsets.self, default: .asStored,
                question: "Look at delivered_at, a datetimeoffset. Should Echo show the stored offset or convert to your time zone?",
                recommend: .asStored,
                why: "The offset is part of the value; converting hides it and makes two equal-looking rows differ in the database. SSMS shows it as stored. Today Echo converts to UTC and drops the offset entirely."),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "Rows after 200 show wire bytes; times lose milliseconds and offsets; money is rounded; Cyrillic text is garbled after row 200.",
                  isEchoToday: true, designWidth: width, designHeight: height) { values in
                MssqlValuesExhibit(fixed: false, rows: Rows(rawValue: values["rows"]) ?? .preview, dates: .today, offsets: .asStored)
            },
            .init(id: "proposal", title: "Proposal", summary: "Every row formatted by the driver from the stored wire bytes, identically before and after row 200.",
                  designWidth: width, designHeight: height) { values in
                MssqlValuesExhibit(fixed: true, rows: Rows(rawValue: values["rows"]) ?? .preview,
                                   dates: Dates(rawValue: values["dates"]) ?? .sqlServer,
                                   offsets: Offsets(rawValue: values["offsets"]) ?? .asStored)
            },
        ],
        questions: [
            .init(id: "spool", title: "How rows after the preview are stored",
                  question: "Rows 1–200 are shown while the query runs; later rows go to the on-disk spool and are read back when you scroll. How should they be stored so every row reads the same?",
                  choices: [
                      .init(id: "wire", name: "SS1 · Wire bytes for every row, formatted by the driver",
                            summary: "Like the Postgres fix: sqlserver-nio's SQLServerCellFormatter formats each cell from its stored bytes and column type."),
                      .init(id: "flag", name: "SS2 · Keep today's mix, mark each spool chunk as text or bytes"),
                      .init(id: "text", name: "SS3 · Convert every row to text while streaming"),
                  ],
                  recommended: "wire",
                  why: "One format and one formatter cannot disagree: the driver's tests prove a spooled cell equals the live cell for every SQL Server type, including code-page varchar. SS2 keeps two decoders that already drifted; SS3 costs a string conversion per cell on the streaming hot path and slows large results."),
            .init(id: "money", title: "money and smallmoney",
                  question: "money has four decimals in the database. Should the grid always show them (1234.5000)?",
                  choices: [
                      .init(id: "four", name: "MN1 · Always four decimals, as SSMS"),
                      .init(id: "trim", name: "MN2 · Trim trailing zeros (1234.5)"),
                  ],
                  recommended: "four",
                  why: "Four decimals is the type's precision and what SSMS shows, so amounts line up and nothing looks rounded. Today the value goes through a Double and can be wrong in its last digits (922337203685477.5807 shows as …477.6)."),
            .init(id: "geo", title: "geography points",
                  question: "Today a geography point prints latitude first; SQL Server's STAsText prints longitude first. Follow SQL Server?",
                  choices: [
                      .init(id: "sql", name: "GE1 · Longitude first, as STAsText"),
                      .init(id: "today", name: "GE2 · Latitude first (today)"),
                  ],
                  recommended: "sql",
                  why: "WKT is defined as x y, longitude then latitude; pasting today's value into geography::STGeomFromText moves the point."),
        ],
        exhibitTopic: ("Correct values?", "Switch between the row sets in both. Does every row in the proposal read correctly and the same way?",
                       "proposal",
                       "It shows the values that are in the database for every row, where Echo today shows bytes after row 200 and drops digits from dates and money in every row."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "DF1, DO1.",
                  values: ["dates": Dates.sqlServer.rawValue, "offsets": Offsets.asStored.rawValue], isRecommended: true),
            .init(id: "iso", name: "ISO dates", summary: "DF2, DO1.",
                  values: ["dates": Dates.iso.rawValue, "offsets": Offsets.asStored.rawValue]),
        ]
    )
}

/// A results card for a typical orders query, with the rows chosen by the Rows control.
struct MssqlValuesExhibit: View {
    typealias R = MssqlValuesRound
    let fixed: Bool
    let rows: R.Rows
    let dates: R.Dates
    let offsets: R.Offsets

    private var firstRow: Int { rows == .preview ? 199 : 999 }

    var body: some View {
        VStack(spacing: SpacingTokens.none) {
            PgGrid(columns: ["id", "customer", "city", "total", "ordered_at", "delivered_at"],
                   rows: (0..<4).map(row(_:)),
                   rightAligned: [0, 3])
            Spacer(minLength: SpacingTokens.none)
            PgFooter(database: "sql01 · Sales") {
                PgPill { Text("1,000 rows") }
                PgPill { PgStatusLabel(text: "Done", color: ColorTokens.Status.success) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .workspaceCard()
    }

    private func row(_ offset: Int) -> [String?] {
        let id = firstRow + offset
        if !fixed && id > 200 {
            // Echo today: spooled wire bytes read back as UTF-8. An int is its little-endian
            // bytes shown as hex; nvarchar is UTF-16LE; Cyrillic varchar is in code page 1251.
            let bytes = withUnsafeBytes(of: Int32(id).littleEndian) { Array($0) }
            return [bytes.map { String(format: "%02x", $0) }.joined(separator: " "),
                    "C·u·s·t·o·m·e·r· ·\(id)·",
                    id.isMultiple(of: 2) ? "Ïðàãà" : "Köln",
                    "3f 42 0f 00 00 00 00 00",
                    dateToday, offsetToday]
        }
        return [String(id), "Customer \(id)", id.isMultiple(of: 2) ? "Прага" : "Köln",
                fixed ? "1234.5000" : "1234.5",
                fixed ? orderedAt : dateToday, fixed ? deliveredAt : offsetToday]
    }

    private var dateToday: String { "2026-09-30T12:34:56Z" }
    private var offsetToday: String { "2026-09-30T07:04:56Z" }

    private var orderedAt: String {
        switch dates {
        case .sqlServer: "2026-09-30 12:34:56.123"
        case .iso: "2026-09-30T12:34:56.123"
        case .today: dateToday
        }
    }

    private var deliveredAt: String {
        let separator = dates == .iso ? "T" : " "
        switch offsets {
        case .asStored: return "2026-09-30\(separator)12:34:56.1234567 +05:30"
        case .local: return "2026-09-30\(separator)09:04:56.1234567"
        }
    }
}
