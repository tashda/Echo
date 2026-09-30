import AppKit
import EchoDesignSystem
import ServerLabKit
import SwiftUI

/// What runs on the lab host now, the memory budget, and the build/start log.
struct RunningServersPanel: View {
    let model: LabServersModel
    @AppStorage("lab.servers.bottomPane") private var bottomPane = "log"

    var body: some View {
        VSplitView {
            Form {
                Section {
                    budget
                } header: {
                    Text("Running on \(model.hostName)")
                } footer: {
                    Text("Lab servers are removed with their volumes when a suite ends or their time runs out. Other agents' servers are shown but can only be stopped by them.")
                        .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                }
                Section {
                    if model.running.isEmpty {
                        Text("Nothing from the lab is running.").foregroundStyle(ColorTokens.Text.secondary)
                    }
                    ForEach(model.running, id: \.id) { server in
                        row(server)
                    }
                }
            }
            .formStyle(.grouped)
            .frame(minHeight: 260)

            VStack(spacing: 0) {
                Picker("Show", selection: $bottomPane) {
                    Text("Log").tag("log")
                    Text("Wire").tag("wire")
                    Text("Explained").tag("explained")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 300)
                .padding(.top, SpacingTokens.xs)
                switch bottomPane {
                case "wire": WireView(model: model)
                case "explained": ExplainedWireView(model: model)
                default: logView
                }
            }
            .frame(minHeight: 180)
        }
    }

    private var budget: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            ProgressView(value: Double(min(model.reservedMB, model.budgetMB)), total: Double(max(model.budgetMB, 1)))
                .tint(model.reservedMB > model.budgetMB * 9 / 10 ? ColorTokens.Status.warning : ColorTokens.accent)
            HStack {
                Text("\(model.reservedMB) of \(model.budgetMB) MB in use, including other containers on the host")
                Spacer()
                if let lastRefresh = model.lastRefresh {
                    Text(lastRefresh, style: .time).foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            .font(TypographyTokens.detail)
            .foregroundStyle(ColorTokens.Text.secondary)
        }
    }

    @ViewBuilder
    private func row(_ server: RunningServer) -> some View {
        // Parts of a server show once, under its main container.
        let mine = model.startedServer(named: server.server)
        let isMain = server.name == server.server
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            HStack {
                Text(server.recipe).font(TypographyTokens.standard)
                Text(server.part.isEmpty || server.part == "server" ? server.role : "\(server.role), \(server.part)")
                    .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                Spacer()
                if let mine, isMain {
                    StartedServerMenus(model: model, server: mine)
                    Button("Copy connection") { Self.copy(mine) }
                    Button("Remove") { Task { await model.stop(mine) } }
                }
            }
            HStack(spacing: SpacingTokens.sm) {
                if let mine, isMain {
                    Text("\(mine.host):\(mine.port)  user \(mine.username)").textSelection(.enabled)
                }
                Text("owner \(server.owner)")
                Text("removed \(server.expires, style: .relative)")
                Text(server.status)
            }
            .font(TypographyTokens.detail)
            .foregroundStyle(ColorTokens.Text.secondary)
            if let mine, isMain { StartedServerDetails(server: mine) }
        }
    }

    private var logView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Log").font(TypographyTokens.headline)
                Spacer()
                Button("Clear") { model.clearLog() }.disabled(model.log.isEmpty)
            }
            .padding(SpacingTokens.sm)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(model.log.enumerated()), id: \.offset) { _, line in
                        Text(line).font(TypographyTokens.monospaced).textSelection(.enabled)
                    }
                }
                .padding(.horizontal, SpacingTokens.sm)
            }
            .defaultScrollAnchor(.bottom)
        }
    }

    /// `SERVERLAB_*` and driver variables, ready to paste into a shell.
    private static func copy(_ server: LabDatabaseServer) {
        let text = server.environment.sorted { $0.key < $1.key }.map { "export \($0.key)='\($0.value)'" }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
