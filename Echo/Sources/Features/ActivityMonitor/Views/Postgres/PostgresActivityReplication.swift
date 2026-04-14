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
            ContentUnavailableView {
                Label("No Active Replication", systemImage: "arrow.triangle.2.circlepath")
            } description: {
                Text("No streaming replication connections detected.")
            }
        } else {
            Table(sortedInfo, sortOrder: $sortOrder) {
                TableColumn("PID", value: \.pid) {
                    Text("\($0.pid)").font(TypographyTokens.Table.numeric)
                }.width(min: 50, max: 70)

                TableColumn("User") {
                    Text($0.usename)
                        .font(TypographyTokens.Table.name)
                }.width(min: 80, ideal: 100)

                TableColumn("Application") {
                    Text($0.applicationName)
                        .font(TypographyTokens.Table.name)
                }.width(min: 100, ideal: 140)

                TableColumn("Client") {
                    Text($0.clientAddr ?? "\u{2014}")
                        .font(TypographyTokens.Table.secondaryName)
                        .foregroundStyle(($0.clientAddr ?? "").isEmpty ? ColorTokens.Text.tertiary : ColorTokens.Text.secondary)
                }.width(min: 100, ideal: 120)

                TableColumn("State") {
                    StatusBadge(text: $0.state)
                }.width(80)

                TableColumn("Sent LSN") {
                    Text($0.sentLsn ?? "\u{2014}")
                        .font(TypographyTokens.Table.path)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }.width(min: 90, ideal: 110)

                TableColumn("Replay LSN") {
                    Text($0.replayLsn ?? "\u{2014}")
                        .font(TypographyTokens.Table.path)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }.width(min: 90, ideal: 110)

                TableColumn("Replay Lag") {
                    if let lag = $0.replayLag, !lag.isEmpty {
                        Text(lag)
                            .font(TypographyTokens.Table.numeric)
                            .foregroundStyle(ColorTokens.Status.warning)
                    } else {
                        Text("\u{2014}")
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                }.width(min: 80, ideal: 100)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .tableColumnAutoResize()
        }
    }
}
