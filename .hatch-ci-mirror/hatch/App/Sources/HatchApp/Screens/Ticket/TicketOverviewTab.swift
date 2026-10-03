import SwiftUI
import AppKit
import CryptoKit
import UniformTypeIdentifiers
import HatchCore

/// A link with the ticket on the other end, for the Links list.
struct LinkEntry: Identifiable {
    let link: TicketLink
    let outgoing: Bool
    let other: Ticket
    var id: String { "\(link.fromId)-\(link.toId)-\(link.kind.rawValue)" }
}

/// Overview: description, screenshots, links, and the facts on the right (decision F1).
struct TicketOverviewTab: View {
    let ticket: Ticket
    @EnvironmentObject var state: AppState

    @State private var attachments: [Attachment] = []
    @State private var linkEntries: [LinkEntry] = []
    @State private var parentTheme: Ticket?
    @State private var parentProgress: (done: Int, total: Int) = (0, 0)
    @State private var children: [Ticket] = []
    @State private var childProgress: (done: Int, total: Int) = (0, 0)
    @State private var specLines: [SpecItem] = []
    @State private var specCodes: [String] = []
    @State private var tokens: (input: Int, output: Int) = (0, 0)
    @State private var pendingSync = 0

    @State private var editing = false
    @State private var editTitle = ""
    @State private var editBody = ""
    @State private var linkRef = ""
    @State private var linkKind: LinkKind = .related

    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 18) {
                    IrisReviewView(ticketId: ticket.id)
                    if ticket.type == .theme { themeSection }
                    descriptionSection
                    attachmentSection
                    linkSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                detailsCard
                    .frame(width: 270)
            }
            .padding(20)
        }
        .autoReload(every: 5) { load() }
    }

    // MARK: Theme

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ThemeHeader(theme: ticket, done: childProgress.done, total: childProgress.total)
            if children.isEmpty {
                Text("No tickets in this Theme yet. Pick this Theme when you create a ticket.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ForEach(Phase.allCases, id: \.self) { phase in
                let inPhase: [Ticket] = children.filter { $0.status.phase == phase }
                if !inPhase.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(phase.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(inPhase) { child in
                            TicketLine(ticket: child, projectName: "")
                                .contentShape(Rectangle())
                                .onTapGesture { state.open(child) }
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Description")
                    .font(.headline)
                Spacer()
                if !editing {
                    Button("Edit") {
                        editTitle = ticket.title
                        editBody = ticket.body
                        editing = true
                    }
                    .controlSize(.small)
                }
            }
            if editing {
                editor
            } else if ticket.body.isEmpty {
                Text("No description.")
                    .foregroundStyle(.secondary)
            } else {
                Text(ticket.body)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            originalDisclosure
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Title", text: $editTitle)
                .textFieldStyle(.roundedBorder)
            TextEditor(text: $editBody)
                .font(.body)
                .frame(minHeight: 160)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
            HStack {
                Button("Save") { saveEdit() }
                    .buttonStyle(.borderedProminent)
                    .disabled(editTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Cancel") { editing = false }
            }
            .controlSize(.small)
        }
    }

    @ViewBuilder private var originalDisclosure: some View {
        let changedTitle: Bool = (ticket.originalTitle ?? ticket.title) != ticket.title
        let changedBody: Bool = (ticket.originalBody ?? ticket.body) != ticket.body
        if changedTitle || changedBody {
            DisclosureGroup("Your original text") {
                VStack(alignment: .leading, spacing: 6) {
                    Text(ticket.originalTitle ?? ticket.title)
                        .font(.body.weight(.semibold))
                    Text(ticket.originalBody ?? ticket.body)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
            }
            .font(.callout)
        }
    }

    private func saveEdit() {
        let id = ticket.id
        let newTitle = editTitle
        let newBody = editBody
        let ok: Ticket? = state.perform("Could not save the text") { try state.store.update(id, title: newTitle, body: newBody, actor: .owner) }
        if ok != nil { editing = false }
    }

    // MARK: Screenshots

    private var attachmentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(attachments.isEmpty ? "Screenshots" : "Screenshots (\(attachments.count))")
                    .font(.headline)
                Spacer()
                Button("Add screenshot…") { addScreenshot() }
                    .controlSize(.small)
            }
            if attachments.isEmpty {
                Text("None yet.")
                    .foregroundStyle(.secondary)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(attachments) { attachment in
                        AttachmentThumb(attachment: attachment)
                    }
                }
            }
        }
    }

    private func addScreenshot() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        let id = ticket.id
        let relative = "attachments/\(id)"
        let dir = state.paths.root.appendingPathComponent(relative, isDirectory: true)
        let urls = panel.urls
        _ = state.perform("Could not add the screenshot") {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            var n = 0
            for url in urls {
                let data = try Data(contentsOf: url)
                n += 1
                let ext = url.pathExtension.isEmpty ? "png" : url.pathExtension.lowercased()
                let name = "shot-\(Int(Date().timeIntervalSince1970))-\(n).\(ext)"
                try data.write(to: dir.appendingPathComponent(name))
                let sha = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                try state.store.addAttachment(id, path: "\(relative)/\(name)", sha: sha, kind: "screenshot", caption: url.lastPathComponent)
            }
        }
    }

    // MARK: Links

    private var linkSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Links")
                .font(.headline)
            if linkEntries.isEmpty {
                Text("No links.")
                    .foregroundStyle(.secondary)
            }
            ForEach(linkEntries) { entry in
                HStack(spacing: 8) {
                    Text(LinkText.label(kind: entry.link.kind, outgoing: entry.outgoing))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 90, alignment: .leading)
                    Button {
                        state.open(entry.other)
                    } label: {
                        HStack(spacing: 6) {
                            Text(entry.other.displayNumber).foregroundStyle(.secondary)
                            Text(entry.other.title).lineLimit(1)
                        }
                    }
                    .buttonStyle(.link)
                    StatusChip(status: entry.other.status)
                    Spacer()
                    Button { remove(entry) } label: { Image(systemName: "xmark.circle") }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Remove this link")
                }
            }
            HStack(spacing: 8) {
                Picker("Kind", selection: $linkKind) {
                    ForEach(LinkKind.allCases.filter { $0 != .parent }, id: \.self) { kind in
                        Text(LinkText.name(kind)).tag(kind)
                    }
                }
                .labelsHidden()
                .frame(width: 130)
                TextField("#118", text: $linkRef)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 110)
                    .onSubmit { addLink() }
                Button("Add link") { addLink() }
                    .disabled(linkRef.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .controlSize(.small)
        }
    }

    private func addLink() {
        let ref = linkRef
        let id = ticket.id
        let kind = linkKind
        let ok: Bool? = state.perform("Could not add the link") { () -> Bool in
            let other = try state.store.resolve(ref)
            try state.store.link(from: id, to: other.id, kind: kind)
            return true
        }
        if ok != nil { linkRef = "" }
    }

    private func remove(_ entry: LinkEntry) {
        let from = entry.link.fromId
        let to = entry.link.toId
        let kind = entry.link.kind
        _ = state.perform("Could not remove the link") { try state.store.unlink(from: from, to: to, kind: kind) }
    }

    // MARK: Details card

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            MetaRow(label: "Type") { Text(ticket.type.displayName) }
            MetaRow(label: "Project") { Text(projectLine) }
            if let parentTheme {
                MetaRow(label: "Theme") {
                    Button {
                        state.open(parentTheme)
                    } label: {
                        Text("\(parentTheme.title) (\(parentProgress.done) of \(parentProgress.total))")
                            .multilineTextAlignment(.leading)
                    }
                    .buttonStyle(.link)
                }
            }
            if !specCodes.isEmpty {
                MetaRow(label: "Touches") {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(specCodes, id: \.self) { code in
                            Text(specLabel(code)).font(.callout)
                        }
                    }
                }
            }
            if ticket.type == .proposal {
                MetaRow(label: "Revision") { Text("\(ticket.revision)") }
            }
            if let who = ticket.takenBy {
                MetaRow(label: "Agent") { Text(who) }
            }
            MetaRow(label: "GitHub") { Text(githubLine) }
            MetaRow(label: "Cost so far") { Text(costLine) }
            MetaRow(label: "Created") { Text(Format.clock(ticket.createdAt)) }
            MetaRow(label: "Changed") { Text(Format.ago(ticket.updatedAt)) }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }

    private var projectLine: String {
        let name: String = state.project(id: ticket.projectId)?.name ?? "?"
        if let area = ticket.area, !area.isEmpty { return "\(name) · \(area)" }
        return name
    }

    private var githubLine: String {
        guard let n = ticket.ghNumber else { return "Not on GitHub yet" }
        if pendingSync > 0 { return "Issue #\(n) · \(Format.count(pendingSync, "change")) waiting" }
        return "Issue #\(n) · synced"
    }

    private var costLine: String {
        let total = tokens.input + tokens.output
        if total == 0 { return "No tokens used" }
        return "\(Format.tokens(total)) tokens (\(Format.tokens(tokens.input)) in, \(Format.tokens(tokens.output)) out)"
    }

    private func specLabel(_ code: String) -> String {
        if let item = specLines.first(where: { $0.code == code }) { return "\(code) \(item.text)" }
        return code
    }

    // MARK: Data

    private func load() {
        let store = state.store
        let id = ticket.id
        attachments = (try? store.attachments(ticketId: id)) ?? []
        var entries: [LinkEntry] = []
        for item in (try? store.links(ticketId: id)) ?? [] {
            let otherId: Int = item.outgoing ? item.link.toId : item.link.fromId
            if item.link.kind == .parent && item.outgoing { continue }
            if let other = try? store.ticket(id: otherId) {
                entries.append(LinkEntry(link: item.link, outgoing: item.outgoing, other: other))
            }
        }
        linkEntries = entries
        if let parentId = ticket.parentId, let theme = try? store.ticket(id: parentId) {
            parentTheme = theme
            parentProgress = (try? store.themeProgress(parentId)) ?? (done: 0, total: 0)
        } else {
            parentTheme = nil
        }
        if ticket.type == .theme {
            children = (try? store.tickets(TicketFilter(parentId: id))) ?? []
            childProgress = (try? store.themeProgress(id)) ?? (done: 0, total: 0)
        }
        let info = ProposalInfo.load(store: store, ticket: ticket)
        var codes: [String] = info.specs
        if let pending = (try? store.pendingSuggestion(ticketId: id)) ?? nil {
            for code in pending.specTouches where !codes.contains(code) { codes.append(code) }
        }
        specCodes = codes
        specLines = (try? store.specItems(projectId: ticket.projectId)) ?? []
        tokens = (try? store.tokenTotals(ticketId: id)) ?? (input: 0, output: 0)
        pendingSync = ((try? store.pendingOps(ticketId: id)) ?? []).count
    }
}

/// One labelled fact in the details card.
struct MetaRow<Content: View>: View {
    let label: String
    let content: Content

    init(label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            content
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
