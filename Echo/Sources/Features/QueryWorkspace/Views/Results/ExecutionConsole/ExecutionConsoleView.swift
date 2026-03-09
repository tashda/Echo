import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

struct ExecutionConsoleView: View {
    let results: QueryResultSet

    @EnvironmentObject internal var appearanceStore: AppearanceStore
    @State internal var messages: [Message] = []
    @State internal var expandedRows: Set<UUID> = []
    internal let columnWidths: [CGFloat] = [64, 320, 110, 90, 110, 160, 80]

    internal var headerBackground: Color {
        ColorTokens.Background.secondary
    }

    internal var gridBackground: Color {
        ColorTokens.Background.primary
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()

            if messages.isEmpty {
                emptyState
            } else {
                tableView
            }
        }
        .background(gridBackground)
        .onAppear {
            buildMessages()
        }
    }

    // MARK: - Components

    private var headerView: some View {
        HStack(spacing: 16) {
            Label("Messages", systemImage: "text.bubble")
                .font(TypographyTokens.standard.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.primary)

            Spacer()

            HStack(spacing: 12) {
                ForEach(Message.Severity.allCases, id: \.self) { severity in
                    let count = messages.filter { $0.severity == severity }.count
                    Label("\(severity.rawValue.capitalized) (\(count))", systemImage: severity.iconName)
                        .font(TypographyTokens.detail.weight(.medium))
                        .foregroundStyle(severity.tint(using: appearanceStore.accentColor))
                }
            }

            Spacer()

            Button {
                messages.removeAll()
                expandedRows.removeAll()
            } label: {
                Label("Clear", systemImage: "trash")
                    .font(TypographyTokens.detail.weight(.medium))
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs2)
        .background(headerBackground)
    }

    private var tableView: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: []) {
                tableHeader
                ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                    messageRow(message, index: index)
                    if expandedRows.contains(message.id) {
                        messageDetails(message, index: index)
                    }
                    Divider()
                }
            }
        }
        .background(gridBackground)
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            headerCell("Number", width: columnWidths[0], alignment: .leading)
            headerCell("Message", width: columnWidths[1], alignment: .leading)
            headerCell("Time", width: columnWidths[2], alignment: .leading)
            headerCell("Delta", width: columnWidths[3], alignment: .leading)
            headerCell("Duration", width: columnWidths[4], alignment: .leading)
            headerCell("Procedure", width: columnWidths[5], alignment: .leading)
            headerCell("Line", width: columnWidths[6], alignment: .leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, SpacingTokens.sm)
        .frame(height: 28)
        .background(headerBackground)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func headerCell(_ title: String, width: CGFloat, alignment: Alignment) -> some View {
        Text(title)
            .font(TypographyTokens.detail.weight(.semibold))
            .foregroundColor(ColorTokens.Text.secondary)
            .frame(width: width, alignment: alignment)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(ColorTokens.Text.secondary)
            Text("No Messages")
                .font(TypographyTokens.display.weight(.semibold))
            Text("Server and execution output will appear here once available.")
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        .padding(.vertical, 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(gridBackground)
    }

    // MARK: - Helpers

    internal func toggle(_ id: UUID) {
        if expandedRows.contains(id) {
            expandedRows.remove(id)
        } else {
            expandedRows.insert(id)
        }
    }

    internal func rowBackground(index: Int, severity: Message.Severity) -> some View {
        let base = ColorTokens.Background.secondary

        let overlay: Color
        switch severity {
        case .error:
            overlay = Color.red.opacity(0.08)
        case .warning:
            overlay = Color.orange.opacity(0.06)
        case .info:
            overlay = appearanceStore.accentColor.opacity(0.04)
        case .debug:
            overlay = Color.clear
        }
        return base.overlay(overlay)
    }

    internal func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

}
