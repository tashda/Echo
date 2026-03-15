import SwiftUI
import SQLServerKit

struct NewLinkedServerSheet: View {
    let session: ConnectionSession
    let environmentState: EnvironmentState
    let onDismiss: () -> Void

    @State private var serverName = ""
    @State private var provider = "SQLNCLI"
    @State private var dataSource = ""
    @State private var product = ""
    @State private var catalog = ""
    @State private var providerString = ""

    @State private var usesSelfMapping = true
    @State private var remoteUser = ""
    @State private var remotePassword = ""

    @State private var isCreating = false
    @State private var errorMessage: String?

    private let knownProviders = [
        "SQLNCLI",
        "SQLOLEDB",
        "MSOLEDBSQL",
        "OraOLEDB.Oracle",
        "Microsoft.ACE.OLEDB.12.0",
        "SQLNCLI11"
    ]

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader
            Divider()
            sheetContent
            Divider()
            sheetFooter
        }
        .frame(width: 460)
    }

    private var sheetHeader: some View {
        HStack {
            Text("New Linked Server")
                .font(TypographyTokens.prominent.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.primary)
            Spacer()
        }
        .padding(.horizontal, SpacingTokens.lg)
        .padding(.vertical, SpacingTokens.md)
    }

    private var sheetContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.md) {
                serverDetailsSection
                loginMappingSection

                if let errorMessage {
                    Text(errorMessage)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Status.error)
                }
            }
            .padding(SpacingTokens.lg)
        }
        .frame(maxHeight: 400)
    }

    private var serverDetailsSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            Text("Server Details")
                .font(TypographyTokens.standard.weight(.medium))
                .foregroundStyle(ColorTokens.Text.primary)

            LabeledContent("Name") {
                TextField("Linked server name", text: $serverName)
                    .textFieldStyle(.roundedBorder)
            }

            LabeledContent("Provider") {
                Picker("", selection: $provider) {
                    ForEach(knownProviders, id: \.self) { p in
                        Text(p).tag(p)
                    }
                }
                .labelsHidden()
            }

            LabeledContent("Data Source") {
                TextField("Server address or DSN", text: $dataSource)
                    .textFieldStyle(.roundedBorder)
            }

            LabeledContent("Product") {
                TextField("Product name (optional)", text: $product)
                    .textFieldStyle(.roundedBorder)
            }

            LabeledContent("Catalog") {
                TextField("Default catalog (optional)", text: $catalog)
                    .textFieldStyle(.roundedBorder)
            }

            LabeledContent("Provider String") {
                TextField("Connection string (optional)", text: $providerString)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var loginMappingSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            Text("Login Mapping")
                .font(TypographyTokens.standard.weight(.medium))
                .foregroundStyle(ColorTokens.Text.primary)

            Toggle("Use current security context", isOn: $usesSelfMapping)

            if !usesSelfMapping {
                LabeledContent("Remote User") {
                    TextField("Remote login", text: $remoteUser)
                        .textFieldStyle(.roundedBorder)
                }

                LabeledContent("Remote Password") {
                    SecureField("Password", text: $remotePassword)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    private var sheetFooter: some View {
        HStack {
            Spacer()

            Button("Cancel") {
                onDismiss()
            }
            .keyboardShortcut(.cancelAction)

            Button("Create") {
                createLinkedServer()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!canCreate || isCreating)
        }
        .padding(.horizontal, SpacingTokens.lg)
        .padding(.vertical, SpacingTokens.md)
    }

    private var canCreate: Bool {
        !serverName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !dataSource.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func createLinkedServer() {
        guard let mssql = session.session as? MSSQLSession else { return }
        isCreating = true
        errorMessage = nil

        let name = serverName.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = dataSource.trimmingCharacters(in: .whitespacesAndNewlines)
        let prod = product.trimmingCharacters(in: .whitespacesAndNewlines)
        let cat: String? = catalog.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : catalog
        let pstr: String? = providerString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : providerString

        Task {
            do {
                try await mssql.linkedServers.add(
                    name: name,
                    provider: provider,
                    dataSource: source,
                    product: prod,
                    catalog: cat,
                    providerString: pstr
                )

                // Add login mapping
                try await mssql.linkedServers.addLoginMapping(
                    serverName: name,
                    usesSelf: usesSelfMapping,
                    remoteUser: usesSelfMapping ? nil : remoteUser,
                    remotePassword: usesSelfMapping ? nil : remotePassword
                )

                onDismiss()
            } catch {
                isCreating = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
