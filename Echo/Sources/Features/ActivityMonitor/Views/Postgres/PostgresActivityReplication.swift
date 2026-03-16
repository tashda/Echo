import SwiftUI
import PostgresWire

struct PostgresActivityReplication: View {
    let info: [PostgresReplicationInfo]
    @Binding var sortOrder: [KeyPathComparator<PostgresReplicationInfo>]

    private var sortedInfo: [PostgresReplicationInfo] {
        info.sorted(using: sortOrder)
    }

    var body: some View {
        if info.isEmpty {
            EmptyStatePlaceholder(
                icon: "arrow.triangle.2.circlepath",
                title: "No Active Replication",
                subtitle: "No streaming replication connections detected"
            )
        } else {
            Table(sortedInfo, sortOrder: $sortOrder) {
                TableColumn("PID", value: \.pid) {
                    Text("\($0.pid)").font(TypographyTokens.detail.monospacedDigit())
                }.width(min: 50, max: 70)

                TableColumn("User") {
                    Text($0.usename).font(TypographyTokens.detail)
                }.width(min: 80, ideal: 100)

                TableColumn("Application") {
                    Text($0.applicationName).font(TypographyTokens.detail)
                }.width(min: 100, ideal: 140)

                TableColumn("Client") {
                    Text($0.clientAddr ?? "")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }.width(min: 100, ideal: 120)

                TableColumn("State") {
                    StatusBadge(text: $0.state)
                }.width(80)

                TableColumn("Sent LSN") {
                    Text($0.sentLsn ?? "\u{2014}")
                        .font(TypographyTokens.detail.monospacedDigit())
                        .foregroundStyle(ColorTokens.Text.secondary)
                }.width(min: 90, ideal: 110)

                TableColumn("Replay LSN") {
                    Text($0.replayLsn ?? "\u{2014}")
                        .font(TypographyTokens.detail.monospacedDigit())
                        .foregroundStyle(ColorTokens.Text.secondary)
                }.width(min: 90, ideal: 110)

                TableColumn("Replay Lag") {
                    if let lag = $0.replayLag, !lag.isEmpty {
                        Text(lag)
                            .font(TypographyTokens.detail.monospacedDigit())
                            .foregroundStyle(ColorTokens.Status.warning)
                    } else {
                        Text("\u{2014}")
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.quaternary)
                    }
                }.width(min: 80, ideal: 100)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
        }
    }
}
