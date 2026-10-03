import SwiftUI
import AppKit
import CryptoKit
import UniformTypeIdentifiers
import HatchCore

/// A screenshot held in memory until the ticket exists (it is then saved under attachments/<ticket>/).
struct PendingShot: Identifiable {
    let id = UUID()
    let name: String
    let data: Data
}

struct PendingLink: Identifiable {
    let id = UUID()
    let ticket: Ticket
    var kind: LinkKind
}

struct SimilarHit: Identifiable {
    let ticket: Ticket
    let score: Double
    var id: Int { ticket.id }
}

/// New ticket: one form with a Hatch check panel on the right (decisions E1, E2, E3, E5, E7).
struct ComposerView: View {
    @EnvironmentObject var state: AppState

    @State private var type: TicketType = .proposal
    @State private var title = ""
    @State private var bodyText = ""
    @State private var projectId: Int?
    @State private var area = ""
    @State private var themeId: Int?
    @State private var shots: [PendingShot] = []
    @State private var links: [PendingLink] = []
    @State private var linkRef = ""
    @State private var linkKind: LinkKind = .related
    @State private var similar: [SimilarHit] = []
    @State private var specs: [SpecItem] = []
    @State private var themes: [Ticket] = []
    @State private var hintTask: Task<Void, Never>?
    @State private var dropTargeted = false
    @State private var submitted: Ticket?

    private var project: Project? {
        guard let projectId else { return nil }
        return state.project(id: projectId)
    }

    private var areaNames: [String] { project?.config?.areas.map { $0.name } ?? [] }

