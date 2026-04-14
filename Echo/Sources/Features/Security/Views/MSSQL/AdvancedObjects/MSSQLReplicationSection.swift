import SwiftUI
import SQLServerKit

struct MSSQLReplicationSection: View {
    @Bindable var viewModel: MSSQLAdvancedObjectsViewModel
    @Binding var showNewPublicationSheet: Bool
    @Binding var showNewSubscriptionSheet: Bool
    @Binding var showConfigureDistribution: Bool

    @State private var showRemoveDistributionAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.lg) {
                distributorSection
                if viewModel.distributorConfigured {
                    agentStatusSection
                    publicationsSection
                    subscriptionsSection
                }
            }
            .padding(SpacingTokens.md)
        }
        .alert("Remove Distribution?", isPresented: $showRemoveDistributionAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                Task { await viewModel.removeDistribution() }
            }
        } message: {
            Text("This will remove the distributor configuration, distribution database, and all associated publications. This action cannot be undone.")
        }
    }

    @ViewBuilder
    private var distributorSection: some View {
        GroupBox {
            HStack(spacing: SpacingTokens.sm) {
                Image(systemName: viewModel.distributorConfigured ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(viewModel.distributorConfigured ? ColorTokens.Status.success : ColorTokens.Text.tertiary)
                Text(viewModel.distributorConfigured ? "Distribution is configured" : "Distribution is not configured")
                    .font(TypographyTokens.standard)
                Spacer()
                if viewModel.distributorConfigured {
                    Button(role: .destructive) { showRemoveDistributionAlert = true } label: {
                        Label("Remove", systemImage: "trash")
                    }
                    .controlSize(.small)
                    .disabled(viewModel.isBusy)
                } else {
                    Button { showConfigureDistribution = true } label: {
                        Label("Configure Distribution", systemImage: "gearshape")
                    }
                    .controlSize(.small)
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isBusy)
                }
            }
        } label: {
            Text("Distributor")
                .font(TypographyTokens.standard.weight(.semibold))
        }
    }

    @ViewBuilder
    private var agentStatusSection: some View {
        GroupBox {
            if viewModel.agentStatuses.isEmpty {
                Text("No replication agents configured.")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, SpacingTokens.sm)
            } else {
                VStack(spacing: SpacingTokens.xxs) {
                    ForEach(viewModel.agentStatuses) { agent in
                        HStack(spacing: SpacingTokens.sm) {
                            Circle()
                                .fill(agentStatusColor(agent.status))
                                .frame(width: 8, height: 8)
                            Text(agent.name)
                                .font(TypographyTokens.standard)
                                .lineLimit(1)
                            Spacer()
                            Text(agent.agentType)
                                .font(TypographyTokens.compact)
                                .foregroundStyle(ColorTokens.Text.tertiary)
                            Text(agent.status)
                                .font(TypographyTokens.compact.weight(.medium))
                                .foregroundStyle(agentStatusColor(agent.status))
                            if let lastRun = agent.lastRunTime {
                                Text(lastRun)
                                    .font(TypographyTokens.detail)
                                    .foregroundStyle(ColorTokens.Text.tertiary)
                            }
                        }
                        .padding(SpacingTokens.xs)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(ColorTokens.Background.secondary)
                        )
                    }
                }
            }
        } label: {
            Text("Agent Status")
                .font(TypographyTokens.standard.weight(.semibold))
        }
    }

    @ViewBuilder
    private var publicationsSection: some View {
        GroupBox {
            if viewModel.publications.isEmpty {
                HStack {
                    Text("No publications found in this database.")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                    Spacer()
                    Button { showNewPublicationSheet = true } label: {
                        Label("New Publication", systemImage: "plus")
                    }
                    .controlSize(.small)
                    .disabled(viewModel.isBusy)
                }
                .padding(.vertical, SpacingTokens.sm)
            } else {
                VStack(spacing: SpacingTokens.xxs) {
                    ForEach(viewModel.publications) { pub in
                        publicationRow(pub)
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    Task { await viewModel.deletePublication(pub) }
                                }
                            }
                    }
                }
            }
        } label: {
            HStack {
                Text("Publications")
                    .font(TypographyTokens.standard.weight(.semibold))
                Spacer()
                if !viewModel.publications.isEmpty {
                    Button { showNewPublicationSheet = true } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                    .disabled(viewModel.isBusy)
                }
            }
        }
    }

    @ViewBuilder
    private func publicationRow(_ pub: SQLServerPublication) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    if viewModel.expandedPublication == pub.name {
                        viewModel.expandedPublication = nil
                        viewModel.articles = []
                    } else {
                        viewModel.expandedPublication = pub.name
                        Task { await viewModel.loadArticles(publicationName: pub.name) }
                    }
                }
            } label: {
                HStack(spacing: SpacingTokens.sm) {
                    Image(systemName: viewModel.expandedPublication == pub.name ? "chevron.down" : "chevron.right")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                        .frame(width: 12)
                    Text(pub.name)
                        .font(TypographyTokens.standard)
                    typeBadge(pub.publicationType)
                    Spacer()
                    if !pub.description.isEmpty {
                        Text(pub.description)
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                            .lineLimit(1)
                    }
                }
            }
            .buttonStyle(.plain)

            if viewModel.expandedPublication == pub.name {
                articlesSubsection
                    .padding(.leading, SpacingTokens.lg)
            }
        }
        .padding(SpacingTokens.xs)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(ColorTokens.Background.secondary)
        )
    }

    @ViewBuilder
    private var articlesSubsection: some View {
        if viewModel.articles.isEmpty {
            Text("No articles.")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.tertiary)
        } else {
            ForEach(viewModel.articles) { article in
                HStack(spacing: SpacingTokens.sm) {
                    Image(systemName: "tablecells")
                        .foregroundStyle(ColorTokens.Text.tertiary)
                    Text(article.sourceObject.isEmpty ? article.name : article.sourceObject)
                        .font(TypographyTokens.detail)
                }
            }
        }
    }

    private func typeBadge(_ type: SQLServerPublicationType) -> some View {
        Text(type.displayName)
            .font(TypographyTokens.compact)
            .padding(.horizontal, SpacingTokens.xxs)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(ColorTokens.Background.tertiary)
            )
            .foregroundStyle(ColorTokens.Text.secondary)
    }

    @ViewBuilder
    private var subscriptionsSection: some View {
        GroupBox {
            if viewModel.subscriptions.isEmpty {
                HStack {
                    Text("No subscriptions found.")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                    Spacer()
                    Button { showNewSubscriptionSheet = true } label: {
                        Label("New Subscription", systemImage: "plus")
                    }
                    .controlSize(.small)
                    .disabled(viewModel.isBusy || viewModel.publications.isEmpty)
                }
                .padding(.vertical, SpacingTokens.sm)
            } else {
                VStack(spacing: SpacingTokens.xxs) {
                    ForEach(viewModel.subscriptions) { sub in
                        HStack(spacing: SpacingTokens.sm) {
                            Image(systemName: "arrow.right.circle")
                                .foregroundStyle(ColorTokens.Text.tertiary)
                            Text("\(sub.subscriberServer).\(sub.subscriberDB)")
                                .font(TypographyTokens.standard)
                            Spacer()
                            Text(sub.isPush ? "Push" : "Pull")
                                .font(TypographyTokens.compact)
                                .foregroundStyle(ColorTokens.Text.secondary)
                            Text(sub.statusDisplayName)
                                .font(TypographyTokens.compact)
                                .foregroundStyle(ColorTokens.Text.secondary)
                        }
                        .padding(SpacingTokens.xs)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(ColorTokens.Background.secondary)
                        )
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                Task {
                                    if let firstPub = viewModel.publications.first?.name {
                                        await viewModel.deleteSubscription(sub, publicationName: firstPub)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } label: {
            HStack {
                Text("Subscriptions")
                    .font(TypographyTokens.standard.weight(.semibold))
                Spacer()
                if !viewModel.subscriptions.isEmpty {
                    Button { showNewSubscriptionSheet = true } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                    .disabled(viewModel.isBusy || viewModel.publications.isEmpty)
                }
            }
        }
    }

    private func agentStatusColor(_ status: String) -> Color {
        switch status {
        case "Succeeded", "Idle": return ColorTokens.Status.success
        case "In progress", "Started": return ColorTokens.Status.info
        case "Retrying": return ColorTokens.Status.warning
        case "Failed": return ColorTokens.Status.error
        default: return ColorTokens.Text.tertiary
        }
    }
}
