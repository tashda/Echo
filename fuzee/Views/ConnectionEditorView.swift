import SwiftUI

struct ConnectionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppModel

    @State private var model: SavedConnection
    @State private var password: String = ""
    @State private var isTestingConnection = false
    @State private var testResult: ConnectionTestResult?

    let onSave: (SavedConnection, String?) -> Void

    init(connection: SavedConnection?, onSave: @escaping (SavedConnection, String?) -> Void) {
        self.onSave = onSave
        _model = State(initialValue: connection ?? SavedConnection(
            connectionName: "",
            host: "",
            port: 5432,
            database: "",
            username: "",
            keychainIdentifier: nil,
            useTLS: true,
            databaseType: .postgresql
        ))
    }

    private var isFormValid: Bool {
        !model.connectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !model.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !model.database.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !model.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && model.port > 0 && model.port <= 65535
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        // Connection Details Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Connection Details").font(.headline).fontWeight(.semibold).foregroundStyle(.primary)

                            VStack(spacing: 16) {
                                LabeledTextField("Connection Name", text: $model.connectionName)

                                // Database Type Selection
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Database Type").font(.subheadline).fontWeight(.medium).foregroundStyle(.secondary)

                                    Picker("Database Type", selection: $model.databaseType) {
                                        ForEach(DatabaseType.allCases, id: \.self) {
                                            type in
                                            HStack(spacing: 8) {
                                                Image(systemName: type.iconName)
                                                Text(type.displayName)
                                            }.tag(type)
                                        }
                                    }.pickerStyle(.menu).onChange(of: model.databaseType) {
                                        _, newType in
                                        // Update port to default for selected database type
                                        model.port = newType.defaultPort
                                    }
                                }

                                HStack(spacing: 16) {
                                    LabeledTextField("Host", text: $model.host)

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Port").font(.subheadline).fontWeight(.medium).foregroundStyle(.secondary)

                                        TextField("Port", value: $model.port, format: .number).textFieldStyle(.roundedBorder).frame(width: 100)
                                    }
                                }

                                LabeledTextField("Database", text: $model.database)
                                LabeledTextField("Username", text: $model.username)
                                LabeledSecureField("Password", text: $password)

                                HStack {
                                    Toggle("Use TLS/SSL", isOn: $model.useTLS).toggleStyle(.switch)
                                    Spacer()
                                }
                            }
                        }.padding(20).background(Color.white, in: RoundedRectangle(cornerRadius: 12))

                        // Test Connection Section
                        if let result = testResult {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Connection Test").font(.headline).fontWeight(.semibold).foregroundStyle(.primary)

                                ConnectionTestResultView(result: result)
                            }.padding(20).background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }.padding(20)
                }

                Divider()

                // Bottom action bar
                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }.buttonStyle(.bordered).controlSize(.large)

                    Spacer()

                    Button(action: {
                        Task {
                            await testConnection()
                        }
                    }) {
                        HStack(spacing: 8) {
                            if isTestingConnection {
                                ProgressView().controlSize(.small)
                                Text("Testing...")
                            } else {
                                Text("Test Connection")
                            }
                        }
                    }.buttonStyle(.bordered).controlSize(.large).disabled(!isFormValid || isTestingConnection)

                    Button("Save Connection") {
                        onSave(model, password.isEmpty ? nil: password)
                        dismiss()
                    }.buttonStyle(.borderedProminent).controlSize(.large).keyboardShortcut(.return).disabled(!isFormValid)
                }.padding(20).background(Color.white)
            }.navigationTitle(model.connectionName.isEmpty ? "New Connection": "Edit Connection")
        }.frame(width: 520, height: 650)
    }

    private func testConnection() async {
        isTestingConnection = true
        testResult = nil

        defer {
            isTestingConnection = false
        }

        // Create a temporary connection for testing
        var testConnection = model
        if !password.isEmpty {
            testConnection.keychainIdentifier = "test-temp"
        }

        let result = await appModel.testConnection(testConnection)
        testResult = result
    }
}

struct ConnectionTestResultView: View {
    let result: ConnectionTestResult

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: result.success ? "checkmark.circle.fill": "xmark.circle.fill").font(.title2).foregroundStyle(result.success ? .green: .red)

            VStack(alignment: .leading, spacing: 4) {
                Text(result.message).font(.subheadline).fontWeight(.medium).foregroundStyle(.primary)

                Text(result.details).font(.caption).foregroundStyle(.secondary).textSelection(.enabled).lineLimit(3)
            }

            Spacer()
        }.padding(12).background(
            result.success ? .green.opacity(0.1): .red.opacity(0.1),
            in: RoundedRectangle(cornerRadius: 8)
        ).overlay(
            RoundedRectangle(cornerRadius: 8).stroke(result.success ? .green.opacity(0.3): .red.opacity(0.3), lineWidth: 1)
        )
    }
}

struct LabeledTextField: View {
    let label: String
    @Binding var text: String

    init(_ label: String, text: Binding<String>) {
        self.label = label
        self._text = text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.subheadline).fontWeight(.medium).foregroundStyle(.secondary)

            TextField(label, text: $text).textFieldStyle(.roundedBorder)
        }
    }
}

struct LabeledSecureField: View {
    let label: String
    @Binding var text: String

    init(_ label: String, text: Binding<String>) {
        self.label = label
        self._text = text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.subheadline).fontWeight(.medium).foregroundStyle(.secondary)

            SecureField(label, text: $text).textFieldStyle(.roundedBorder)
        }
    }
}