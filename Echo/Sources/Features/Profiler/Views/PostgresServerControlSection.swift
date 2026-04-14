import SwiftUI

struct PostgresServerControlSection: View {
    @Bindable var viewModel: ServerPropertiesViewModel
    let customToolPath: String?

    @State private var dataDir: String = ""
    @State private var logFile: String = ""

    private var pgCtlAvailable: Bool {
        PostgresToolLocator.pgCtlURL(customPath: customToolPath) != nil
    }

    var body: some View {
        Form {
            Section("Server Status") {
                HStack {
                    statusIndicator
                    Text(statusLabel)
                        .font(TypographyTokens.standard)
                }
            }

            Section("Server Control") {
                if !viewModel.isLocalPostgresHost {
                    Text("Server control is only available for local PostgreSQL instances.")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                } else if !pgCtlAvailable {
                    Text("pg_ctl was not found. Install PostgreSQL or configure the tool path in Preferences.")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Status.warning)
                } else {
                    HStack(spacing: SpacingTokens.sm) {
                        Button("Start") {
                            Task { await viewModel.startLocalPostgresServer(customToolPath: customToolPath, dataDir: effectiveDataDir, logFile: effectiveLogFile) }
                        }
                        .disabled(viewModel.serverControlState == .running)

                        Button("Stop") {
                            Task { await viewModel.stopLocalPostgresServer(customToolPath: customToolPath, dataDir: effectiveDataDir) }
                        }
                        .disabled(viewModel.serverControlState == .stopped)

                        Button("Restart") {
                            Task { await viewModel.restartLocalPostgresServer(customToolPath: customToolPath, dataDir: effectiveDataDir, logFile: effectiveLogFile) }
                        }
                        .disabled(viewModel.serverControlState == .stopped)
                    }
                }
            }

            Section("Configuration") {
                TextField("Data Directory", text: $dataDir, prompt: Text("Auto-detect (PGDATA)"))
                    .textFieldStyle(.roundedBorder)
                TextField("Log File", text: $logFile, prompt: Text("Optional log file path"))
                    .textFieldStyle(.roundedBorder)
            }

            Section("Tools") {
                LabeledContent("pg_ctl") {
                    if let url = PostgresToolLocator.pgCtlURL(customPath: customToolPath) {
                        Text(url.path)
                            .font(TypographyTokens.code)
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .textSelection(.enabled)
                    } else {
                        Text("Not found")
                            .foregroundStyle(ColorTokens.Status.warning)
                    }
                }
            }

            if !viewModel.serverControlOutput.isEmpty {
                Section("Output") {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(viewModel.serverControlOutput.indices, id: \.self) { idx in
                                Text(viewModel.serverControlOutput[idx])
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(ColorTokens.Text.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(SpacingTokens.xs)
                    }
                    .frame(maxHeight: 150)
                    .background(ColorTokens.Background.secondary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .formStyle(.grouped)
    }

    private var effectiveDataDir: String? {
        dataDir.isEmpty ? nil : dataDir
    }

    private var effectiveLogFile: String? {
        logFile.isEmpty ? nil : logFile
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch viewModel.serverControlState {
        case .running:
            Circle().fill(ColorTokens.Status.success).frame(width: 10, height: 10)
        case .stopped:
            Circle().fill(ColorTokens.Status.warning).frame(width: 10, height: 10)
        case .unavailable:
            Circle().fill(ColorTokens.Status.error).frame(width: 10, height: 10)
        case .unknown:
            Circle().fill(ColorTokens.Text.quaternary).frame(width: 10, height: 10)
        }
    }

    private var statusLabel: String {
        switch viewModel.serverControlState {
        case .running: return "Running"
        case .stopped: return "Stopped"
        case .unavailable(let reason): return reason
        case .unknown: return "Checking..."
        }
    }
}
