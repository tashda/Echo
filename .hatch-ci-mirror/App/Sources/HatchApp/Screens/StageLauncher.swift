import SwiftUI
import AppKit
import HatchCore

/// Starts or focuses the Hatch Stage app for a Proposal (decisions S1, S5). Hatch itself contains no round code.
@MainActor
final class StageLauncher {
    static let shared = StageLauncher()

    private var processes: [Int: Process] = [:]

    private init() {}

    func open(ticket: Ticket, state: AppState) {
        // Already running from this Hatch: bring it to the front.
        if let running = processes[ticket.id], running.isRunning {
            focus(pid: running.processIdentifier)
            return
        }
        // Started earlier (before Hatch was relaunched): focus it too.
        let sessions = (try? state.store.stageSessions(ticketId: ticket.id)) ?? []
        for s in sessions where s.state != "closed" {
            if let pid = s.pid, kill(pid_t(pid), 0) == 0 {
                focus(pid: pid_t(pid))
                return
            }
        }

        guard let executable = resolveExecutable(setting: state.hxSetting("stage_executable")) else {
            showNotBuilt(ticket: ticket)
            return
        }

        let ref = ticket.ghNumber.map { String($0) } ?? "new-\(ticket.id)"
        let home = state.paths.root.path
        let process = Process()
        process.executableURL = executable
        process.arguments = ["--ticket", ref, "--home", home]
        var env = ProcessInfo.processInfo.environment
        env["HATCH_HOME"] = home
        process.environment = env
        let ticketId = ticket.id
        let store = state.store
        process.terminationHandler = { _ in
            Task { @MainActor in
                StageLauncher.shared.processes[ticketId] = nil
                try? store.upsertStageSession(ticketId: ticketId, revision: 1, pid: nil, state: "closed")
            }
        }
        do {
            try process.run()
        } catch {
            state.errorMessage = "Could not start the Stage: \(error.localizedDescription)"
            return
        }
        processes[ticket.id] = process
        try? state.store.upsertStageSession(ticketId: ticket.id, revision: ticket.revision, pid: Int(process.processIdentifier), state: "building")
    }

    // MARK: Helpers

    private func resolveExecutable(setting: String?) -> URL? {
        guard let path = setting, !path.isEmpty else { return nil }
        let fm = FileManager.default
        if path.hasSuffix(".app") {
            guard let exec = Bundle(url: URL(fileURLWithPath: path))?.executableURL, fm.isExecutableFile(atPath: exec.path) else { return nil }
            return exec
        }
        return fm.isExecutableFile(atPath: path) ? URL(fileURLWithPath: path) : nil
    }

    private func focus(pid: pid_t) {
        NSRunningApplication(processIdentifier: pid)?.activate()
    }

    private func showNotBuilt(ticket: Ticket) {
        let alert = NSAlert()
        alert.messageText = "The Stage is not built yet"
        alert.informativeText = "Hatch Stage opens \(ticket.displayNumber) in its own window. Build the Stage app, then set its path under Settings, Apps Hatch opens."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: Build steps (decision I1)

/// The Work tab: Plan, Claim, Implement, Build, Tests, Match check, Ready, read from the ticket's events.
struct BuildStepsView: View {
    @EnvironmentObject var state: AppState
    let ticketId: Int

    enum StepState { case done, running, failed, pending }

    struct StepRow: Identifiable {
        let id: String
        let name: String
        let state: StepState
        let detail: String
        let seconds: Double?
    }

    private var ticket: Ticket? {
        let t: Ticket? = try? state.store.ticket(id: ticketId)
        return t
    }

    private var events: [Event] { (try? state.store.events(ticketId: ticketId)) ?? [] }

    // MARK: Deriving the steps

    private func latest(_ kinds: [String], in all: [Event]) -> Event? {
        all.last { kinds.contains($0.kind) }
    }

    private func detail(of event: Event?, fallback: String) -> String {
        guard let event else { return fallback }
        if let d = event.payload["detail"]?.stringValue, !d.isEmpty { return d }
        if let d = event.payload["summary"]?.stringValue, !d.isEmpty { return d }
        return fallback
    }

    private func outcome(of event: Event?) -> StepState {
        guard let event else { return .pending }
        if let ok = event.payload["ok"]?.boolValue, !ok { return .failed }
        return .done
    }

    private var rows: [StepRow] {
        let all = events
        let t = ticket
        let working = t.map { $0.status == .building || $0.status == .fixing } ?? false
        let finished = t.map { [.toVerify, .merged, .done].contains($0.status) } ?? false

        let defs: [(String, [String], String)] = [
            ("Plan", ["plan", "claim"], "Files and repositories chosen"),
            ("Claim", ["claim", "claim-granted"], "Files reserved"),
            ("Implement", ["commit", "workspace"], "Changes on the ticket branch"),
            ("Build", ["build"], "Compile the app"),
            ("Tests", ["tests"], "Tests for this area"),
            ("Match check", ["match-check", "conformance"], "Compare with the accepted option"),
        ]
        var out: [StepRow] = []
        var foundRunning = false
        for def in defs {
            let event = latest(def.1, in: all)
            var s = outcome(of: event)
            if finished && s == .pending { s = .done }
            if s == .pending && working && !foundRunning {
                s = .running
                foundRunning = true
            }
            var text = detail(of: event, fallback: s == .pending ? "" : def.2)
            if def.0 == "Claim", let e = event, e.kind == "claim", e.payload["state"]?.stringValue == "queued" {
                text = "Waiting for another ticket's files"
            }
            out.append(StepRow(id: def.0, name: def.0, state: s, detail: text, seconds: event?.payload["seconds"]?.doubleValue))
        }
        let readyState: StepState = finished ? .done : .pending
        out.append(StepRow(id: "Ready", name: "Ready for Preview", state: readyState, detail: finished ? "Ready to verify" : "", seconds: nil))
        return out
    }

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(rows) { row in stepRow(row) }
            DisclosureGroup("Log") { logView }
        }
    }

    private func stepRow(_ row: StepRow) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            icon(row.state).frame(width: 18)
            Text(row.name).font(.body.weight(row.state == .running ? .semibold : .regular))
            if !row.detail.isEmpty { Text(row.detail).font(.callout).foregroundStyle(.secondary).lineLimit(1) }
            Spacer()
            if let s = row.seconds { Text(hxClock(s)).font(.callout.monospacedDigit()).foregroundStyle(.secondary) }
        }
    }

    @ViewBuilder private func icon(_ s: StepState) -> some View {
        switch s {
        case .done: Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.finished)
        case .failed: Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.critical)
        case .running: ProgressView().controlSize(.small)
        case .pending: Image(systemName: "circle").foregroundStyle(.tertiary)
        }
    }

    private var logView: some View {
        let recent = Array(events.suffix(30))
        return VStack(alignment: .leading, spacing: 2) {
            if recent.isEmpty { Text("Nothing logged yet.").font(.caption).foregroundStyle(.secondary) }
            ForEach(recent) { e in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(e.at.formatted(date: .omitted, time: .standard)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    Text(e.actor).font(.caption).foregroundStyle(.secondary).frame(width: 60, alignment: .leading)
                    Text(e.kind).font(.caption.monospaced())
                }
            }
        }
        .padding(.top, 4)
    }
}
