import SwiftUI
import SQLServerKit

struct AGListenerSection: View {
    let listeners: [SQLServerAvailabilityGroupsClient.SQLServerAGListener]
    let detailState: AvailabilityGroupsViewModel.LoadingState

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            SidebarSectionHeader(title: "Listeners (\(listeners.count))")

            if detailState == .loading && listeners.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(SpacingTokens.md)
            } else if listeners.isEmpty {
                Text("No listeners configured for this availability group.")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .padding(SpacingTokens.md)
            } else {
                listenerTable
            }
        }
    }

    private var listenerTable: some View {
        VStack(spacing: 0) {
            listenerHeader
            Divider()
            ForEach(listeners) { listener in
                listenerRow(listener)
                Divider()
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(ColorTokens.Background.secondary)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var listenerHeader: some View {
        HStack(spacing: 0) {
            headerCell("DNS Name", width: 180)
            headerCell("Port", width: 60)
            headerCell("IP Addresses", width: 200)
            headerCell("State", width: 100)
        }
        .padding(.vertical, SpacingTokens.xs)
        .padding(.horizontal, SpacingTokens.sm)
        .background(ColorTokens.Background.tertiary)
    }

    private func listenerRow(_ listener: SQLServerAvailabilityGroupsClient.SQLServerAGListener) -> some View {
        HStack(spacing: 0) {
            Text(listener.dnsName)
                .font(TypographyTokens.detail.weight(.semibold))
                .frame(width: 180, alignment: .leading)

            Text("\(listener.port)")
                .font(TypographyTokens.detail.monospacedDigit())
                .frame(width: 60, alignment: .leading)

            Text(listener.ipAddresses.joined(separator: ", "))
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
                .lineLimit(1)
                .frame(width: 200, alignment: .leading)

            HStack(spacing: SpacingTokens.xxs) {
                Circle()
                    .fill(listener.state == "ONLINE" ? ColorTokens.Status.success : ColorTokens.Text.tertiary)
                    .frame(width: 6, height: 6)
                Text(listener.state)
                    .font(TypographyTokens.detail.weight(.medium))
                    .foregroundStyle(listener.state == "ONLINE" ? ColorTokens.Status.success : ColorTokens.Text.tertiary)
            }
            .frame(width: 100, alignment: .leading)
        }
        .padding(.vertical, SpacingTokens.xs)
        .padding(.horizontal, SpacingTokens.sm)
    }

    private func headerCell(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .font(TypographyTokens.detail.weight(.semibold))
            .foregroundStyle(ColorTokens.Text.secondary)
            .frame(width: width, alignment: .leading)
    }
}
