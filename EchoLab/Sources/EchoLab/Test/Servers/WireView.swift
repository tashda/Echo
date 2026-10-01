import EchoDesignSystem
import ServerLabKit
import SwiftUI

/// The decoded traffic of a server started (with recording on) from the Servers page.
struct WireView: View {
    let model: LabServersModel
    @AppStorage("lab.servers.wireServer") private var selected = ""

    private var recordable: [String] { model.started.map(\.containerName).filter { model.capturing.contains($0) } }

    /// Table rows need an identity; messages are numbered in capture order.
    private struct Row: Identifiable {
        let id: Int
        let message: WireMessage
    }

    private var rows: [Row] {
        guard model.wireServer == selected else { return [] }
        return model.wire.enumerated().map { Row(id: $0.offset, message: $0.element) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Picker("Server", selection: $selected) {
                    ForEach(recordable, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .frame(maxWidth: 320)
                Text("\(model.wire.requests.count) requests").foregroundStyle(ColorTokens.Text.secondary)
                Spacer()
                Button("Open in Wireshark") { Task { await model.openInWireshark(selected) } }
                    .disabled(selected.isEmpty)
                    .help(LabWireshark.isInstalled ? "Opens the capture file in Wireshark" : "Wireshark is not installed: shows the file in Finder")
            }
            .font(TypographyTokens.detail)
            .padding(SpacingTokens.sm)

            if recordable.isEmpty {
                ContentUnavailableView("Nothing recorded", systemImage: "waveform.path.ecg",
                                       description: Text("Turn on Record traffic, then start a server."))
            } else {
                Table(rows) {
                    TableColumn("Time") { Text(String(format: "%.3f", $0.message.time)).monospacedDigit() }.width(70)
                    TableColumn("") { Image(systemName: $0.message.toServer ? "arrow.right" : "arrow.left") }.width(20)
                    TableColumn("Message") { Text($0.message.kind) }.width(min: 120, ideal: 170)
                    TableColumn("SQL or procedure") { Text($0.message.text ?? "").lineLimit(1).help($0.message.text ?? "") }
                }
                .font(TypographyTokens.monospaced)
            }
        }
        .task(id: selected) {
            if selected.isEmpty || !recordable.contains(selected) { selected = recordable.first ?? "" }
            while !Task.isCancelled, !selected.isEmpty {
                await model.refreshWire(for: selected)
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }
}
