import SwiftUI
import AppKit

extension ApplicationCacheSettingsView {
    func storageUsageRow(
        title: String,
        usage: UInt64,
        isRefreshing: Bool,
        onRefresh: (() async -> Void)?,
        onClear: @escaping () -> Void,
        usageBreakdown: (total: String, query: String, grid: String)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack {
                Text(title)
                    .font(TypographyTokens.standard.weight(.medium))

                Spacer()

                HStack(spacing: SpacingTokens.sm) {
                    if isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                            .progressViewStyle(.circular)
                            .frame(width: 16, height: 16)
                    } else {
                        Text(EchoFormatters.bytes(usage))
                            .font(TypographyTokens.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    if let onRefresh = onRefresh {
                        Button(action: { Task { await onRefresh() } }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: onClear) {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let breakdown = usageBreakdown {
                HStack(spacing: SpacingTokens.lg) {
                    Label {
                        Text(breakdown.query)
                            .monospacedDigit()
                    } icon: {
                        Text("Queries")
                            .foregroundStyle(.tertiary)
                    }
                    Label {
                        Text(breakdown.grid)
                            .monospacedDigit()
                    } icon: {
                        Text("Grid Data")
                            .foregroundStyle(.tertiary)
                    }
                }
                .font(TypographyTokens.detail)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, SpacingTokens.xxs2)
    }
}

// MARK: - Storage Location Button

struct StorageLocationButton: View {
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
            return "~" + path.dropFirst(homePath.count)
        }
        return path
    }

    var body: some View {
        Button(action: { NSWorkspace.shared.activateFileViewerSelecting([storageLocation]) }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Storage Location")

                    Text(displayPath(storageLocation.path))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Spacer()

                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Toggle With Info (kept for backward compat)

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
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .popover(isPresented: $showInfoPopover,
                     attachmentAnchor: .rect(.bounds),
                     arrowEdge: .trailing) {
                Text(description)
                    .font(TypographyTokens.standard)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(SpacingTokens.md)
                    .frame(width: 280)
            }
        }
    }
}