    private var canSubmit: Bool {
        projectId != nil && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            if let submitted {
                submittedView(submitted)
            } else {
                header
                Divider()
                HStack(spacing: 0) {
                    ScrollView {
                        form
                            .padding(20)
                            .frame(maxWidth: 720, alignment: .leading)
                            .frame(maxWidth: .infinity)
                    }
                    Divider()
                    HatchCheckPanel(similar: similar, specs: specs, hasInput: hasInput, onLink: addLink)
                        .frame(width: 300)
                }
            }
        }
        .navigationTitle("New ticket")
        .onAppear { setUp() }
        .onChange(of: title) { _, _ in scheduleHints() }
        .onChange(of: bodyText) { _, _ in scheduleHints() }
        .onChange(of: projectId) { _, _ in projectChanged() }
    }

    private var hasInput: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Text("New ticket")
                .font(.title3.weight(.semibold))
            Text("Draft")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Cancel") { state.route = .desk }
                .keyboardShortcut(.cancelAction)
            Button("Save as draft") { create(submit: false) }
                .disabled(!canSubmit)
            Button(type == .theme ? "Create Theme" : "Submit for check") { create(submit: true) }
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!canSubmit)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: Form

    private var form: some View {
        VStack(alignment: .leading, spacing: 16) {
            typePicker
            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
            pickers
            bodyEditor
            screenshotArea
            linkArea
            branchLine
        }
    }

    private var typePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            HXDock(items: TicketType.allCases.map { HXDock.Item(id: $0, title: $0.displayName) }, selection: $type)
            Text(Self.typeHelp(type))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    static func typeHelp(_ type: TicketType) -> String {
        switch type {
        case .question: return "An idea or UX issue that is still words. You get a reply that has read the Spec and related tickets."
        case .sketch: return "Exploring a layout or flow before any Swift. You get 2 to 4 variants as HTML."
        case .proposal: return "Several options to compare in Swift. Hatch will suggest another type if it fits better."
        case .tweak: return "A small change with one obvious fix. No judging step."
        case .bug: return "Something that behaves wrongly. Say the steps, what you expected and what happened."
        case .theme: return "A group of related tickets, like \"Connection management\". It shows progress."
        }
    }

    private var pickers: some View {
        HStack(spacing: 12) {
            Picker("Project", selection: $projectId) {
                ForEach(state.projects) { p in
                    Text(p.name).tag(Optional(p.id))
                }
            }
            .frame(maxWidth: 220)
            Picker("Area", selection: $area) {
                Text("No area").tag("")
                ForEach(areaNames, id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            .frame(maxWidth: 240)
            Picker("Theme", selection: $themeId) {
                Text("No theme").tag(Int?.none)
                ForEach(themes) { theme in
                    Text(theme.title).tag(Optional(theme.id))
                }
            }
            .frame(maxWidth: 260)
            .disabled(type == .theme)
        }
    }

    private var bodyEditor: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $bodyText)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                if bodyText.isEmpty {
                    Text("What should change, and why. Write what you like; Iris will help structure it.")
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: 180)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
            if type == .proposal {
                Text("Useful for a Proposal: what, why, scope, constraints.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if type == .bug {
                Text("Useful for a Bug: steps, expected, actual.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Screenshots

    private var screenshotArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle")
                    .foregroundStyle(.secondary)
                Text("Drop or paste screenshots")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Choose…") { chooseFiles() }
                    .controlSize(.small)
                Button("Paste") { pasteFromClipboard() }
                    .controlSize(.small)
            }
            if !shots.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(shots) { shot in
                            ShotThumb(shot: shot) { remove(shot) }
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(dropTargeted ? Theme.agentBackground : Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
        .onDrop(of: [UTType.fileURL], isTargeted: $dropTargeted) { providers in
            handleDrop(providers)
        }
    }

    private func remove(_ shot: PendingShot) {
        shots.removeAll { $0.id == shot.id }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            handled = true
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                var url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let direct = item as? URL {
                    url = direct
                }
                guard let url else { return }
                guard Self.isImage(url) else { return }
                guard let data = try? Data(contentsOf: url) else { return }
                let name = url.lastPathComponent
                DispatchQueue.main.async {
                    shots.append(PendingShot(name: name, data: data))
                }
            }
        }
        return handled
    }

    static func isImage(_ url: URL) -> Bool {
        ["png", "jpg", "jpeg", "gif", "heic", "tiff", "tif", "webp"].contains(url.pathExtension.lowercased())
    }

    private func chooseFiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let data = try? Data(contentsOf: url) {
                shots.append(PendingShot(name: url.lastPathComponent, data: data))
            }
        }
    }

    private func pasteFromClipboard() {
        let board = NSPasteboard.general
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        if let urls = board.readObjects(forClasses: [NSURL.self], options: options) as? [URL], !urls.isEmpty {
            var added = false
            for url in urls where Self.isImage(url) {
                if let data = try? Data(contentsOf: url) {
                    shots.append(PendingShot(name: url.lastPathComponent, data: data))
                    added = true
                }
            }
            if added { return }
        }
        if let image = NSImage(pasteboard: board), let png = Self.pngData(image) {
            shots.append(PendingShot(name: "pasted.png", data: png))
        } else {
            state.errorMessage = "The clipboard has no image."
        }
    }

    static func pngData(_ image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    // MARK: Links

    private var linkArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Links")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(links) { link in
                HStack(spacing: 8) {
                    Text(LinkText.name(link.kind))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)
                    Text(link.ticket.displayNumber).foregroundStyle(.secondary)
                    Text(link.ticket.title).lineLimit(1)
                    Spacer()
                    Button { links.removeAll { $0.id == link.id } } label: { Image(systemName: "xmark.circle") }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
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
                    .frame(width: 120)
                    .onSubmit { addLinkFromField() }
                Button("Add link") { addLinkFromField() }
                    .disabled(linkRef.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func addLinkFromField() {
        let ref = linkRef
        guard let found: Ticket = state.perform("Could not find that ticket", { try state.store.resolve(ref) }) else { return }
        addLink(found, kind: linkKind)
        linkRef = ""
    }

    private func addLink(_ ticket: Ticket, kind: LinkKind) {
        if links.contains(where: { $0.ticket.id == ticket.id && $0.kind == kind }) { return }
        links.append(PendingLink(ticket: ticket, kind: kind))
    }

    private var branchLine: some View {
        let text: String = branchText()
        return Group {
            if !text.isEmpty {
                Text("Branches: \(text) (from the project settings)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func branchText() -> String {
        guard let config = project?.config else { return "" }
        var parts: [String] = []
        for repo in config.repos {
            switch repo.role {
            case .app: parts.append("App \u{2192} \(repo.branch)")
            case .designSystem: parts.append("Design system \u{2192} \(repo.branch)")
            case .specimens: parts.append("Specimens \u{2192} \(repo.branch)")
            case .tickets: break
            }
        }
        return parts.joined(separator: " · ")
    }

    // MARK: Hints (free, local)

    private func setUp() {
        if projectId == nil {
            projectId = state.projectFilterId ?? state.projects.first?.id
        }
        loadThemes()
    }

    private func projectChanged() {
        area = ""
        themeId = nil
        loadThemes()
        scheduleHints()
    }

    private func loadThemes() {
        guard let projectId else { themes = []; return }
        let all: [Ticket] = (try? state.store.tickets(TicketFilter(projectId: projectId, types: [.theme]))) ?? []
        themes = all.filter { !$0.status.isTerminal }
    }

    private func scheduleHints() {
        hintTask?.cancel()
        hintTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
            runHints()
        }
    }

    private func runHints() {
        guard hasInput else {
            similar = []
            specs = []
            return
        }
        let hits = (try? state.store.similarTickets(projectId: projectId, title: title, body: bodyText, limit: 5)) ?? []
        similar = hits.map { SimilarHit(ticket: $0.ticket, score: $0.score) }
        if let projectId {
            specs = (try? state.store.searchSpec(projectId: projectId, query: title + " " + bodyText, limit: 5)) ?? []
        } else {
            specs = []
        }
    }

    // MARK: Create and submit

    private func create(submit: Bool) {
        guard let pid = projectId else { return }
        let ticketType = type
        let ticketTitle = title
        let ticketBody = bodyText
        let ticketArea: String? = area.isEmpty ? nil : area
        let parent: Int? = ticketType == .theme ? nil : themeId
        let runCheck = submit && ticketType != .theme
        let created: Ticket? = state.perform("Could not create the ticket") {
            let t = try state.store.createTicket(projectId: pid, type: ticketType, title: ticketTitle, body: ticketBody,
                                                 area: ticketArea, parentId: parent, status: .draft, actor: .owner)
            try saveShots(for: t)
            for link in links {
                try state.store.link(from: t.id, to: link.ticket.id, kind: link.kind)
            }
            if runCheck {
                return try state.store.move(t.id, to: .checking, actor: .owner, reason: "submitted for check")
            }
            return t
        }
        guard let created else { return }
        if runCheck {
            VettingBridge.start(ticketId: created.id, state: state)
            submitted = created
        } else {
            state.open(created)
        }
    }

    private func saveShots(for ticket: Ticket) throws {
        guard !shots.isEmpty else { return }
        let relative = "attachments/\(ticket.id)"
        let dir = state.paths.root.appendingPathComponent(relative, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for (index, shot) in shots.enumerated() {
            let ext = (shot.name as NSString).pathExtension.lowercased()
            let fileName = "shot-\(index + 1).\(ext.isEmpty ? "png" : ext)"
            try shot.data.write(to: dir.appendingPathComponent(fileName))
            let digest = SHA256.hash(data: shot.data)
            let sha = digest.map { String(format: "%02x", $0) }.joined()
            try state.store.addAttachment(ticket.id, path: "\(relative)/\(fileName)", sha: sha, kind: "screenshot", caption: shot.name)
        }
    }

    // MARK: After submit

    private func submittedView(_ ticket: Ticket) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: "paperplane")
                        .foregroundStyle(Theme.agent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(ticket.displayNumber) submitted")
                            .font(.title3.weight(.semibold))
                        Text(ticket.title)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("New ticket") { resetForm() }
                    Button("Open ticket") { state.open(ticket) }
                        .buttonStyle(.glassProminent)
                }
                if !VettingBridge.isAvailable {
                    Text("Iris is not connected in this build, so the check will not run on its own. The ticket waits in Checking.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                IrisReviewView(ticketId: ticket.id, showIdleMessage: true)
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private func resetForm() {
        submitted = nil
        title = ""
        bodyText = ""
        shots = []
        links = []
        similar = []
        specs = []
        area = ""
        themeId = nil
    }
}

struct ShotThumb: View {
    let shot: PendingShot
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let image = NSImage(data: shot.data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 84, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 84, height: 84)
            }
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white, .black.opacity(0.6))
            }
            .buttonStyle(.plain)
            .padding(3)
        }
    }
}

