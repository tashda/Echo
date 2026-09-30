import SwiftUI

enum LabInspectorVersion: String, CaseIterable, Identifiable {
    case today = "Today"
    case proposed = "Proposed"
    var id: String { rawValue }
}

/// Today's inspector next to the proposed one: one section style, single padding, row-detail mode.
struct LabInspectorPlayground: View {
    @State private var version: LabInspectorVersion = .proposed
    @State private var isWide = false

    var body: some View {
        LabStage(title: "Inspector · row detail and sections") {
            LabPicker(title: "Version", selection: $version, options: LabInspectorVersion.allCases)
            Button(isWide ? "Narrow (row detail)" : "Widen (JSON)") {
                withAnimation(.smooth(duration: 0.3)) { isWide.toggle() }
            }
        } content: {
            HStack(spacing: 0) {
                LabCard { LabEditorText() }
                    .padding(16)
                Divider()
                ScrollView {
                    Group {
                        if version == .today { todayInspector } else { proposedInspector }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(width: isWide ? 420 : 300)
                .background(.background.secondary)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 860, minHeight: 600)
    }

    private let fields: [(String, String)] = [
        ("emp_no", "10003"), ("first_name", "Parto"), ("last_name", "Bamford"),
        ("salary", "43 311"), ("dept_no", "d004"), ("to_date", "NULL"),
    ]

    // MARK: Today

    /// Doubled side padding, uppercase caption labels, boxed values.
    private var todayInspector: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Row 3").font(.title3.weight(.semibold))
            ForEach(fields, id: \.0) { field in
                VStack(alignment: .leading, spacing: 4) {
                    Text(field.0.uppercased()).font(.caption2).foregroundStyle(.secondary)
                    Text(field.1)
                        .font(.system(size: 12))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.12), in: .rect(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.6), lineWidth: 0.6))
                }
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 16)
    }

    // MARK: Proposed

    private var proposedInspector: some View {
        VStack(alignment: .leading, spacing: 16) {
            LabInspectorSection(title: "Row 3 of 12 000", symbol: "tablecells", actions: ["doc.on.doc", "square.and.arrow.up"]) {
                ForEach(fields, id: \.0) { field in
                    LabInspectorRow(label: field.0, value: field.1)
                }
            }
            LabInspectorSection(title: "Related", symbol: "arrow.turn.down.right", actions: []) {
                LabInspectorRow(label: "departments", value: "d004 · Production", isLink: true)
                LabInspectorRow(label: "salaries", value: "18 rows", isLink: true)
            }
        }
        .padding(12)
    }
}

/// One section style for every inspector panel.
struct LabInspectorSection<Content: View>: View {
    let title: String
    let symbol: String
    let actions: [String]
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: symbol).foregroundStyle(.secondary)
                Text(title).font(.system(size: 12, weight: .semibold))
                Spacer()
                ForEach(actions, id: \.self) { action in
                    Image(systemName: action).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)
            VStack(spacing: 0) { content() }
                .background(Color(nsColor: .textBackgroundColor), in: .rect(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.separator, lineWidth: 0.5))
        }
    }
}

/// Label left, value right; the value is selectable.
struct LabInspectorRow: View {
    let label: String
    let value: String
    var isLink = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label).font(.system(size: 11.5)).foregroundStyle(.secondary).lineLimit(1)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: 12).monospacedDigit())
                .italic(value == "NULL")
                .foregroundStyle(value == "NULL" ? AnyShapeStyle(.tertiary) : isLink ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.primary))
                .textSelection(.enabled)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 26)
        .overlay(alignment: .bottom) { Divider().padding(.leading, 10) }
    }
}

#Preview("Inspector · today vs proposed") {
    LabInspectorPlayground()
}
