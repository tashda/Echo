import SwiftUI

/// Round 15: three ways to draw the inspector column without the stacked, cut-off shadows.
enum LabInspectorLook: String, CaseIterable, Identifiable {
    case oneCard = "One card"
    case groupedBoxes = "Grouped boxes"
    case separateCards = "Separate cards, fixed"
    var id: String { rawValue }

    var summary: String {
        switch self {
        case .oneCard: "One workspace card, like a server card in the tree. Sections sit under quiet headers, divided by hairlines."
        case .groupedBoxes: "One card; each section is a rounded inset group, like System Settings."
        case .separateCards: "A card per section, as decided in round 10, with room around them so no shadow is cut off."
        }
    }
}

/// Sample content: a selected cell, its row, and related records.
struct LabR15InspectorSection: Identifiable {
    struct Row: Identifiable {
        let label: String
        let value: String
        var isLink = false
        var id: String { label }
    }

    let title: String
    let subtitle: String?
    let symbol: String
    let actions: [String]
    let rows: [Row]
    var body: String?
    var id: String { title }

    static let samples: [LabR15InspectorSection] = [
        LabR15InspectorSection(title: "salary", subtitle: "integer · Numeric", symbol: "character.cursor.ibeam",
                            actions: ["doc.on.doc", "arrow.up.left.and.arrow.down.right"], rows: [], body: "43311"),
        LabR15InspectorSection(title: "Row 3", subtitle: nil, symbol: "tablecells", actions: ["doc.on.doc"], rows: [
            Row(label: "emp_no", value: "10003"),
            Row(label: "first_name", value: "Parto"),
            Row(label: "last_name", value: "Bamford"),
            Row(label: "salary", value: "43311"),
            Row(label: "dept_no", value: "d004"),
            Row(label: "from_date", value: "2001-12-01"),
            Row(label: "to_date", value: "NULL"),
        ]),
        LabR15InspectorSection(title: "Related", subtitle: nil, symbol: "arrow.turn.down.right", actions: [], rows: [
            Row(label: "departments", value: "d004 · Production", isLink: true),
            Row(label: "salaries", value: "18 rows", isLink: true),
        ]),
    ]
}

/// A section's header: icon, title, subtitle and actions.
struct LabR15InspectorHeader: View {
    let section: LabR15InspectorSection

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xxs2) {
            Image(systemName: section.symbol)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
            VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                Text(section.title).font(TypographyTokens.standard.weight(.semibold))
                if let subtitle = section.subtitle {
                    Text(subtitle).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                }
            }
            Spacer(minLength: SpacingTokens.xs)
            ForEach(section.actions, id: \.self) { action in
                Image(systemName: action)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }
    }
}

/// A section's content: the value for a cell, rows for the rest.
struct LabR15InspectorBody: View {
    let section: LabR15InspectorSection

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            if let text = section.body {
                Text(text)
                    .font(TypographyTokens.code)
                    .textSelection(.enabled)
                    .padding(.vertical, SpacingTokens.xxs)
            }
            ForEach(Array(section.rows.enumerated()), id: \.element.id) { index, row in
                HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.sm) {
                    Text(row.label).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                    Spacer(minLength: SpacingTokens.none)
                    Text(row.value)
                        .font(TypographyTokens.standard.monospacedDigit())
                        .italic(row.value == "NULL")
                        .foregroundStyle(row.isLink ? ColorTokens.accent : row.value == "NULL" ? ColorTokens.Text.tertiary : ColorTokens.Text.primary)
                        .textSelection(.enabled)
                }
                .padding(.vertical, SpacingTokens.xxs)
                .overlay(alignment: .bottom) {
                    if index < section.rows.count - 1 { Divider() }
                }
            }
        }
    }
}
