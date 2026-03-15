import SwiftUI
import SQLServerKit

/// Panel showing SQL Server replication status: distributor, publications,
/// subscriptions, and articles.
struct ReplicationSheet: View {
    let databaseName: String
    let session: ConnectionSession
    let onDismiss: () -> Void

    @State var isLoading = true
    @State var errorMessage: String?
    @State var distributorConfigured = false
    @State var publications: [SQLServerPublication] = []
    @State var subscriptions: [SQLServerSubscription] = []
    @State var expandedPublication: String?
    @State var articles: [SQLServerReplicationArticle] = []

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            if isLoading {
                VStack { Spacer(); ProgressView("Loading replication status\u{2026}"); Spacer() }
            } else if let error = errorMessage {
                VStack {
                    Spacer()
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(ColorTokens.Text.secondary)
                    Spacer()
                }
                .padding()
            } else {
                contentView
            }

            Divider()
            footerBar
        }
        .frame(minWidth: 520, minHeight: 380)
        .frame(idealWidth: 580, idealHeight: 460)
        .task { await loadData() }
    }

    private var headerBar: some View {
        HStack {
            Image(systemName: "arrow.triangle.swap")
                .foregroundStyle(ColorTokens.accent)
            Text("Replication")
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
            distributorConfigured = try await mssql.replication.isDistributorConfigured()
            publications = try await mssql.replication.listPublications()
            subscriptions = try await mssql.replication.listSubscriptions()
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func loadArticles(publicationName: String) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        do {
            articles = try await mssql.replication.listArticles(publicationName: publicationName)
        } catch {
            articles = []
        }
    }
}
