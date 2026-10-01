import SwiftUI

/// Round 11: the tab bar. Today's glass capsule reads as weaker than the old strip (inactive tabs
/// too light), so this page lays out many directions side by side, each fully clickable.
enum LabTabDesign: String, CaseIterable, Identifiable {
    case todayGlass = "Today · Glass"
    case classic = "Classic"
    case safari = "T1 Safari"
    case filled = "T2 Filled tabs"
    case separatePills = "T3 Separate pills"
    case serverColour = "T4 Server colour"
    case hugging = "T5 Hugging"
    case underline = "T6 Underline"
    case twoLine = "T7 Two-line tabs"
    case accent = "T8 Accent active"
    var id: String { rawValue }

    var isReference: Bool { self == .todayGlass || self == .classic }

    var summary: String {
        switch self {
        case .todayGlass: "What's in the app now: one glass capsule, light inactive tabs, + inside."
        case .classic: "The earlier strip: a grey plate, white active tab, separate glass +."
        case .safari: "Like Safari on macOS 26: a glass capsule, inactive titles in full-strength text with hairline dividers, the active tab a raised white pill."
        case .filled: "Every tab is a faint filled capsule inside the glass bar, like a segmented control, so inactive tabs read as real buttons; the active one is raised white."
        case .separatePills: "No bar: each tab is its own small glass pill, the active one white and raised, with the + as a glass circle after them."
        case .serverColour: "Safari-style, with each tab's server colour: a dot on every tab and a coloured edge on the active one, so you see at a glance which server a tab talks to."
        case .hugging: "Tabs as wide as their titles (within limits), left-aligned in a capsule that grows with them; more tabs scroll with soft edges."
        case .underline: "No plate: titles on the canvas, the active one semibold with a short accent underline; a faint hover fill."
        case .twoLine: "Taller tabs with the title over its database (or the timer while running), in a glass capsule; the most informative, costs 8pt of height."
        case .accent: "A glass capsule where the active tab is filled with the accent colour and white text; inactive tabs in full-strength text."
        }
    }
}

/// One sample tab.
struct LabTabItem: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var database: String
    var symbol: String
    var serverColor: Color
    var isRunning = false
}

struct LabRound11Playground: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(LabTabDesign.allCases) { design in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(design.rawValue).font(.headline)
                        if design.isReference {
                            Text("Reference").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Text(design.summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(width: 760, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    LabTabWindow(design: design)
                }
                .padding(14)
                .background(Color(nsColor: .textBackgroundColor), in: .rect(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.separator, lineWidth: 0.5))
                .fixedSize()
            }
        }
    }
}

/// A slice of the window: the tab bar on the canvas and the top of the editor card.
struct LabTabWindow: View {
    let design: LabTabDesign

    @State private var tabs: [LabTabItem] = [
        LabTabItem(title: "Query 1", database: "employees", symbol: "doc.text", serverColor: .blue),
        LabTabItem(title: "Query 2", database: "employees", symbol: "doc.text", serverColor: .blue, isRunning: true),
        LabTabItem(title: "Activity Monitor", database: "mssql25", symbol: "gauge.with.dots.needle.33percent", serverColor: .red),
        LabTabItem(title: "Query 3", database: "dwh", symbol: "doc.text", serverColor: .orange),
    ]
    @State private var activeID: UUID?

    var body: some View {
        VStack(spacing: 6) {
            LabTabBarView(design: design, tabs: $tabs, activeID: $activeID)
            LabCard { LabEditorText() }
                .frame(height: 90)
        }
        .padding(6)
        .frame(width: 760)
        .background(Color(nsColor: .windowBackgroundColor), in: .rect(cornerRadius: 12))
        .onAppear { activeID = activeID ?? tabs.first?.id }
    }
}
