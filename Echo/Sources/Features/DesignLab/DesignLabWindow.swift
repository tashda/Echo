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
    case round9 = "Round 9 · open questions"
    case window = "Window · canvas and cards"
    case rail = "Server rail"
    case tree = "Tree · sticky header"
    case results = "Results grid"
    case floating = "Toasts and notifications"
    case inspector = "Inspector"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .round9: "checklist"
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
        case .round9: "The questions round 9 left open. Each stage switches live; the footer sits on a real AppKit table with Echo's real footer, and FB1 uses the blur the app would use. The other pages were settled in earlier rounds and stay as a reference."
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
        case .round9:
            [
                LabQuestion(id: "round9.footerBacking", title: "What shows behind the footer", howTo: "Switch Behind with Rows drift on. Try it in light and dark.", options: ["FB1 Soft blur", "FB2 Hard edge", "FB4 Glass bar"]),
                LabQuestion(id: "round9.footerPosition", title: "Where the footer sits", howTo: "Switch Position, with each Behind option.", options: ["FP1 Lift 4pt", "FP3 Floating"]),
                LabQuestion(id: "round9.scroller", title: "The tree's scroll bar", howTo: "Switch Scroll bar and scroll the tree; SB1 shows only while scrolling.", options: ["SB1 In the gutter", "SB3 None"]),
                LabQuestion(id: "round9.tabs", title: "The tab bar", howTo: "Switch Tab bar; click tabs and + (tabs select at once, as TFIX).", options: ["TB1 Glass capsule", "TB3 In the toolbar", "TB4 Hugging tabs"]),
            ]
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
    @State private var page: DesignLabPage = .round9
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
