import SwiftUI

/// The owner's controls for one page: accept, confirm, send feedback, reopen, and the history.
struct LabFeedbackInspector: View {
    @Environment(LabStore.self) private var store
    let page: LabPage
    /// The element the feedback is about (set from the Spec view), or nil for the whole page.
    @Binding var element: (id: String, name: String)?
    @State private var draft = ""
    private var draftKey: String { "draft." + page.id }

    private var status: LabStatus? { store.status(of: page) }

    var body: some View {
        Form {
            if let status {
                Section("Status") {
                    LabStatusPill(status: status)
                    Text(explanation(status))
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                    actions(status)
                }
                Section(status == .decided ? "Reopen with feedback" : "Feedback") {
                    if let element {
                        HStack {
                            Label("\(element.id) · \(element.name)", systemImage: "scope").font(TypographyTokens.detail)
                            Spacer()
                            Button("Whole page") { self.element = nil }.buttonStyle(.link).font(TypographyTokens.detail)
                        }
                    }
                    TextField("", text: $draft, prompt: Text("What should change?"), axis: .vertical)
                        .lineLimit(3...8)
                    Button(status == .decided ? "Reopen with feedback" : "Send feedback") {
                        store.sendFeedback(page, comment: draft, element: element?.id)
                        draft = ""
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                let comments = store.comments(for: page)
                if !comments.isEmpty {
                    Section("Comments") {
                        ForEach(comments.reversed()) { comment in
                            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                                if let id = comment.element { Text(id).font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(ColorTokens.accent) }
                                Text(LabRoundName.stripped(comment.text))
                                Text(comment.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(TypographyTokens.detail)
                                    .foregroundStyle(ColorTokens.Text.tertiary)
                            }
                        }
                    }
                }
                let history = store.history(for: page)
                if !history.isEmpty {
                    Section("History") {
                        ForEach(Array(history.enumerated().reversed()), id: \.offset) { _, event in
                            HStack {
                                Text(LabRoundName.stripped(event.text))
                                Spacer()
                                Text(event.date.formatted(date: .abbreviated, time: .omitted))
                                    .foregroundStyle(ColorTokens.Text.tertiary)
                            }
                            .font(TypographyTokens.detail)
                        }
                    }
                }
            } else {
                Text("Feedback applies to design pages.")
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { draft = LabPrefs.load(draftKey, default: "") }
        .onChange(of: page.id) { _, _ in draft = LabPrefs.load(draftKey, default: "") }
        .onChange(of: draft) { _, new in LabPrefs.save(new, key: draftKey) }
    }

    @ViewBuilder
    private func actions(_ status: LabStatus) -> some View {
        switch status {
        case .judging, .newFeedback:
            Button("Accept") { store.accept(page) }
        case .accepted:
            EmptyView()
        case .inEcho:
            Button("Confirm in Echo") { store.confirm(page) }
            Button("Move back to New feedback") { store.reopen(page) }
        case .decided:
            Button("Move back to New feedback") { store.reopen(page) }
        }
    }

    private func explanation(_ status: LabStatus) -> String {
        switch status {
        case .newFeedback: "Your feedback is waiting for the agent."
        case .judging: "Try the playground, then accept it or send feedback."
        case .accepted: "Accepted. The agent builds it into Echo next."
        case .inEcho: "Built into Echo. Check it in the running app, then confirm."
        case .decided: "Confirmed and frozen in the library."
        }
    }
}
