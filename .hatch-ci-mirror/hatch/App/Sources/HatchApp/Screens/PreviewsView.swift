import SwiftUI
import AppKit
import HatchCore

/// Previews (decisions J1 to J6): choose To-verify tickets, build one Preview, verify per ticket, then merge what is approved.
struct PreviewsView: View {
    @EnvironmentObject var state: AppState

    @State private var selected: Set<Int> = []
    @State private var building = false
    @State private var outcome: HXPreviewOutcome?
    @State private var ciText = ""
    @State private var mergeSteps: [HXMergeAdapter.Step] = []
    @State private var merging = false
    @State private var needsWorkFor: Int?
    @State private var needsNote = ""
    @State private var screenshot: URL?
    @State private var checked: Set<String> = []
    @State private var confirmDiscard = false

    // MARK: Data

    private var appRepo: Repo? {
        guard let project = state.hxProject else { return nil }
        let repo: Repo? = try? state.store.repo(projectId: project.id, role: .app)
        return repo
    }

    private var designRepo: Repo? {
        guard let project = state.hxProject else { return nil }
        let repo: Repo? = try? state.store.repo(projectId: project.id, role: .designSystem)
        return repo
    }

    private var toVerify: [Ticket] {
        let filter = TicketFilter(projectId: state.projectFilterId, statuses: [.toVerify])
        return (try? state.store.tickets(filter)) ?? []
    }

    private var latestPreview: HatchCore.Preview? {
        let all = (try? state.store.previews()) ?? []
        return all.last { $0.state != "discarded" }
    }

    private var previewTickets: [PreviewTicket] {
        guard let p = latestPreview else { return [] }
        return (try? state.store.previewTickets(previewId: p.id)) ?? []
    }

    private func ticket(_ id: Int) -> Ticket? {
        let t: Ticket? = try? state.store.ticket(id: id)
        return t
    }

    private func hasWorkspace(_ t: Ticket, in repo: Repo?) -> Bool {
        guard let repo else { return false }
        let ws: Workspace? = try? state.store.workspace(ticketId: t.id, repoId: repo.id)
        return ws != nil
    }

    private var integrationBranch: String { state.hxProject?.config?.integrationBranch ?? "hatch" }

