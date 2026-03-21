import SwiftUI
import SQLServerKit

/// Read-only panel showing Database Mail profiles, accounts, and recent queue.
struct DatabaseMailSheet: View {
    let session: ConnectionSession
    let onDismiss: () -> Void

    @State var selectedPage: MailPage = .profiles
    @State var isLoading = true
    @State var errorMessage: String?
    @State var profiles: [SQLServerMailProfile] = []
    @State var accounts: [SQLServerMailAccount] = []
    @State var status: SQLServerMailStatus?
    @State var queueItems: [SQLServerMailQueueItem] = []

    enum MailPage: String, CaseIterable {
        case profiles = "Profiles"
        case accounts = "Accounts"
        case queue = "Mail Queue"

        var icon: String {
            switch self {
            case .profiles: "person.crop.rectangle.stack"
            case .accounts: "envelope"
            case .queue: "tray"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                sidebar
                    .frame(width: 160)
                Divider()
                detailPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()

            HStack {
                if let status {
                    Circle()
                        .fill(status.isStarted ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text("Database Mail: \(status.statusDescription)")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                Spacer()
                Button("Done") { onDismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.cancelAction)
            }
            .padding(SpacingTokens.md)
        }
        .frame(minWidth: 580, minHeight: 400)
        .frame(idealWidth: 620, idealHeight: 440)
        .task { await loadData() }
    }

    private var sidebar: some View {
        List(MailPage.allCases, id: \.self, selection: $selectedPage) { page in
            Label(page.rawValue, systemImage: page.icon)
                .tag(page)
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .contentMargins(SpacingTokens.xs)
    }

    @ViewBuilder
    private var detailPane: some View {
        if isLoading {
            VStack { Spacer(); ProgressView("Loading Database Mail\u{2026}"); Spacer() }
        } else if let error = errorMessage {
            VStack { Spacer(); Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(ColorTokens.Text.secondary); Spacer() }.padding()
        } else {
            pageContent
        }
    }

    @ViewBuilder
    var pageContent: some View {
        switch selectedPage {
        case .profiles: profilesPage
        case .accounts: accountsPage
        case .queue: queuePage
        }
    }

    private func loadData() async {
        guard let mssql = session.session as? MSSQLSession else {
            errorMessage = "Not a SQL Server connection."
            isLoading = false
            return
        }
        do {
            profiles = try await mssql.databaseMail.listProfiles()
            accounts = try await mssql.databaseMail.listAccounts()
            status = try await mssql.databaseMail.status()
            queueItems = try await mssql.databaseMail.mailQueue(limit: 50)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
