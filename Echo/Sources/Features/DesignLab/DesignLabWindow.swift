#if DEBUG
import AppKit
import SwiftUI

/// Debug-only window that hosts every Design Lab playground inside the running app, so the lab
/// works even when Xcode's canvas can't launch Echo in time. Open it from Help › Design Lab.
struct DesignLabWindow: Scene {
    static let sceneID = "design-lab"

    var body: some Scene {
        Window("Design Lab", id: Self.sceneID) {
            DesignLabRootView()
        }
        .defaultSize(width: 1480, height: 960)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)
    }
}

struct DesignLabCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .help) {
            Button {
                openWindow(id: DesignLabWindow.sceneID)
            } label: {
                Label("Design Lab", systemImage: "paintpalette")
            }
        }
    }
}

// MARK: - Questions

/// One thing to judge on a page: the options being compared, and how to try them.
struct LabQuestion: Identifiable {
    let id: String
    let title: String
    let howTo: String
    let options: [String]

    static let acceptReject = ["Accept", "Reject"]
}

enum DesignLabPage: String, CaseIterable, Identifiable {
    case round14Tabs = "Round 14 · tab bar and pages"
    case round14Dock = "Round 14 · section dock"
    case round14Connections = "Round 14 · connections"
    case round14Sense = "Round 14 · EchoSense selection"
    case round13 = "Tab bar · new directions"
    case treeCard = "Tree card · decided"
    case round12 = "Round 12 · decided"
    case round11 = "Round 11 · decided"
    case round10 = "Round 10 · decided"
    case round9 = "Round 9 · decided"
    case window = "Window · canvas and cards"
    case rail = "Server rail"
    case tree = "Tree · sticky header"
    case results = "Results grid"
    case floating = "Toasts and notifications"
    case inspector = "Inspector"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .round14Tabs: "rectangle.topthird.inset.filled"
        case .round14Dock: "square.grid.3x1.below.line.grid.1x2"
        case .round14Connections: "externaldrive.connected.to.line.below"
        case .round14Sense: "text.badge.star"
        case .round13: "rectangle.topthird.inset.filled"
        case .treeCard: "checkmark.circle"
        case .round12: "rectangle.topthird.inset.filled"
        case .round11: "checkmark.circle"
        case .round10: "checkmark.circle"
        case .round9: "checkmark.circle"
        case .window: "macwindow"
        case .rail: "circle.grid.3x3"
        case .tree: "list.bullet.indent"
        case .results: "tablecells"
        case .floating: "bell"
        case .inspector: "sidebar.right"
        }
    }

    var intro: String {
        switch self {
        case .round14Tabs: "The Maybes from the design board, drawn with SwiftUI on the real canvas and card tokens. Top: R9 Today, N1R and N7, each with the ST1 drawer that slides out under Activity Monitor. Bottom: one window where you pick how a tool's pages open (ST1, ST2, ST3, ST5 or TT6) and in which bar style. Click tabs, pages and +, hover to close; Query 2 is running. Try light, dark and Increase Contrast."
        case .round14Dock: "TC1 from the design board: an icon row under the server name switches what the card shows (Databases, Security, Agent, Management, More). The dock stays pinned while the rows scroll under it with the system's scroll edge effect, and every section remembers its scroll position and open folders. Left: duotone icons (IC2, the new default); right: mono (IC1, the setting). SF Symbols stand in until the Recraft set exists."
        case .round14Connections: "CN5 from the design board: adding and editing a connection happens in Manage Connections' detail pane, with CN2's fields as a native grouped form. Select a connection and edit it in place; + adds a new one with the same form; Save with an empty server shows the inline message (CR1); the port shows the engine's default (CR2); Security and timeouts fold into one line and remember it (CR7); Test reports next to the buttons (CR4)."
        case .round14Sense: "ESR4 and ESR5 from the design board, in a small editor you can type in. Rows follow ES1 (letter badge, name in the editor font with your letters highlighted, alias, type) and ES4 (the details footer as an inset rounded panel). Compare the three selection styles, and change Card Corners to see the popup follow the Appearance setting."
        case .round13: "Three new single-line tab bars, shown against the tree and editor cards. Click tabs and +, and hover a tab to close it. These are proposals only; choosing one does not change Echo's current tab bar."
        case .treeCard: "Decided: S4 Quiet, colourful icons in the Vivid palette, dimmed schema prefix, server folders as folders, and tree blueprints. Kept as a reference. The content of the server cards, redrawn six ways beside the original tree. The card itself stays as it is. Every tree is live and they share one state: click folders to open them, hover rows, click to select. The controls above the trees apply to all of them: icon mode (every style has colourful and monochrome), palette, how schema names show, and whether server folders are folders or headings."
        case .round12: "Two-line versions of T2 (round 11's pick). Every design is live: click tabs, hover for the close button, press +. Query 2 is running, so its second line is a timer."
        case .round11: "Decided in round 11: T2 filled tabs. Kept as a reference. The tab bar, again: today's glass capsule feels weaker than the old strip, with inactive tabs too light. Every design below is live: click tabs, hover them for the close button, press +. Query 2 is running. Pick one, or combine: say which in the note."
        case .round10: "Decided in round 10: a pill per entry on the footer's right, and the database switcher as a card above the pill that rises in. Kept as a reference."
        case .round9: "Decided in round 9: FB1 soft blur, FP1 lift 4pt, SB3 no tree scroll bar, TB1 glass tab bar. Kept as a reference."
        case .window: "The whole window in miniature. Use the controls above the mock window to switch each option; the mock responds live."
        case .rail: "The server rail on its own. Click servers to see the selection move."
        case .tree: "The Explorer tree. Scroll it to see the server header pin at the top and grow a breadcrumb."
        case .results: "The results card. Hover rows and headers; the blue range shows the new selection outline."
        case .floating: "Toasts and the notification history, all Liquid Glass that melts together."
        case .inspector: "Today's inspector next to the proposed one."
        }
    }

    var questions: [LabQuestion] {
        switch self {
        case .round14Tabs:
            [
                LabQuestion(id: "round14-bar-style", title: "Which tab bar?", howTo: "Compare the three windows at the top against the tree and editor cards, in light and dark.", options: LabRound14BarStyle.allCases.map(\.rawValue)),
                LabQuestion(id: "round14-page-style", title: "How should a tool's pages open?", howTo: "In the bottom window, switch Pages and Bar, then move between Activity Monitor and Query 2.", options: LabRound14PageStyle.allCases.map(\.rawValue)),
            ]
        case .round14Dock:
            [
                LabQuestion(id: "round14-dock", title: "Section dock", howTo: "Scroll Databases, open and close folders, switch to Agent and back. Does it keep your place, and does the pinned dock read well?", options: ["Accept", "Refine", "Reject"]),
                LabQuestion(id: "round14-dock-labels", title: "Dock buttons", howTo: "Switch Dock between Icons only and Icons + current title.", options: LabDockLabels.allCases.map(\.rawValue)),
                LabQuestion(id: "round14-dock-edge", title: "Edge under the dock", howTo: "Scroll rows under the dock with Soft and Hard edge.", options: LabDockEdge.allCases.map(\.rawValue)),
            ]
        case .round14Connections:
            [LabQuestion(id: "round14-cn5", title: "Edit inside Manage Connections", howTo: "Select connections, change fields, press Save with the server empty, press +, press Test.", options: ["Accept", "Refine", "Reject"])]
        case .round14Sense:
            [
                LabQuestion(id: "round14-esr4", title: "Selected suggestion", howTo: "Type on line 1, then press ↓ and ↑, in each Selection style.", options: LabSenseSelection.allCases.map(\.rawValue)),
                LabQuestion(id: "round14-esr5", title: "Popup corners", howTo: "Switch Card Corners from 10 to 26 in each Popup corners mode.", options: LabSenseCorners.allCases.map(\.rawValue)),
            ]
        case .round13:
            [LabQuestion(id: "round13-tab-direction", title: "Which direction feels at home in Echo?", howTo: "Compare the selected tab against the editor card, then try switching and adding tabs. Add any combination or adjustment in the note.", options: LabNewTabDesign.allCases.map(\.rawValue))]
        case .treeCard:
            []
        case .round12:
            []
        case .round11:
            []
        case .round10:
            []
        case .round9:
            []
        case .window, .rail, .tree, .results, .floating, .inspector:
            // Settled in rounds 3 to 8 (Design/decisions.md); the pages stay as a visual reference.
            []
        }
    }
}

