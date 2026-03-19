import SwiftUI
import SQLServerKit

/// Panel showing Change Data Capture status and Change Tracking configuration.
struct ChangeTrackingSheet: View {
    let databaseName: String
    let session: ConnectionSession
    let onDismiss: () -> Void

    @State var isLoading = true
    @State var errorMessage: String?
    @State var cdcTables: [SQLServerCDCTable] = []
    @State var ctStatus: [SQLServerChangeTrackingStatus] = []
    @State var confirmEnableCDC: CDCEnableTarget?
    @State var confirmDisableCDC: CDCDisableTarget?

    struct CDCEnableTarget: Identifiable {
        let id = UUID()
        let schema: String
        let table: String
    }

    struct CDCDisableTarget: Identifiable {
        let id = UUID()
        let schema: String
        let table: String
        let captureInstance: String?
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            if isLoading {
                VStack { Spacer(); ProgressView("Loading change tracking status\u{2026}"); Spacer() }
            } else if let error = errorMessage {
                VStack { Spacer(); Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(ColorTokens.Text.secondary); Spacer() }.padding()
            } else {
                contentView
            }

            Divider()
            footerBar
        }
        .frame(minWidth: 520, minHeight: 380)
        .frame(idealWidth: 560, idealHeight: 420)
        .task { await loadData() }
        .alert("Enable CDC?", isPresented: enableAlertBinding) {
            Button("Cancel", role: .cancel) { confirmEnableCDC = nil }
            Button("Enable") {
                guard let target = confirmEnableCDC else { return }
                confirmEnableCDC = nil
                Task { await toggleCDC(schema: target.schema, table: target.table, enable: true) }
            }
        } message: {
            if let target = confirmEnableCDC {
                Text("Enable Change Data Capture on [\(target.schema)].[\(target.table)]?")
            }
        }
        .alert("Disable CDC?", isPresented: disableAlertBinding) {
            Button("Cancel", role: .cancel) { confirmDisableCDC = nil }
            Button("Disable", role: .destructive) {
                guard let target = confirmDisableCDC else { return }
                confirmDisableCDC = nil
                Task { await toggleCDC(schema: target.schema, table: target.table, enable: false, captureInstance: target.captureInstance) }
            }
        } message: {
            if let target = confirmDisableCDC {
                Text("Disable CDC on [\(target.schema)].[\(target.table)]? This removes the change table.")
            }
        }
    }

    var enableAlertBinding: Binding<Bool> {
        Binding(get: { confirmEnableCDC != nil }, set: { if !$0 { confirmEnableCDC = nil } })
    }

    var disableAlertBinding: Binding<Bool> {
        Binding(get: { confirmDisableCDC != nil }, set: { if !$0 { confirmDisableCDC = nil } })
    }

    private var headerBar: some View {
        HStack {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(ColorTokens.accent)
            Text("Change Tracking / CDC")
                .font(TypographyTokens.prominent.weight(.semibold))
            Spacer()
            Text(databaseName)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        .padding(SpacingTokens.md)
    }

    private var footerBar: some View {
        HStack {
            Spacer()
            Button("Done") { onDismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(SpacingTokens.md)
    }

    func loadData() async {
        guard let mssql = session.session as? MSSQLSession else {
            errorMessage = "Not a SQL Server connection."
            isLoading = false
            return
        }
        do {
            cdcTables = try await mssql.changeTracking.listCDCTables()
            ctStatus = try await mssql.changeTracking.changeTrackingStatus()
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func toggleCDC(schema: String, table: String, enable: Bool, captureInstance: String? = nil) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        do {
            if enable {
                try await mssql.changeTracking.enableCDC(schema: schema, table: table)
            } else {
                try await mssql.changeTracking.disableCDC(schema: schema, table: table, captureInstance: captureInstance)
            }
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
