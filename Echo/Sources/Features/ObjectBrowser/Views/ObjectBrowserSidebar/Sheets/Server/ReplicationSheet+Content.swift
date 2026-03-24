import SwiftUI
import SQLServerKit

extension ReplicationSheet {

    @ViewBuilder
    var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.lg) {
                distributorSection
                agentStatusSection
                publicationsSection
                subscriptionsSection
            }
            .padding(SpacingTokens.md)
        }
    }

    @ViewBuilder
    var agentStatusSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text("Agent Status")
                .font(TypographyTokens.standard.weight(.semibold))

            if agentStatuses.isEmpty {
                Text("No replication agents configured.")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            } else {
                ForEach(agentStatuses) { agent in
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
    }

    func agentStatusColor(_ status: String) -> Color {
        switch status {
        case "Succeeded", "Idle": return ColorTokens.Status.success
        case "In progress", "Started": return ColorTokens.Status.info
        case "Retrying": return ColorTokens.Status.warning
        case "Failed": return ColorTokens.Status.error
        default: return ColorTokens.Text.tertiary
        }
    }

    @ViewBuilder
    var distributorSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text("Distributor")
                .font(TypographyTokens.standard.weight(.semibold))

            HStack(spacing: SpacingTokens.sm) {
                Image(systemName: distributorConfigured ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(distributorConfigured ? ColorTokens.Status.success : ColorTokens.Text.tertiary)
                Text(distributorConfigured ? "Distribution is configured" : "Distribution is not configured")
                    .font(TypographyTokens.standard)
            }
            .padding(SpacingTokens.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(ColorTokens.Background.secondary)
            )
        }
    }

    @ViewBuilder
    var publicationsSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text("Publications")
                .font(TypographyTokens.standard.weight(.semibold))

            if publications.isEmpty {
                Text("No publications found in this database.")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            } else {
                ForEach(publications) { pub in
                    publicationRow(pub)
                }
            }
        }
    }

    @ViewBuilder
    func publicationRow(_ pub: SQLServerPublication) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    if expandedPublication == pub.name {
                        expandedPublication = nil
                        articles = []
                    } else {
                        expandedPublication = pub.name
                        Task { await loadArticles(publicationName: pub.name) }
                    }
                }
            } label: {
                HStack(spacing: SpacingTokens.sm) {
                    Image(systemName: expandedPublication == pub.name ? "chevron.down" : "chevron.right")
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

            if expandedPublication == pub.name {
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
    var articlesSubsection: some View {
        if articles.isEmpty {
            Text("No articles.")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.tertiary)
        } else {
            ForEach(articles) { article in
                HStack(spacing: SpacingTokens.sm) {
                    Image(systemName: "tablecells")
                        .foregroundStyle(ColorTokens.Text.tertiary)
                    Text(article.sourceObject.isEmpty ? article.name : article.sourceObject)
                        .font(TypographyTokens.detail)
                }
            }
        }
    }

    func typeBadge(_ type: SQLServerPublicationType) -> some View {
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
    var subscriptionsSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text("Subscriptions")
                .font(TypographyTokens.standard.weight(.semibold))

            if subscriptions.isEmpty {
                Text("No subscriptions found.")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            } else {
                ForEach(subscriptions) { sub in
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
                }
            }
        }
    }
}
