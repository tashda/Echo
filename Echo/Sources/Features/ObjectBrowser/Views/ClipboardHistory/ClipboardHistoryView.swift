import SwiftUI
import Foundation
#if os(macOS)
import AppKit
#endif

struct ClipboardHistoryView: View {
    @Environment(ProjectStore.self) private var projectStore
    @Environment(ClipboardHistoryStore.self) private var clipboardHistory
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    @State private var copiedEntryID: UUID?
    @State private var filter: HistoryFilter = .all

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            header
                .padding(.horizontal, SpacingTokens.md)
                .padding(.top, SpacingTokens.sm)

            if !clipboardHistory.isEnabled {
                disabledPlaceholder
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            } else if filteredEntries.isEmpty {
                placeholder
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: SpacingTokens.sm) {
                        ForEach(filteredEntries) { entry in
                            ClipboardHistoryRow(
                                entry: entry,
                                isRecentlyCopied: copiedEntryID == entry.id,
                                onCopy: { handleCopy(entry) }
                            )
                            .environment(clipboardHistory)
                        }
                        .padding(.horizontal, SpacingTokens.sm)
                        .padding(.vertical, SpacingTokens.xxs)
                    }
                }
            }
        }
        .background(Color.clear)
        .onChange(of: clipboardHistory.lastCopiedEntryID) { _, newValue in
            guard let id = newValue else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                copiedEntryID = id
            }
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                if copiedEntryID == id {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        copiedEntryID = nil
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                Text("Clipboard History")
                    .font(TypographyTokens.headline)
                Text(clipboardHistory.isEnabled ? "Recent items copied from the editor and grid" : "History capture is turned off")
                    .font(TypographyTokens.footnote)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }

            Spacer()

            if clipboardHistory.isEnabled {
                filterMenu
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            ForEach(HistoryFilter.allCases, id: \.self) { option in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        filter = option
                    }
                } label: {
                    if filter == option {
                        Label(option.title, systemImage: "checkmark")
                    } else {
                        Text(option.title)
                    }
                }
            }
        } label: {
            Label(filter.title, systemImage: "line.3.horizontal.decrease.circle")
                .labelStyle(.titleAndIcon)
                .font(TypographyTokens.footnote)
                .padding(SpacingTokens.xs)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(ColorTokens.Text.primary.opacity(0.05))
                )
        }
        .menuIndicator(.hidden)
    }

    private var filteredEntries: [ClipboardHistoryStore.Entry] {
        guard clipboardHistory.isEnabled else { return [] }

        switch filter {
        case .all:
            return clipboardHistory.entries
        case .queryEditor:
            return clipboardHistory.entries.filter { if case .queryEditor = $0.source { return true } else { return false } }
        case .grid:
            return clipboardHistory.entries.filter {
                if case .resultGrid(includeHeaders: false) = $0.source { return true } else { return false }
            }
        case .gridWithHeaders:
            return clipboardHistory.entries.filter {
                if case .resultGrid(includeHeaders: true) = $0.source { return true } else { return false }
            }
        }
    }

    private var placeholder: some View {
        ContentUnavailableView {
            Label("No Clipboard Items Yet", systemImage: "clipboard")
        } description: {
            Text("Copy from the query editor or result grid to build a clipboard history.")
        }
    }

    private var disabledPlaceholder: some View {
        ContentUnavailableView {
            Label("Disabled", systemImage: "nosign")
        } description: {
            Text("Enable clipboard history in Settings to keep track of copied queries and results.")
        } actions: {
            Button("Enable in Settings", action: openClipboardSettings)
        }
    }

    private func handleCopy(_ entry: ClipboardHistoryStore.Entry) {
        clipboardHistory.copyEntry(entry)
    }

    private func openClipboardSettings() {
        #if os(macOS)
        openWindow(id: SettingsWindowScene.sceneID)
        Task {
            try? await Task.sleep(for: .seconds(0.1))
            NotificationCenter.default.post(
                name: .openSettingsSection,
                object: SettingsView.SettingsSection.applicationCache.rawValue
            )
        }
        #endif
    }

    private enum HistoryFilter: CaseIterable {
        case all
        case queryEditor
        case grid
        case gridWithHeaders

        var title: String {
            switch self {
            case .all: return "All"
            case .queryEditor: return "Query Editor"
            case .grid: return "Grid"
            case .gridWithHeaders: return "Grid + Headers"
            }
        }
    }
}
