#if DEBUG
import SwiftUI

enum LabHeaderDesign: String, CaseIterable, Identifiable {
    case today = "Today · name"
    case typeLine = "Name + type line"
    case rich = "Name, type chip, keys"
    var id: String { rawValue }
}

enum LabRowHover: String, CaseIterable, Identifiable {
    case none = "No hover"
    case tint = "Row tint"
    case tintNumber = "Tint + row number"
    var id: String { rawValue }
}

enum LabContextBar: String, CaseIterable, Identifiable {
    case resultsFooter = "Results card footer"
    case windowBar = "Window bottom bar"
    var id: String { rawValue }
}

struct LabColumn: Identifiable {
    let id: String
    let type: String
    var isPrimaryKey = false
    var isForeignKey = false
    var isNullable = false
    var isNumeric = false
    var width: CGFloat
}

enum LabResultsData {
    static let columns: [LabColumn] = [
        LabColumn(id: "emp_no", type: "int4", isPrimaryKey: true, isNumeric: true, width: 92),
        LabColumn(id: "first_name", type: "varchar(14)", width: 130),
        LabColumn(id: "salary", type: "int4", isNumeric: true, width: 96),
        LabColumn(id: "dept_no", type: "char(4)", isForeignKey: true, width: 90),
        LabColumn(id: "active", type: "bool", width: 70),
        LabColumn(id: "to_date", type: "date", isNullable: true, isNumeric: true, width: 110),
    ]

    static let rows: [[String]] = [
        ["10001", "Georgi", "88 958", "d005", "true", "9999-01-01"],
        ["10002", "Bezalel", "72 527", "d007", "true", "9999-01-01"],
        ["10003", "Parto", "43 311", "d004", "false", "NULL"],
        ["10004", "Chirstian", "74 057", "d004", "true", "9999-01-01"],
        ["10005", "Kyoichi", "94 692", "d003", "true", "9999-01-01"],
        ["10006", "Anneke", "59 755", "d005", "false", "NULL"],
        ["10007", "Tzvetan", "88 070", "d008", "true", "9999-01-01"],
        ["10008", "Saniya", "52 668", "d005", "true", "2000-07-31"],
        ["10009", "Sumant", "94 409", "d006", "true", "9999-01-01"],
        ["10010", "Duangkaew", "80 324", "d004", "false", "NULL"],
        ["10011", "Mary", "56 753", "d009", "true", "1996-11-09"],
        ["10012", "Patricio", "54 423", "d005", "true", "9999-01-01"],
    ]
}

/// A static mock of the result grid, used inside the window playground.
struct LabResultsGridMock: View {
    var header: LabHeaderDesign = .typeLine
    var hover: LabRowHover = .tint
    var monospaced = false
    var showsFooter = true

    @State private var hoveredRow: Int?
    private let selectedRows = 2...4
    private let selectedColumns = 2...2

    var body: some View {
        VStack(spacing: 0) {
            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 0) {
                    headerRow
                    ForEach(LabResultsData.rows.indices, id: \.self) { index in
                        dataRow(index)
                    }
                }
                .overlay(alignment: .topLeading) { selectionOutline }
            }
            if showsFooter { footer }
        }
    }

    // MARK: Header

    private var headerRow: some View {
        HStack(spacing: 0) {
            Text("#").font(.system(size: 11)).foregroundStyle(.tertiary).frame(width: 44)
            ForEach(LabResultsData.columns) { column in
                LabHeaderCell(column: column, design: header)
                    .frame(width: column.width, alignment: column.isNumeric ? .trailing : .leading)
            }
        }
        .frame(height: header == .today ? 26 : 38)
        .background(header == .rich ? Color.primary.opacity(0.03) : .clear)
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: Rows

    private func dataRow(_ index: Int) -> some View {
        let isSelectedRow = selectedRows.contains(index)
        let isHovered = hoveredRow == index && hover != .none
        return HStack(spacing: 0) {
            Text("\(index + 1)")
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(isSelectedRow || (isHovered && hover == .tintNumber) ? Color.accentColor : Color.secondary.opacity(0.7))
                .frame(width: 44, alignment: .trailing)
                .padding(.trailing, 6)
                .frame(width: 44)
            ForEach(Array(LabResultsData.columns.enumerated()), id: \.offset) { offset, column in
                cell(LabResultsData.rows[index][offset], column: column)
                    .frame(width: column.width, alignment: column.isNumeric ? .trailing : .leading)
            }
        }
        .frame(height: 24)
        .background {
            if isHovered {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.primary.opacity(0.045))
                    .padding(.horizontal, 3)
            }
        }
        .onHover { inside in hoveredRow = inside ? index : (hoveredRow == index ? nil : hoveredRow) }
        .animation(.easeOut(duration: 0.1), value: hoveredRow)
    }

    @ViewBuilder
    private func cell(_ value: String, column: LabColumn) -> some View {
        Group {
            if value == "NULL" {
                Text("NULL").italic().foregroundStyle(.tertiary)
            } else if column.type == "bool" {
                Image(systemName: value == "true" ? "checkmark" : "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(value == "true" ? Color.accentColor : Color.secondary)
            } else {
                Text(value).foregroundStyle(.primary)
            }
        }
        .font(monospaced ? .system(size: 12, design: .monospaced) : .system(size: 12).monospacedDigit())
        .lineLimit(1)
        .padding(.horizontal, 10)
    }

    /// One outline around the whole selected range, plus a ring on the active cell.
    private var selectionOutline: some View {
        let columns = LabResultsData.columns
        let x = 44 + columns.prefix(selectedColumns.lowerBound).reduce(0) { $0 + $1.width }
        let width = columns[selectedColumns].reduce(0) { $0 + $1.width }
        let top = (header == .today ? 26 : 38) + CGFloat(selectedRows.lowerBound) * 24
        let height = CGFloat(selectedRows.count) * 24
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.accentColor.opacity(0.14))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 1))
                .frame(width: width, height: height)
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(Color.accentColor, lineWidth: 2)
                .frame(width: width, height: 24)
        }
        .offset(x: x, y: top)
        .allowsHitTesting(false)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 10) {
            Text("12 000 of 1.2 M rows").monospacedDigit()
            Text("·").foregroundStyle(.tertiary)
            Text("3 cells · Σ 190 495 · avg 63 498").monospacedDigit().foregroundStyle(.secondary)
            Spacer()
            Text("184 ms").monospacedDigit().foregroundStyle(.secondary)
        }
        .font(.system(size: 11))
        .padding(.horizontal, 12)
        .frame(height: 26)
        .background(Color.primary.opacity(0.03))
        .overlay(alignment: .top) { Divider() }
    }
}