    private var approved: [Ticket] {
        var out: [Ticket] = []
        for pt in previewTickets where pt.verdict == "looks-right" {
            if let t = ticket(pt.ticketId), t.status == .toVerify { out.append(t) }
        }
        return out
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HXHeader(title: "Previews", subtitle: "Verify several finished tickets in one build. You decide per ticket.")
                chooser
                resultSection
                verificationSection
                mergeSection
            }
            .padding(20)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .onAppear { refreshCI() }
    }

    // MARK: Choose tickets (J1)

    private var chooser: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Choose tickets").font(.headline)
            if appRepo == nil {
                ContentUnavailableView {
                    Label("No app repository", systemImage: "externaldrive.badge.questionmark")
                } description: {
                    Text("Add the app repository in Project settings, then choose finished tickets here.")
                }
            } else if toVerify.isEmpty {
                ContentUnavailableView {
                    Label("Nothing to verify", systemImage: "checkmark.circle")
                } description: {
                    Text("Tickets appear here when an agent finishes them. Then you pick the ones to look at together.")
                }
            } else {
                HXCard {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(toVerify) { t in chooserRow(t) }
                    }
                }
                HStack(spacing: 10) {
                    buildButton
                    Text(selected.isEmpty ? "Select the tickets to look at together." : "\(selected.count) selected").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    /// The one prominent action on the screen: Build while nothing is approved, Merge once something is.
    private var buildButton: some View {
        let label = Label(building ? "Building..." : "Build Preview", systemImage: "hammer")
        let off = selected.isEmpty || building || appRepo == nil
        return Group {
            if approved.isEmpty {
                Button { buildPreview() } label: { label }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
            } else {
                Button { buildPreview() } label: { label }
                    .buttonStyle(.glass)
            }
        }
        .disabled(off)
    }

    private func chooserRow(_ t: Ticket) -> some View {
        let ready = hasWorkspace(t, in: appRepo)
        return HStack(spacing: 8) {
            Toggle("", isOn: Binding(
                get: { selected.contains(t.id) },
                set: { on in
                    if on { selected.insert(t.id) } else { selected.remove(t.id) }
                }
            ))
            .labelsHidden()
            .disabled(!ready)
            Text(t.displayNumber).font(.callout.monospacedDigit()).foregroundStyle(.secondary)
            Text(t.title).lineLimit(1)
            Spacer()
            if !ready {
                Text("no workspace yet").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Result (J2)

    @ViewBuilder private var resultSection: some View {
        if let o = outcome {
            VStack(alignment: .leading, spacing: 8) {
                if let message = o.errorText {
                    errorCard(message)
                } else if o.conflictTicket != nil {
                    conflictCard(o)
                } else {
                    cleanCard(o)
                }
            }
        }
    }

    private func errorCard(_ message: String) -> some View {
        HXCard {
            VStack(alignment: .leading, spacing: 4) {
                HXProblemChip(text: "Could not build")
                Text(message).font(.callout).textSelection(.enabled)
            }
        }
    }

    private func cleanCard(_ o: HXPreviewOutcome) -> some View {
        HXCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(o.name).font(.headline)
                    HXChip(text: "Merged cleanly", turn: .finished)
                    if o.buildOK {
                        HXChip(text: "Built", turn: .finished)
                    } else {
                        HXProblemChip(text: "Build failed")
                    }
                    Spacer()
                    openButton(name: o.name)
                }
                if !o.buildOK && !o.buildLog.isEmpty {
                    Text(o.buildLog).font(.caption.monospaced()).textSelection(.enabled).lineLimit(12)
                }
            }
        }
    }

    private func openButton(name: String) -> some View {
        let path = state.hxSetting("preview_app_path")
        let appName = state.hxProject?.name ?? "app"
        return HStack(spacing: 8) {
            if path == nil {
                Text("Set the Preview app path in Settings.").font(.caption).foregroundStyle(.secondary)
            }
            Button {
                if let path { NSWorkspace.shared.open(URL(fileURLWithPath: path)) }
            } label: {
                Label("Open \(appName) (\(name))", systemImage: "play")
            }
            .buttonStyle(.glass)
            .disabled(path == nil)
        }
    }

    private func conflictCard(_ o: HXPreviewOutcome) -> some View {
        let later = o.conflictTicket.flatMap { ticket($0) }
        let earlier = o.conflictAgainst.flatMap { ticket($0) }
        let pair = "\(later?.displayNumber ?? "?") and \(earlier?.displayNumber ?? "?")"
        return HXCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(o.name).font(.headline)
                    HXProblemChip(text: "Conflict")
                }
                Text("\(pair) change the same code and cannot be merged together.").font(.callout)
                if !o.conflictFiles.isEmpty {
                    Text(o.conflictFiles.joined(separator: "\n")).font(.caption.monospaced()).foregroundStyle(.secondary)
                }
                Text("Recommended: stack \(later?.displayNumber ?? "it") on \(earlier?.displayNumber ?? "the other"). Both tickets stay in, and the later one builds on the earlier one's finished work.")
                    .font(.callout)
                HStack {
                    Button { stackConflict(o) } label: { Label("Stack on \(earlier?.displayNumber ?? "the other")", systemImage: "square.3.layers.3d.down.left") }
                    Button { askAgent(o) } label: { Label("Ask agent to resolve", systemImage: "sparkles") }
                    Button { dropFromPreview(o) } label: { Label("Drop \(later?.displayNumber ?? "it")", systemImage: "minus.circle") }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    // MARK: Conflict choices

    private func dropFromPreview(_ o: HXPreviewOutcome) {
        if let id = o.conflictTicket { selected.remove(id) }
        outcome = nil
        if !selected.isEmpty { buildPreview() }
    }

    private func stackConflict(_ o: HXPreviewOutcome) {
        guard let later = o.conflictTicket, let earlier = o.conflictAgainst else { return }
        state.perform("Stack") { try state.store.stack(ticketId: later, onto: earlier) }
        selected.remove(later)
        outcome = nil
    }

    private func askAgent(_ o: HXPreviewOutcome) {
        guard let later = o.conflictTicket, let earlier = o.conflictAgainst else { return }
        let other = ticket(earlier)?.displayNumber ?? "#\(earlier)"
        let files = o.conflictFiles.joined(separator: ", ")
        let body = "This ticket conflicts with \(other) when both go into one Preview. Files: \(files). Please resolve the conflict on your branch."
        state.perform("Ask agent") {
            try state.store.addNote(later, kind: .instruction, author: "owner", body: body)
            try state.store.move(later, to: .fixing, actor: .owner, reason: "conflict with \(other)")
        }
        selected.remove(later)
        outcome = nil
    }

    // MARK: Build

    private func buildPreview() {
        guard let repo = appRepo else { return }
        let store = state.store
        let ids = selected.sorted()
        building = true
        outcome = nil
        Task {
            let result = await Task.detached { HXPreviewAdapter.build(store: store, repo: repo, ticketIds: ids) }.value
            outcome = result
            building = false
            state.refresh()
        }
    }

    // MARK: Verify per ticket (J3)

    @ViewBuilder private var verificationSection: some View {
        let list = previewTickets
        if !list.isEmpty, let preview = latestPreview, preview.state == "merged" {
            VStack(alignment: .leading, spacing: 8) {
                Text("Verify in \(preview.name)").font(.headline)
                ForEach(list, id: \.ticketId) { pt in
                    if let t = ticket(pt.ticketId) { verifyCard(t, pt, preview) }
                }
            }
        }
    }

    private func lookAt(_ t: Ticket) -> [String] {
        let picks = (try? state.store.picks(ticketId: t.id)) ?? []
        var items: [String] = picks.map { "\($0.topic): \($0.choice)" }
        if items.isEmpty {
            let firstLine = t.body.split(separator: "\n").first.map(String.init) ?? t.title
            items.append(String(firstLine.prefix(140)))
        }
        return items
    }

    private func verifyCard(_ t: Ticket, _ pt: PreviewTicket, _ preview: HatchCore.Preview) -> some View {
        HXCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(t.displayNumber).font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                    Text(t.title).font(.headline).lineLimit(1)
                    HXStatusChip(status: t.status)
                    Spacer()
                    verdictChip(pt.verdict)
                }
                Text("Look at").font(.caption).foregroundStyle(.secondary)
                ForEach(lookAt(t), id: \.self) { item in checklistRow(t, item) }
                if t.status == .toVerify {
                    verdictButtons(t, preview)
                }
                if needsWorkFor == t.id { needsWorkForm(t, preview) }
                if let note = pt.note, pt.verdict == "needs-work" {
                    Text("Your note: \(note)").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder private func verdictChip(_ verdict: String?) -> some View {
        if verdict == "looks-right" {
            HXChip(text: "Looks right", turn: .finished)
        } else if verdict == "needs-work" {
            HXProblemChip(text: "Needs work")
        }
    }

    private func checklistRow(_ t: Ticket, _ item: String) -> some View {
        let key = "\(t.id)|\(item)"
        return Toggle(isOn: Binding(
            get: { checked.contains(key) },
            set: { on in
                if on { checked.insert(key) } else { checked.remove(key) }
            }
        )) {
            Text(item).font(.callout)
        }
        .toggleStyle(.checkbox)
    }

    private func verdictButtons(_ t: Ticket, _ preview: HatchCore.Preview) -> some View {
        HStack {
            Button { markRight(t, preview) } label: { Label("Looks right", systemImage: "checkmark") }
            Button {
                needsWorkFor = t.id
                needsNote = ""
                screenshot = nil
            } label: { Label("Needs work...", systemImage: "xmark") }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func needsWorkForm(_ t: Ticket, _ preview: HatchCore.Preview) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("What is wrong?", text: $needsNote, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...5)
            HStack {
                Button { pickScreenshot() } label: { Label("Add screenshot", systemImage: "photo") }
                    .buttonStyle(.bordered)
                if let url = screenshot { Text(url.lastPathComponent).font(.caption).foregroundStyle(.secondary) }
                Spacer()
                Button("Cancel") { needsWorkFor = nil }
                    .buttonStyle(.bordered)
                Button { markNeedsWork(t, preview) } label: { Label("Send back to agent", systemImage: "arrow.uturn.backward") }
                    .buttonStyle(.borderedProminent)
                    .disabled(needsNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func pickScreenshot() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK { screenshot = panel.url }
    }

    private func markRight(_ t: Ticket, _ preview: HatchCore.Preview) {
        state.perform("Record verdict") {
            try state.store.setVerdict(previewId: preview.id, ticketId: t.id, verdict: "looks-right", note: nil)
            try state.store.record(t.id, actor: "owner", kind: "verified", payload: ["preview": .string(preview.name), "verdict": "looks-right"])
        }
    }

    private func markNeedsWork(_ t: Ticket, _ preview: HatchCore.Preview) {
        let note = needsNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let shot = screenshot
        state.perform("Send back") {
            try state.store.setVerdict(previewId: preview.id, ticketId: t.id, verdict: "needs-work", note: note)
            if let shot {
                try state.store.addAttachment(t.id, path: shot.path, kind: "screenshot", caption: note)
            }
            try state.store.addNote(t.id, kind: .instruction, author: "owner", body: "Needs work in \(preview.name): \(note)")
            try state.store.move(t.id, to: .fixing, actor: .owner, reason: note)
        }
        needsWorkFor = nil
    }

    // MARK: Merge plan (J5, J6, I6)

    private var planSteps: [String] {
        var steps: [String] = []
        if let project = state.hxProject {
            steps = HXMergeAdapter.planLines(store: state.store, project: project, tickets: approved)
        }
        let base = appRepo?.defaultBranch ?? "dev"
        steps.append("CI on \(integrationBranch): \(ciText.isEmpty ? "not checked yet" : ciText).")
        steps.append("When CI is green, promote \(integrationBranch) to \(base).")
        return steps
    }

    @ViewBuilder private var mergeSection: some View {
        if latestPreview != nil, !previewTickets.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Merge plan").font(.headline)
                HXCard {
                    VStack(alignment: .leading, spacing: 8) {
                        if approved.isEmpty {
                            Text("Mark tickets as Looks right to build a plan. A ticket that needs work does not block the others.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(Array(planSteps.enumerated()), id: \.offset) { index, text in
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text("\(index + 1)").font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                                    Text(text).font(.callout)
                                }
                            }
                        }
                        mergeButtons
                        ForEach(Array(mergeSteps.enumerated()), id: \.offset) { _, step in
                            mergeStepRow(step)
                        }
                    }
                }
            }
        }
    }

    private var mergeButtons: some View {
        HStack {
            Button { mergeApproved() } label: {
                Label(merging ? "Merging..." : "Merge approved (\(approved.count))", systemImage: "arrow.triangle.merge")
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(approved.isEmpty || merging)
            Button { refreshCI() } label: { Label("Check CI", systemImage: "arrow.clockwise") }
                .buttonStyle(.glass)
            Button { promote() } label: { Label("Promote", systemImage: "arrow.up.right") }
                .buttonStyle(.glass)
                .disabled(ciText != "passing")
                .help("Moves the integration branch into the base branch when CI is green.")
            if latestPreview != nil {
                HXMenuButton(title: "More", symbol: "ellipsis") {
                    Button("Discard this Preview...", role: .destructive) { confirmDiscard = true }
                }
            }
        }
        .confirmationDialog("Discard \(latestPreview?.name ?? "this Preview")?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard", role: .destructive) {
                if let p = latestPreview { discardPreview(p) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The Preview build is removed. The tickets stay To verify.")
        }
    }

    private func mergeStepRow(_ step: HXMergeAdapter.Step) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: step.ok ? "checkmark.circle" : "exclamationmark.triangle")
                .foregroundStyle(step.ok ? Theme.finished : Theme.critical)
            VStack(alignment: .leading, spacing: 1) {
                Text(step.title).font(.callout)
                if !step.detail.isEmpty { Text(step.detail).font(.caption).foregroundStyle(.secondary) }
            }
        }
    }

    private func mergeApproved() {
        guard let project = state.hxProject else { return }
        let list = approved
        let store = state.store
        let integration = integrationBranch
        let previewName = latestPreview?.name ?? "Preview"
        merging = true
        mergeSteps = []
        Task {
            let steps: [HXMergeAdapter.Step] = await Task.detached { HXMergeAdapter.run(store: store, project: project, tickets: list) }.value
            mergeSteps = steps
            merging = false
            if !steps.contains(where: { !$0.ok }) {
                for t in list {
                    state.perform("Mark merged") {
                        try state.store.move(t.id, to: .merged, actor: .hatch, reason: "merged from \(previewName) into \(integration)")
                    }
                }
            }
            refreshCI()
        }
    }

    private func promote() {
        guard let repo = appRepo else { return }
        let store = state.store
        let integration = integrationBranch
        let green = ciText == "passing"
        Task {
            let step = await Task.detached { HXMergeAdapter.promote(store: store, repo: repo, integration: integration, ciPassed: green) }.value
            mergeSteps.append(step)
        }
    }

    private func discardPreview(_ p: HatchCore.Preview) {
        guard let repo = appRepo else { return }
        let store = state.store
        Task {
            let failure = await Task.detached { HXPreviewAdapter.discard(store: store, preview: p, repo: repo) }.value
            if let failure { state.errorMessage = failure }
            outcome = nil
            state.refresh()
        }
    }

    private func refreshCI() {
        guard let repo = appRepo else { return }
        let branch = integrationBranch
        let remote = repo.remote
        Task {
            let text = await Task.detached { HXCIAdapter.status(remote: remote, ref: branch) }.value
            ciText = text
        }
    }
}
