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
    case window = "Window · canvas and cards"
    case rail = "Server rail"
    case tree = "Tree · sticky header"
    case results = "Results grid"
    case floating = "Toasts and notifications"
    case inspector = "Inspector"

    var id: String { rawValue }

    var symbol: String {
        switch self {
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
        case .window:
            [
                LabQuestion(id: "window.corners", title: "Card corners", howTo: "Switch Corners and compare the cards' corners with the mock window's own corners.", options: ["Concentric", "12pt", "16pt"]),
                LabQuestion(id: "window.shadow", title: "Card shadow", howTo: "Switch Shadow.", options: ["Floating shadow", "Hairline"]),
                LabQuestion(id: "window.gutter", title: "Gutter between rail, tree and cards", howTo: "Switch Gutter.", options: ["4pt", "6pt", "8pt"]),
                LabQuestion(id: "window.treehide", title: "Hiding the tree", howTo: "Press Hide tree / Show tree (or ⌃⌘S) with each Hide tree style, at Default and Fast speed.", options: ["Tree shrinks into rail", "Cards slide over"]),
                LabQuestion(id: "window.serverclick", title: "Clicking a server while the tree is hidden", howTo: "Hide the tree, then click TI in the rail. Try each Server click option; with the last one, also ⌘-click.", options: ["Peek", "Reopen tree", "Peek · ⌘-click reopens"]),
                LabQuestion(id: "window.tabs", title: "Tab strip position", howTo: "Switch Tabs.", options: ["On canvas", "In editor card"]),
                LabQuestion(id: "window.results", title: "Results card appearing", howTo: "Press Close results, then Run query.", options: LabQuestion.acceptReject),
            ]
        case .rail:
            [
                LabQuestion(id: "rail.selection", title: "Selected server", howTo: "Pick each Selection style, click servers and use Jump first ↔ last.", options: ["White disc", "Liquid stretch", "Glass lens"]),
                LabQuestion(id: "rail.identity", title: "Selected monogram colour", howTo: "Switch Identity.", options: ["Accent", "Server colour"]),
                LabQuestion(id: "rail.pulse", title: "Connecting pulse", howTo: "Press Connect a server and watch the new monogram until it connects.", options: ["Accept", "Too strong", "Too subtle"]),
                LabQuestion(id: "rail.growth", title: "Pill growing and shrinking", howTo: "Connect and disconnect a few servers.", options: LabQuestion.acceptReject),
                LabQuestion(id: "rail.canvas", title: "Rail on the translucent canvas", howTo: "Switch Canvas to Translucent.", options: LabQuestion.acceptReject),
            ]
        case .tree:
            [
                LabQuestion(id: "tree.header", title: "Server header style", howTo: "Switch Header and scroll down through a server.", options: ["Bold", "Small caps"]),
                LabQuestion(id: "tree.breadcrumb", title: "Pinned header with breadcrumb", howTo: "Scroll into a database: the header should pin and show \"› database\" over a soft fade.", options: LabQuestion.acceptReject),
                LabQuestion(id: "tree.monochrome", title: "Monochrome icon mode", howTo: "Compare Monochrome and Mono + accent on open.", options: ["Monochrome", "Mono + accent on open"]),
                LabQuestion(id: "tree.colourful", title: "Colourful icon mode", howTo: "Pick Soft colour.", options: LabQuestion.acceptReject),
            ]
        case .results:
            [
                LabQuestion(id: "results.header", title: "Column header", howTo: "Switch Header; hover a header to see the sort arrow.", options: ["Today · name", "Name + type line", "Name, type chip, keys"]),
                LabQuestion(id: "results.hover", title: "Row hover", howTo: "Switch Hover and move the pointer over rows.", options: ["No hover", "Row tint", "Tint + row number"]),
                LabQuestion(id: "results.selection", title: "Selection outline (one outline, active cell ring)", howTo: "Look at the blue range in the salary column.", options: LabQuestion.acceptReject),
                LabQuestion(id: "results.footer", title: "Footer: loaded of total rows and selection sum", howTo: "Look at the footer under the grid.", options: ["Both", "Rows only", "Neither"]),
                LabQuestion(id: "results.context", title: "Where the server › database bar lives", howTo: "Switch Connection bar.", options: ["Results card footer", "Window bottom bar"]),
                LabQuestion(id: "results.mono", title: "Monospaced cells as a setting", howTo: "Toggle Monospaced cells.", options: LabQuestion.acceptReject),
            ]
        case .floating:
            [
                LabQuestion(id: "floating.stack", title: "Stacked toasts melting together", howTo: "Press Post notification three times quickly; let them dismiss.", options: LabQuestion.acceptReject),
                LabQuestion(id: "floating.expand", title: "Toast expanding on hover", howTo: "Hover a toast.", options: LabQuestion.acceptReject),
                LabQuestion(id: "floating.repeat", title: "Repeats collapse to ×2, ×3", howTo: "Press Post the same one again.", options: LabQuestion.acceptReject),
                LabQuestion(id: "floating.history", title: "History card growing out of the bell", howTo: "Click the bell.", options: LabQuestion.acceptReject),
            ]
        case .inspector:
            [
                LabQuestion(id: "inspector.proposed", title: "Proposed inspector", howTo: "Switch Version between Today and Proposed.", options: ["Proposed", "Today", "Needs work"]),
                LabQuestion(id: "inspector.width", title: "Width change when JSON opens", howTo: "Press Widen / Narrow.", options: LabQuestion.acceptReject),
            ]
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

    var answeredCount: Int { answers.values.filter { !$0.choice.isEmpty }.count }

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
    @State private var page: DesignLabPage = .window
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
        .frame(maxWidth: 1080, alignment: .leading)
        .background(Color(nsColor: .textBackgroundColor), in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.separator, lineWidth: 0.5))
    }

    @ViewBuilder
    private var playground: some View {
        switch page {
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
            .frame(maxWidth: 380)
            TextField("Note", text: $answer.note)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
        }
    }
}
#endif