struct LabHeaderCell: View {
    let column: LabColumn
    let design: LabHeaderDesign

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 4) {
            if design == .rich && (column.isPrimaryKey || column.isForeignKey) {
                Image(systemName: column.isPrimaryKey ? "key.fill" : "arrow.turn.down.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(column.isPrimaryKey ? Color.orange : Color.accentColor)
            }
            VStack(alignment: column.isNumeric ? .trailing : .leading, spacing: 1) {
                Text(column.id)
                    .font(.system(size: 12, weight: design == .today ? .medium : .semibold))
                    .lineLimit(1)
                switch design {
                case .today:
                    EmptyView()
                case .typeLine:
                    Text(column.type).font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary)
                case .rich:
                    HStack(spacing: 3) {
                        Text(column.type)
                            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.primary.opacity(0.06), in: Capsule())
                        if column.isNullable {
                            Text("NULL").font(.system(size: 9, weight: .medium)).foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.secondary)
                }
            }
            if design != .today {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .opacity(isHovering ? 1 : 0)
            }
        }
        .padding(.horizontal, 10)
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .overlay(alignment: .trailing) { Rectangle().fill(.separator).frame(width: 0.5, height: 14) }
    }
}

struct LabResultsPlayground: View {
    @State private var header: LabHeaderDesign = .typeLine
    @State private var hover: LabRowHover = .tint
    @State private var monospaced = false
    @State private var contextBar: LabContextBar = .resultsFooter

    var body: some View {
        LabStage(title: "Results · header, hover, selection, footer") {
            LabPicker(title: "Header", selection: $header, options: LabHeaderDesign.allCases)
            LabPicker(title: "Hover", selection: $hover, options: LabRowHover.allCases)
            Toggle("Monospaced cells", isOn: $monospaced)
            LabPicker(title: "Connection bar", selection: $contextBar, options: LabContextBar.allCases)
        } content: {
            VStack(spacing: 8) {
                VStack(spacing: 0) {
                    LabResultsGridMock(header: header, hover: hover, monospaced: monospaced, showsFooter: true)
                    if contextBar == .resultsFooter { contextStrip.overlay(alignment: .top) { Divider() } }
                }
                .background(Color(nsColor: .textBackgroundColor), in: .rect(cornerRadius: 14))
                .clipShape(.rect(cornerRadius: 14))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 3)
                .padding(12)

                if contextBar == .windowBar {
                    contextStrip
                        .background(.bar)
                        .overlay(alignment: .top) { Divider() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 820, height: 620)
    }

    /// Server › database picker, result panes, running state.
    private var contextStrip: some View {
        HStack(spacing: 10) {
            Button {} label: {
                HStack(spacing: 5) {
                    Circle().fill(.blue).frame(width: 7, height: 7)
                    Text("postgres18").foregroundStyle(.secondary)
                    Image(systemName: "chevron.right").font(.system(size: 8, weight: .semibold)).foregroundStyle(.tertiary)
                    Text("employees")
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 8, weight: .semibold)).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .frame(height: 22)
                .background(Color.primary.opacity(0.06), in: Capsule())
            }
            .buttonStyle(.plain)
            Picker("", selection: .constant(0)) {
                Image(systemName: "tablecells").tag(0)
                Image(systemName: "text.bubble").tag(1)
                Image(systemName: "flowchart").tag(2)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            Spacer()
            HStack(spacing: 5) {
                Circle().fill(.green).frame(width: 6, height: 6)
                Text("Completed")
            }
            .foregroundStyle(.secondary)
        }
        .font(.system(size: 11))
        .controlSize(.small)
        .padding(.horizontal, 12)
        .frame(height: 32)
    }
}

#Preview("Results · header, hover, selection, footer") {
    LabResultsPlayground()
}
#endif