/// Answers kept on this Mac (UserDefaults) until they're copied and sent back.
@Observable @MainActor
final class DesignLabAnswers {
    struct Answer: Codable, Equatable { var choice: String = ""; var note: String = "" }

    private static let key = "designLab.answers.v1"
    var answers: [String: Answer] = [:]

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let stored = try? JSONDecoder().decode([String: Answer].self, from: data) {
            answers = stored
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(answers) { UserDefaults.standard.set(data, forKey: Self.key) }
    }

    func binding(_ id: String) -> Binding<Answer> {
        Binding(get: { self.answers[id] ?? Answer() }, set: { self.answers[id] = $0; self.save() })
    }

    /// Answers to the questions on the pages now, not to questions retired since.
    var answeredCount: Int {
        DesignLabPage.allCases.flatMap(\.questions).filter { !(answers[$0.id]?.choice ?? "").isEmpty }.count
    }

    func summary() -> String {
        var lines = ["Design Lab results"]
        for page in DesignLabPage.allCases {
            lines.append("")
            lines.append(page.rawValue)
            for question in page.questions {
                let answer = answers[question.id] ?? Answer()
                var line = "- \(question.title): \(answer.choice.isEmpty ? "—" : answer.choice)"
                if !answer.note.isEmpty { line += " · \(answer.note)" }
                lines.append(line)
            }
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Root

private struct DesignLabRootView: View {
    @State private var page: DesignLabPage = .treeCard
    @State private var answers = DesignLabAnswers()
    @State private var copied = false

    private var totalQuestions: Int { DesignLabPage.allCases.reduce(0) { $0 + $1.questions.count } }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            ScrollView([.vertical, .horizontal]) {
                VStack(alignment: .leading, spacing: 16) {
                    judgePanel
                    playground
                }
                .padding(24)
                .frame(minWidth: 1180, alignment: .topLeading)
            }
        }
        .frame(minWidth: 1100, minHeight: 760)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Design Lab").font(.title3.weight(.semibold)).padding(.bottom, 8)
            ForEach(DesignLabPage.allCases) { item in
                Button { page = item } label: {
                    HStack {
                        Label(item.rawValue, systemImage: item.symbol)
                        Spacer()
                        let done = item.questions.filter { !(answers.answers[$0.id]?.choice ?? "").isEmpty }.count
                        Text("\(done)/\(item.questions.count)").monospacedDigit().foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 28)
                    .background(page == item ? Color.accentColor.opacity(0.16) : .clear, in: .rect(cornerRadius: 7))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Text("\(answers.answeredCount) of \(totalQuestions) answered").font(.callout).foregroundStyle(.secondary)
            Button(copied ? "Copied" : "Copy results") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(answers.summary(), forType: .string)
                copied = true
                Task { @MainActor in try? await Task.sleep(for: .seconds(2)); copied = false }
            }
            .buttonStyle(.borderedProminent)
            Text("Paste the results into the chat with Claude.").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(width: 250)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.background.secondary)
    }

    private var judgePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(page.rawValue).font(.title2.weight(.semibold))
            Text(page.intro).foregroundStyle(.secondary)
            Divider()
            Text("What to judge").font(.headline)
            ForEach(Array(page.questions.enumerated()), id: \.element.id) { index, question in
                LabQuestionRow(number: index + 1, question: question, answer: answers.binding(question.id))
            }
        }
        .padding(16)
        .fixedSize(horizontal: true, vertical: false)
        .background(Color(nsColor: .textBackgroundColor), in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.separator, lineWidth: 0.5))
    }

    @ViewBuilder
    private var playground: some View {
        switch page {
        case .round14Tabs: LabRound14TabsPlayground()
        case .round14Dock: LabRound14DockPlayground()
        case .round14Connections: LabRound14ManageConnections().padding(SpacingTokens.md)
        case .round14Sense: LabRound14SensePlayground()
        case .round13: LabRound13Playground()
        case .treeCard: LabTreeCardPlayground()
        case .round12: LabRound12Playground()
        case .round11: LabRound11Playground()
        case .round10: LabRound10Playground()
        case .round9: LabRound9Playground()
        case .window: LabWindowPlayground()
        case .rail: LabRailPlayground()
        case .tree: LabTreePlayground()
        case .results: LabResultsPlayground()
        case .floating: LabFloatingPlayground()
        case .inspector: LabInspectorPlayground()
        }
    }
}

private struct LabQuestionRow: View {
    let number: Int
    let question: LabQuestion
    @Binding var answer: DesignLabAnswers.Answer

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)").font(.callout.weight(.semibold)).monospacedDigit().foregroundStyle(.secondary).frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(question.title).font(.body.weight(.medium))
                Text(question.howTo).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 420, alignment: .leading)
            Picker("", selection: $answer.choice) {
                Text("—").tag("")
                ForEach(question.options, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            TextField("Note", text: $answer.note)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
        }
    }
}
#endif
