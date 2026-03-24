import SwiftUI
import SQLServerKit

struct MSSQLEffectivePermissionsView: View {
    let session: DatabaseSession
    let database: String?
    @Environment(EnvironmentState.self) private var environmentState

    @State private var permissions: [EffectivePermissionInfo] = []
    @State private var isLoading = false
    @State private var securableClass: String = "SERVER"
    @State private var securableName: String = ""

    private let securableClasses = ["SERVER", "DATABASE", "SCHEMA", "OBJECT"]

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            permissionsTable
        }
        .task {
            await loadPermissions()
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: SpacingTokens.sm) {
            Picker("Scope", selection: $securableClass) {
                ForEach(securableClasses, id: \.self) { cls in
                    Text(cls).tag(cls)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 140)

            if securableClass != "SERVER" {
                TextField("", text: $securableName, prompt: Text("e.g. dbo.MyTable"))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
            }

            Button {
                Task { await loadPermissions() }
            } label: {
                Label("Check", systemImage: "checkmark.shield")
            }

            Spacer()
        }
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.vertical, SpacingTokens.xs)
    }

    // MARK: - Table

    private var permissionsTable: some View {
        List(permissions, id: \.permissionName) { perm in
            HStack {
                Text(perm.permissionName)
                    .font(TypographyTokens.Table.name)
                    .frame(minWidth: 160, alignment: .leading)

                if let entity = perm.entityName, !entity.isEmpty {
                    Text(entity)
                        .font(TypographyTokens.Table.secondaryName)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .frame(minWidth: 100, alignment: .leading)
                }

                if let sub = perm.subentityName, !sub.isEmpty {
                    Text(sub)
                        .font(TypographyTokens.Table.secondaryName)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }

                Spacer()
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
    }

    // MARK: - Data Loading

    private func loadPermissions() async {
        guard let mssql = session as? MSSQLSession else { return }
        isLoading = true
        defer { isLoading = false }

        if let db = database {
            _ = try? await session.sessionForDatabase(db)
        }

        let secName: String? = securableClass == "SERVER" ? nil : (securableName.isEmpty ? nil : securableName)
        do {
            permissions = try await mssql.security.listEffectivePermissions(on: secName, class: securableClass)
        } catch {
            permissions = []
        }
    }
}
