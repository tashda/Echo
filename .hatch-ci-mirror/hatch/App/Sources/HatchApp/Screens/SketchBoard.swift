import SwiftUI
import WebKit
import HatchCore

// Sketch variants (decisions G1 to G4): HTML concepts side by side, pinned comments, and a way to choose a direction.

struct HXSketchVariant: Identifiable, Equatable {
    let id: String
    let title: String
    let summary: String
    let htmlPath: String          // relative path, or inline HTML when it contains a tag
}

enum HXSketchLoader {
    static func variants(from manifestJSON: String) -> [HXSketchVariant] {
        let root = JSONValue.parse(manifestJSON)
        let list: [JSONValue] = root["variants"]?.arrayValue ?? []
        var out: [HXSketchVariant] = []
        for v in list {
            let id = v["id"]?.stringValue ?? "v\(out.count + 1)"
            let title = v["title"]?.stringValue ?? id
            let path = v["htmlPath"]?.stringValue ?? v["html"]?.stringValue ?? ""
            let summary = v["summary"]?.stringValue ?? ""
            out.append(HXSketchVariant(id: id, title: title, summary: summary, htmlPath: path))
        }
        return out
    }

    static func directoryHint(from manifestJSON: String) -> String? {
        let root = JSONValue.parse(manifestJSON)
        return root["dir"]?.stringValue ?? root["directory"]?.stringValue ?? root["baseDirectory"]?.stringValue
    }

    static func isInline(_ s: String) -> Bool { s.contains("<") }

    /// Looks for the variant's file in the manifest's folder, then in Hatch's own sketches folder.
    static func resolve(_ variant: HXSketchVariant, ticket: Ticket?, hint: String?, home: URL) -> (file: URL, base: URL)? {
        if variant.htmlPath.isEmpty || isInline(variant.htmlPath) { return nil }
        var bases: [URL] = []
        if let hint { bases.append(URL(fileURLWithPath: hint, isDirectory: true)) }
        if let n = ticket?.ghNumber { bases.append(home.appendingPathComponent("sketches/\(n)", isDirectory: true)) }
        if let id = ticket?.id { bases.append(home.appendingPathComponent("sketches/\(id)", isDirectory: true)) }
        for base in bases {
            let file = base.appendingPathComponent(variant.htmlPath)
            if FileManager.default.fileExists(atPath: file.path) { return (file, base) }
        }
        return nil
    }
}

// MARK: The web view

struct HXPinMark: Equatable {
    let number: Int
    let x: Double
    let y: Double
}

struct HXSketchWeb: NSViewRepresentable {
    let loadKey: String
    let fileURL: URL?
    let baseURL: URL?
    let inlineHTML: String?
    let pins: [HXPinMark]
    let onPin: (Double, Double) -> Void