/// The right-hand panel: related tickets and Spec items found locally while typing, and what happens after Submit (decision E2).
struct HatchCheckPanel: View {
    let similar: [SimilarHit]
    let specs: [SpecItem]
    let hasInput: Bool
    let onLink: (Ticket, LinkKind) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Hatch check")
                    .font(.headline)
                Text("Found instantly. This is a local search: no network, no tokens.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !hasInput {
                    Text("Start typing a title and related tickets and Spec items appear here.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                if !similar.isEmpty { similarList }
                if !specs.isEmpty { specList }
                if hasInput && similar.isEmpty && specs.isEmpty {
                    Text("Nothing related found yet.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                afterSubmit
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.secondary.opacity(0.04))
    }

    private var similarList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Related tickets")
                .font(.subheadline.weight(.semibold))
            ForEach(similar) { hit in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(hit.ticket.displayNumber)
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text(hit.ticket.title)
                            .font(.callout)
                            .lineLimit(2)
                    }
                    HStack {
                        StatusChip(status: hit.ticket.status)
                        Spacer()
                        Button("Link") { onLink(hit.ticket, .related) }
                            .controlSize(.small)
                    }
                }
            }
        }
    }

    private var specList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Spec")
                .font(.subheadline.weight(.semibold))
            ForEach(specs) { item in
                HStack(alignment: .top, spacing: 6) {
                    Text(item.code)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    Text(item.text)
                        .font(.callout)
                        .lineLimit(2)
                }
            }
        }
    }

    private var afterSubmit: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("After you submit")
                .font(.subheadline.weight(.semibold))
            Text("Iris compares the ticket with every other ticket and the Spec, and asks her questions before any work starts. She may also suggest a clearer text and a better type; you decide on both.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.agentBackground.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
    }
}
