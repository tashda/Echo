import SwiftUI
import AppKit

extension ApplicationCacheSettingsView {
    var workspaceTabToggleRow: some View {
        ToggleWithInfo(
            title: "Keep tabs in memory",
            isOn: keepTabsBinding,
            description: "Keeps each tab's editor and results view alive when switching. This speeds up tab changes at the cost of additional memory usage."
        )
    }

    var queryResultRetentionRow: some View {
        Stepper(value: resultCacheRetentionBinding, in: 1...(24 * 14)) {
            let hours = projectStore.globalSettings.resultSpoolRetentionHours
            let days = Double(hours) / 24.0
            let formattedDays = String(format: "%.1f", days)
            Text("Query Result Retention: \(hours) hour\(hours == 1 ? "" : "s") (~\(formattedDays) days)")
        }
    }

    var unifiedStorageLocationRow: some View {
        UnifiedStorageLocationRow()
    }

    func storageUsageRow(
        title: String,
        usage: UInt64,
        isRefreshing: Bool,
        onRefresh: (() async -> Void)?,
        onClear: @escaping () -> Void,
        usageBreakdown: (total: String, query: String, grid: String)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(TypographyTokens.standard.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                HStack(spacing: 12) {
                    if isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                            .progressViewStyle(.circular)
                            .frame(width: 16, height: 16)
                    } else {
                        Text(EchoFormatters.bytes(usage))
                            .font(TypographyTokens.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    if let onRefresh = onRefresh {
                        Button(action: { Task { await onRefresh() } }) {
                            Image(systemName: "arrow.clockwise")
                                .font(TypographyTokens.caption2.weight(.regular))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: onClear) {
                        Image(systemName: "trash")
                            .font(TypographyTokens.caption2.weight(.regular))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let breakdown = usageBreakdown {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Usage Breakdown")
                        .font(TypographyTokens.detail.weight(.medium))
                        .foregroundStyle(.secondary)

                    HStack {
                        Text("Queries:")
                            .font(TypographyTokens.label)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text(breakdown.query)
                            .font(TypographyTokens.label.weight(.medium))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Grid Data:")
                            .font(TypographyTokens.label)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text(breakdown.grid)
                            .font(TypographyTokens.label.weight(.medium))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, SpacingTokens.xxxs)
            }
        }
        .padding(.vertical, SpacingTokens.xxs)
    }

}

struct UnifiedStorageLocationRow: View {
    private var storageLocation: URL {
        let fm = FileManager.default
        let baseSupport = (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        return baseSupport.appendingPathComponent("Echo", isDirectory: true)
    }

    private func displayPath(_ path: String) -> String {
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(homePath) {
            let suffix = path.dropFirst(homePath.count)
            return "~" + suffix
        }
        return path
    }

    var body: some View {
        LabeledContent {
            Button(action: { NSWorkspace.shared.activateFileViewerSelecting([storageLocation]) }) {
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("Storage Location")

                Text(displayPath(storageLocation.path))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }
}

struct ToggleWithInfo: View {
    let title: String
    @Binding var isOn: Bool
    let description: String
    @State private var showInfoPopover = false

    var body: some View {
        HStack {
            Toggle(title, isOn: $isOn)
                .toggleStyle(.switch)

            Spacer()

            Button(action: { showInfoPopover.toggle() }) {
                Image(systemName: "info.circle")
                    .imageScale(.medium)
                    .font(TypographyTokens.standard.weight(.regular))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .popover(isPresented: $showInfoPopover,
                     attachmentAnchor: .rect(.bounds),
                     arrowEdge: .trailing) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(description)
                        .font(TypographyTokens.standard)
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .frame(width: 240)
                .background(Color(.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}