    static let script: String = """
    (function () {
      function post(x, y) {
        try { window.webkit.messageHandlers.hatchPin.postMessage({ x: x, y: y }); } catch (e) {}
      }
      document.addEventListener('click', function (e) {
        var w = Math.max(document.documentElement.scrollWidth, 1);
        var h = Math.max(document.documentElement.scrollHeight, 1);
        e.preventDefault();
        e.stopPropagation();
        post(e.pageX / w, e.pageY / h);
      }, true);
      window.__hatchSetPins = function (list) {
        var old = document.querySelectorAll('.hatch-pin');
        for (var i = 0; i < old.length; i++) { old[i].remove(); }
        var w = Math.max(document.documentElement.scrollWidth, 1);
        var h = Math.max(document.documentElement.scrollHeight, 1);
        list.forEach(function (p) {
          var d = document.createElement('div');
          d.className = 'hatch-pin';
          d.textContent = String(p.n);
          d.style.cssText = 'position:absolute;z-index:99999;width:20px;height:20px;border-radius:10px;background:#B4540A;color:#fff;font:600 12px -apple-system,sans-serif;display:flex;align-items:center;justify-content:center;transform:translate(-10px,-10px);pointer-events:none;left:' + (p.x * w) + 'px;top:' + (p.y * h) + 'px;';
          document.body.appendChild(d);
        });
      };
    })();
    """

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "hatchPin")
        controller.addUserScript(WKUserScript(source: HXSketchWeb.script, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        let config = WKWebViewConfiguration()
        config.userContentController = controller
        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        context.coordinator.onPin = onPin
        context.coordinator.web = web
        load(into: web, coordinator: context.coordinator)
        return web
    }

    func updateNSView(_ web: WKWebView, context: Context) {
        context.coordinator.onPin = onPin
        if context.coordinator.loadedKey != loadKey {
            load(into: web, coordinator: context.coordinator)
        }
        context.coordinator.apply(pins: pins)
    }

    private func load(into web: WKWebView, coordinator: Coordinator) {
        coordinator.loadedKey = loadKey
        coordinator.pins = pins
        if let fileURL {
            web.loadFileURL(fileURL, allowingReadAccessTo: baseURL ?? fileURL.deletingLastPathComponent())
        } else if let inlineHTML {
            web.loadHTMLString(inlineHTML, baseURL: nil)
        } else {
            web.loadHTMLString("<html><body style='font:14px -apple-system;color:#888;padding:24px'>This variant has no HTML file yet.</body></html>", baseURL: nil)
        }
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var onPin: (Double, Double) -> Void = { _, _ in }
        var loadedKey = ""
        var pins: [HXPinMark] = []
        var applied: [HXPinMark] = []
        weak var web: WKWebView?
        var pageReady = false

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any] else { return }
            guard let x = body["x"] as? Double, let y = body["y"] as? Double else { return }
            onPin(x, y)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            pageReady = true
            applied = []
            apply(pins: pins)
        }

        func apply(pins newPins: [HXPinMark]) {
            pins = newPins
            guard pageReady, let web, newPins != applied else { return }
            applied = newPins
            let items = newPins.map { "{n:\($0.number),x:\($0.x),y:\($0.y)}" }.joined(separator: ",")
            web.evaluateJavaScript("if (window.__hatchSetPins) { window.__hatchSetPins([\(items)]); }", completionHandler: nil)
        }
    }
}

// MARK: The board

struct SketchBoard: View {
    @EnvironmentObject var state: AppState
    let ticketId: Int

    @State private var carousel = false
    @State private var pending: PendingPin?
    @State private var pendingText = ""
    @State private var variantNotes: [String: String] = [:]
    @State private var showChoose = false

    struct PendingPin: Equatable {
        let variantId: String
        let x: Double
        let y: Double
    }

    // MARK: Data

    private var ticket: Ticket? {
        let t: Ticket? = try? state.store.ticket(id: ticketId)
        return t
    }

    private var manifestJSON: String {
        let m: String? = try? state.store.proposalManifest(ticketId: ticketId)
        return m ?? ""
    }

    private var variants: [HXSketchVariant] { HXSketchLoader.variants(from: manifestJSON) }

    private var allPins: [PinnedNote] { (try? state.store.pins(ticketId: ticketId)) ?? [] }

    private func number(of pin: PinnedNote) -> Int {
        (allPins.firstIndex { $0.id == pin.id } ?? 0) + 1
    }

