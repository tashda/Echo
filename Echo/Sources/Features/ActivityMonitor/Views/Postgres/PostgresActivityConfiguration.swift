import SwiftUI
import PostgresKit

struct PostgresActivityConfiguration: View {
    let connectionID: UUID
    var activityEngine: ActivityEngine?
    @Environment(EnvironmentState.self) private var environmentState

    @State private var settings: [PostgresServerSetting] = []
    @State private var sortOrder = [KeyPathComparator(\PostgresServerSetting.name)]
    @State private var selection: Set<String> = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var categoryFilter: String?

    private var categories: [String] {
        Array(Set(settings.map(\.category))).sorted()
    }

    private var filteredSettings: [PostgresServerSetting] {
        var result = settings
        if let cat = categoryFilter {
            result = result.filter { $0.category == cat }
        }
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query)
                || $0.setting.lowercased().contains(query)
                || $0.shortDesc.lowercased().contains(query)
            }
        }
        return result.sorted(using: sortOrder)
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            table
        }
        .task { await loadSettings() }
    }

    private var filterBar: some View {
        HStack(spacing: SpacingTokens.sm) {
            TextField("", text: $searchText, prompt: Text("Search settings\u{2026}"))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 240)

            Picker("Category", selection: $categoryFilter) {
                Text("All Categories").tag(nil as String?)
                Divider()
                ForEach(categories, id: \.self) { cat in
                    Text(cat).tag(cat as String?)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 220)

            Spacer()

            if isLoading { ProgressView().controlSize(.small) }
            Button { Task { await loadSettings() } } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
    }

    private var table: some View {
        Table(filteredSettings, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name) { setting in
                Text(setting.name).font(TypographyTokens.Table.name)
            }
            .width(min: 120, ideal: 200)

            TableColumn("Value") { setting in
                Text(setting.setting).font(TypographyTokens.Table.numeric)
            }
            .width(min: 80, ideal: 120)

            TableColumn("Unit") { setting in
                if let unit = setting.unit {
                    Text(unit).font(TypographyTokens.Table.category)
                        .foregroundStyle(ColorTokens.Text.secondary)
                } else {
                    Text("\u{2014}").foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            .width(50)

            TableColumn("Category") { setting in
                Text(setting.category).font(TypographyTokens.Table.category)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(1)
            }
            .width(min: 100, ideal: 160)

            TableColumn("Context") { setting in
                Text(setting.context).font(TypographyTokens.Table.category)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(min: 60, ideal: 100)

            TableColumn("Source") { setting in
                Text(setting.source).font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(min: 60, ideal: 100)

            TableColumn("Restart") { setting in
                if setting.pendingRestart {
                    Text("Yes")
                        .font(TypographyTokens.Table.status)
                        .foregroundStyle(ColorTokens.Status.warning)
                } else {
                    Text("No")
                        .font(TypographyTokens.Table.status)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            .width(55)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
    }

    private func loadSettings() async {
        guard let session = environmentState.sessionGroup.sessionForConnection(connectionID),
              let pg = session.session as? PostgresSession else { return }
        isLoading = true
        let handle = activityEngine?.begin("Loading server settings", connectionSessionID: connectionID)
        defer { isLoading = false }
        do {
            settings = try await pg.client.metadata.listServerSettings()
            handle?.succeed()
        } catch {
            settings = []
            handle?.fail(error.localizedDescription)
        }
    }
}

extension PostgresServerSetting: @retroactive Identifiable {
    public var id: String { name }
}
