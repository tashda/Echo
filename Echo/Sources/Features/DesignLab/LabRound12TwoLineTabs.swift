#if DEBUG
import SwiftUI

/// Round 12: two-line versions of round 11's chosen T2 (filled tabs in a glass capsule).
enum LabTwoLineTab: String, CaseIterable, Identifiable {
    case oneLine = "T2 · one line"
    case twoLine = "L1 Two lines"
    case withIcon = "L2 Two lines, icon"
    case serverLine = "L3 Server on line two"
    case activeOnly = "L4 Active tab only"
    case compact = "L5 Compact two lines"
    var id: String { rawValue }

    var isReference: Bool { self == .oneLine }

    var summary: String {
        switch self {
        case .oneLine: "What's in the app now: T2 with the database beside the title."
        case .twoLine: "Title over the database (or the timer while running). Tabs 32pt, the bar 38pt."
        case .withIcon: "Like L1, with the tab kind's icon (query, Activity Monitor) centred on the left."
        case .serverLine: "Line two names the server and database with the server's colour dot, so tabs on different servers are easy to tell apart."
        case .activeOnly: "Inactive tabs keep one line; the active tab shows its second line. Same bar height as L1, calmer overall."
        case .compact: "Two lines squeezed into 28pt tabs (a 34pt bar): 11pt title, 9.5pt second line."
        }
    }

    var tabHeight: CGFloat {
        switch self {
        case .oneLine: 24
        case .compact: 28
        default: 32
        }
    }
}

struct LabRound12Playground: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(LabTwoLineTab.allCases) { design in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(design.rawValue).font(.headline)
                        if design.isReference { Text("Reference").font(.caption).foregroundStyle(.secondary) }
                    }
                    Text(design.summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(width: 760, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    LabTwoLineWindow(design: design)
                }
                .padding(14)
                .background(Color(nsColor: .textBackgroundColor), in: .rect(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.separator, lineWidth: 0.5))
                .fixedSize()
            }
        }
    }
}

private struct LabTwoLineWindow: View {
    let design: LabTwoLineTab

    @State private var tabs: [LabTabItem] = [
        LabTabItem(title: "Query 1", database: "employees", symbol: "doc.text", serverColor: .blue),
        LabTabItem(title: "Query 2", database: "employees", symbol: "doc.text", serverColor: .blue, isRunning: true),
        LabTabItem(title: "Activity Monitor", database: "mssql25", symbol: "gauge.with.dots.needle.33percent", serverColor: .red),
        LabTabItem(title: "Query 3", database: "dwh", symbol: "doc.text", serverColor: .orange),
    ]
    @State private var activeID: UUID?
    @Namespace private var selection

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 2) {
                ForEach(tabs) { tab in
                    LabTwoLineTabButton(
                        design: design,
                        tab: tab,
                        isActive: tab.id == activeID,
                        selection: selection,
                        onSelect: { activeID = tab.id },
                        onClose: { close(tab) }
                    )
                }
                Button {
                    let tab = LabTabItem(title: "Query \(tabs.count + 1)", database: "employees", symbol: "doc.text", serverColor: .blue)
                    tabs.append(tab)
                    activeID = tab.id
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: design.tabHeight)
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
            }
            .padding(3)
            .glassEffect(.regular, in: .capsule)
            .animation(.spring(duration: 0.3, bounce: 0.15), value: activeID)
            .animation(.spring(duration: 0.3, bounce: 0.15), value: tabs)
            LabCard { LabEditorText() }
                .frame(height: 90)
        }
        .padding(6)
        .frame(width: 760)
        .background(Color(nsColor: .windowBackgroundColor), in: .rect(cornerRadius: 12))
        .onAppear { activeID = activeID ?? tabs.first?.id }
    }

    private func close(_ tab: LabTabItem) {
        guard tabs.count > 1, let index = tabs.firstIndex(of: tab) else { return }
        tabs.remove(at: index)
        if activeID == tab.id { activeID = tabs[min(index, tabs.count - 1)].id }
    }
}

private struct LabTwoLineTabButton: View {
    let design: LabTwoLineTab
    let tab: LabTabItem
    let isActive: Bool
    let selection: Namespace.ID
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    private var showsSecondLine: Bool {
        switch design {
        case .oneLine: false
        case .activeOnly: isActive
        default: true
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            leading
            if design == .oneLine {
                HStack(spacing: 4) {
                    title
                    Text(tab.isRunning ? "0:12" : tab.database).font(.system(size: 11).monospacedDigit()).foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: design == .compact ? 0 : 1) {
                    title
                    if showsSecondLine { secondLine }
                }
            }
            Spacer(minLength: 0)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 14, height: 14)
                    .background(Circle().fill(Color.primary.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0)
        }
        .lineLimit(1)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .frame(height: design.tabHeight)
        .background {
            if isActive {
                Capsule()
                    .fill(Color(nsColor: .textBackgroundColor))
                    .shadow(color: .black.opacity(0.16), radius: 1.5, y: 0.5)
                    .matchedGeometryEffect(id: "active", in: selection)
            } else {
                Capsule().fill(Color.primary.opacity(isHovering ? 0.1 : 0.06))
            }
        }
        .contentShape(.capsule)
        .onHover { isHovering = $0 }
        .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in onSelect() })
    }

    @ViewBuilder
    private var leading: some View {
        if tab.isRunning {
            ProgressView().controlSize(.mini)
        } else if design == .withIcon {
            Image(systemName: tab.symbol).font(.system(size: 13)).foregroundStyle(.secondary).frame(width: 16)
        }
    }

    private var title: some View {
        Text(tab.title)
            .font(.system(size: design == .compact ? 11 : 11.5, weight: isActive ? .semibold : .medium))
            .foregroundStyle(Color.primary.opacity(isActive ? 1 : 0.8))
    }

    @ViewBuilder
    private var secondLine: some View {
        Group {
            if tab.isRunning {
                Text(Date().addingTimeInterval(-12), style: .timer)
            } else if design == .serverLine {
                HStack(spacing: 4) {
                    Circle().fill(tab.serverColor).frame(width: 5, height: 5)
                    Text(tab.serverColor == .red ? "mssql25 · master" : "postgres18 · \(tab.database)")
                }
            } else {
                Text(tab.database)
            }
        }
        .font(.system(size: design == .compact ? 9.5 : 10).monospacedDigit())
        .foregroundStyle(.secondary)
    }
}
#endif