    private func marks(for variant: HXSketchVariant) -> [HXPinMark] {
        var out: [HXPinMark] = []
        for p in allPins where p.option == variant.id {
            if let x = p.x, let y = p.y { out.append(HXPinMark(number: number(of: p), x: x, y: y)) }
        }
        return out
    }

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            topRow
            if variants.isEmpty {
                HXEmpty(symbol: "pencil.and.outline", title: "No variants yet", detail: "The agent hands in 2 to 4 HTML variants when it has drawn them.")
            } else {
                variantArea
                if let p = pending { pendingForm(p) }
                actionRow
            }
        }
        .padding(16)
        .sheet(isPresented: $showChoose) {
            ChooseDirectionSheet(ticketId: ticketId, variants: variants)
        }
    }

    private var topRow: some View {
        HStack(spacing: 10) {
            Text("Sketch variants").font(.headline)
            conceptLabel
            Spacer()
            if variants.count >= 2 {
                Picker("Layout", selection: $carousel) {
                    Text("Side by side").tag(false)
                    Text("One at a time").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
                .labelsHidden()
            }
        }
    }

    private var conceptLabel: some View {
        Text("Concept, not Swift")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 2)
            .foregroundStyle(Theme.hatch)
            .background(Theme.hatchBackground, in: Capsule())
    }

    @ViewBuilder private var variantArea: some View {
        if variants.count >= 4 || carousel {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(variants) { v in
                        variantCard(v).frame(width: 440)
                    }
                }
            }
        } else {
            HStack(alignment: .top, spacing: 12) {
                ForEach(variants) { v in
                    variantCard(v).frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: One variant

    private func variantCard(_ v: HXSketchVariant) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(v.title).font(.headline)
                Spacer()
                conceptLabel
            }
            if !v.summary.isEmpty { Text(v.summary).font(.caption).foregroundStyle(.secondary) }
            web(for: v)
                .frame(minHeight: 360)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
            Text("Click the concept to drop a numbered pin.").font(.caption).foregroundStyle(.secondary)
            pinList(v)
            noteField(v)
        }
    }

    private func web(for v: HXSketchVariant) -> some View {
        let resolved = HXSketchLoader.resolve(v, ticket: ticket, hint: HXSketchLoader.directoryHint(from: manifestJSON), home: state.paths.root)
        let inline: String? = HXSketchLoader.isInline(v.htmlPath) ? v.htmlPath : nil
        let key = v.id + "|" + (resolved?.file.path ?? inline ?? "none")
        return HXSketchWeb(loadKey: key, fileURL: resolved?.file, baseURL: resolved?.base, inlineHTML: inline, pins: marks(for: v),
                           onPin: { x, y in pending = PendingPin(variantId: v.id, x: x, y: y); pendingText = "" })
    }

    private func pinList(_ v: HXSketchVariant) -> some View {
        let mine = allPins.filter { $0.option == v.id }
        return VStack(alignment: .leading, spacing: 3) {
            ForEach(mine) { p in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(p.x == nil ? "Note" : "Pin \(number(of: p))").font(.caption.weight(.semibold)).foregroundStyle(Theme.you)
                    Text(p.text).font(.callout)
                }
            }
        }
    }

    private func noteField(_ v: HXSketchVariant) -> some View {
        HStack {
            TextField("Note on \(v.title)", text: Binding(
                get: { variantNotes[v.id] ?? "" },
                set: { variantNotes[v.id] = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .onSubmit { addNote(v) }
            Button("Add") { addNote(v) }
                .disabled((variantNotes[v.id] ?? "").trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func addNote(_ v: HXSketchVariant) {
        let text = (variantNotes[v.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return }
        state.perform("Add note") {
            try state.store.addPin(ticketId: ticketId, option: v.id, x: nil, y: nil, scenario: nil, appearance: nil, corners: nil, zoom: nil, text: text)
        }
        variantNotes[v.id] = ""
    }

    // MARK: New pin

    private func pendingForm(_ p: PendingPin) -> some View {
        let title = variants.first { $0.id == p.variantId }?.title ?? p.variantId
        return HXCard {
            HStack {
                Text("Pin \(allPins.count + 1) on \(title)").font(.callout.weight(.semibold))
                TextField("What do you want to say here?", text: $pendingText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { savePin(p) }
                Button("Add pin") { savePin(p) }
                    .buttonStyle(.glassProminent)
                    .disabled(pendingText.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Cancel") { pending = nil }
            }
        }
    }

    private func savePin(_ p: PendingPin) {
        let text = pendingText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return }
        state.perform("Add pin") {
            try state.store.addPin(ticketId: ticketId, option: p.variantId, x: p.x, y: p.y, scenario: nil, appearance: nil, corners: nil, zoom: nil, text: text)
        }
        pending = nil
        pendingText = ""
    }

    // MARK: Actions

    private var actionRow: some View {
        let canAct = ticket.map { Workflow.isAllowed(type: $0.type, from: $0.status, to: .revising, actor: .owner) } ?? false
        return HStack {
            Button("Ask") { state.showAskPanel = true }
            Spacer()
            Button("Needs more variants") { needsMore() }
                .disabled(!canAct)
                .help(canAct ? "Sends the sketch back to the agent with your pins and notes." : "Only available while it is your call.")
            Button("Choose direction...") { showChoose = true }
                .buttonStyle(.glassProminent)
        }
    }

    private func needsMore() {
        let lines = allPins.map { p in
            let where_ = variants.first { $0.id == p.option }?.title ?? "general"
            return "\(where_): \(p.text)"
        }
        let body = lines.isEmpty ? "Please offer more variants." : "Please offer more variants. My notes so far:\n" + lines.joined(separator: "\n")
        state.perform("Send back") {
            try state.store.addNote(ticketId, kind: .instruction, author: "owner", body: body)
            try state.store.move(ticketId, to: .revising, actor: .owner, reason: "needs more variants")
        }
    }
}

// MARK: Choose direction (G4)

struct ChooseDirectionSheet: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    let ticketId: Int
    let variants: [HXSketchVariant]

    enum Next: String, CaseIterable {
        case record = "Just record the direction"
        case proposal = "Make it real as a Proposal"
        case tweak = "Make it real as a Tweak"
    }

    struct Part: Identifiable {
        let id = UUID()
        var name: String
        var variantId: String
    }

    @State private var parts: [Part] = []
    @State private var note = ""
    @State private var next: Next = .proposal

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose direction").font(.title3.weight(.semibold))
            Text("Pick one variant, or mix parts: header from A, list from C.").font(.callout).foregroundStyle(.secondary)
            ForEach($parts) { $part in
                HStack {
                    TextField("Part (for example Header)", text: $part.name).textFieldStyle(.roundedBorder)
                    Picker("From", selection: $part.variantId) {
                        ForEach(variants) { v in Text(v.title).tag(v.id) }
                    }
                    .labelsHidden()
                    .frame(width: 160)
                    Button { parts.removeAll { $0.id == part.id } } label: { Image(systemName: "minus.circle") }
                        .buttonStyle(.borderless)
                }
            }
            Button { addPart() } label: { Label("Add a part", systemImage: "plus") }
            TextField("Anything else the agent should know", text: $note, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
            Picker("Next", selection: $next) {
                ForEach(Next.allCases, id: \.self) { n in Text(n.rawValue).tag(n) }
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Choose") { choose() }
                    .buttonStyle(.glassProminent)
                    .disabled(parts.isEmpty || parts.contains { $0.name.trimmingCharacters(in: .whitespaces).isEmpty })
            }
        }
        .padding(20)
        .frame(width: 520)
        .onAppear {
            if parts.isEmpty, let first = variants.first { parts = [Part(name: "Whole layout", variantId: first.id)] }
        }
    }

    private func addPart() {
        let id = variants.first?.id ?? ""
        parts.append(Part(name: "", variantId: id))
    }

    private func title(for id: String) -> String { variants.first { $0.id == id }?.title ?? id }

    private var directionText: String {
        var text = parts.map { "\($0.name) from \(title(for: $0.variantId))" }.joined(separator: ", ")
        let extra = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !extra.isEmpty { text += ". " + extra }
        return text
    }

    private func choose() {
        let direction = directionText
        let chosenNext = next
        let source: Ticket? = try? state.store.ticket(id: ticketId)
        guard let source else { return }
        let created: Ticket?? = state.perform("Choose direction") { () -> Ticket? in
            try state.store.setPick(ticketId: ticketId, topic: "direction", choice: direction)
            try state.store.addNote(ticketId, kind: .note, author: "owner", body: "Direction chosen: " + direction)
            if Workflow.isAllowed(type: source.type, from: source.status, to: .done, actor: .owner) {
                try state.store.move(ticketId, to: .done, actor: .owner, reason: "direction chosen")
            }
            if chosenNext == .record { return nil }
            let type: TicketType = chosenNext == .proposal ? .proposal : .tweak
            let body = "From Sketch \(source.displayNumber) \(source.title).\n\nChosen direction: \(direction)"
            let made = try state.store.createTicket(projectId: source.projectId, type: type, title: source.title, body: body, area: source.area)
            try state.store.link(from: made.id, to: ticketId, kind: .related)
            return made
        }
        if let outer = created, let made = outer { state.open(made) }
        dismiss()
    }
}
