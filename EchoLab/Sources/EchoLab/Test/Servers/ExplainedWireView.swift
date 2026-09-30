import EchoDesignSystem
import ServerLabKit
import SwiftUI
import TDSSpec

/// A recorded session explained by the lab's own decoders (TDS or PostgreSQL): every message, every
/// field, and what did not match the protocol. Sits next to Wire (Wireshark's decode).
struct ExplainedWireView: View {
    let model: LabServersModel
    @AppStorage("lab.servers.explainedServer") private var selected = ""
    @State private var selectedMessage: Int?
    @State private var sql = "SELECT name, database_id FROM sys.databases"

    private var recordable: [String] {
        model.started.filter { model.capturing.contains($0.containerName) }.map(\.containerName)
    }

    private var messages: [ExplainedMessage] { model.explainedServer == selected ? model.explained : [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolbar
            if recordable.isEmpty {
                ContentUnavailableView("Nothing recorded", systemImage: "list.bullet.indent",
                                       description: Text("Start a server with Record traffic on."))
            } else {
                HSplitView {
                    List(selection: $selectedMessage) {
                        ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
                            messageRow(message).tag(index)
                        }
                    }
                    .frame(minWidth: 220, idealWidth: 280)
                    detail.frame(minWidth: 320)
                }
            }
        }
        .task(id: selected) {
            if selected.isEmpty || !recordable.contains(selected) { selected = recordable.first ?? "" }
            while !Task.isCancelled, !selected.isEmpty {
                await model.refreshExplained(for: selected)
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    private var toolbar: some View {
        HStack {
            Picker("Server", selection: $selected) {
                ForEach(recordable, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()
            .frame(maxWidth: 280)
            let problems = messages.specProblems.count
            Label(problems == 0 ? "All \(messages.count) messages match the protocol" : "\(problems) not in the protocol",
                  systemImage: problems == 0 ? "checkmark.seal" : "exclamationmark.triangle")
                .foregroundStyle(problems == 0 ? ColorTokens.Status.success : ColorTokens.Status.warning)
            Spacer()
            if model.startedServer(named: selected)?.engine == .sqlServer {
                TextField("SQL", text: $sql, prompt: Text("SELECT 1"))
                    .frame(maxWidth: 320)
                    .onSubmit(send)
                Button("Send with sqlcmd", action: send)
                    .disabled(sql.isEmpty)
                    .help("Runs the SQL through Microsoft's sqlcmd with only the login encrypted, so the rest can be read here")
            }
        }
        .font(TypographyTokens.detail)
        .padding(SpacingTokens.sm)
    }

    private func send() {
        guard let server = model.startedServer(named: selected) else { return }
        let text = sql
        Task { await model.runMicrosoftClient(text, on: server) }
    }

    private func messageRow(_ message: ExplainedMessage) -> some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: message.toServer ? "arrow.right" : "arrow.left")
                .foregroundStyle(ColorTokens.Text.secondary)
            Text(message.kind)
            Spacer()
            if !message.explanation.problems.isEmpty {
                Image(systemName: "exclamationmark.triangle").foregroundStyle(ColorTokens.Status.warning)
            }
            Text(String(format: "%.3f", message.time)).monospacedDigit().foregroundStyle(ColorTokens.Text.tertiary)
        }
        .font(TypographyTokens.detail)
    }

    @ViewBuilder
    private var detail: some View {
        if let index = selectedMessage, messages.indices.contains(index) {
            let explanation = messages[index].explanation
            List {
                if !explanation.problems.isEmpty {
                    Section("Not in the protocol") {
                        ForEach(explanation.problems, id: \.self) { Text($0).foregroundStyle(ColorTokens.Status.warning) }
                    }
                }
                Section("\(explanation.structure), \(explanation.byteCount) bytes") {
                    TDSFieldOutline(fields: explanation.fields)
                }
            }
            .font(TypographyTokens.monospaced)
        } else {
            ContentUnavailableView("Choose a message", systemImage: "cursorarrow.click")
        }
    }
}
