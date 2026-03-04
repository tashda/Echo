import SwiftUI
import Foundation
#if os(macOS)
import AppKit
#endif

struct ClipboardHistoryView: View {
    @Environment(ProjectStore.self) private var projectStore
    @EnvironmentObject private var clipboardHistory: ClipboardHistoryStore
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    @State private var copiedEntryID: UUID?
    @State private var filter: HistoryFilter = .all

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 12)

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
                    LazyVStack(spacing: 12) {
                        ForEach(filteredEntries) { entry in
                            ClipboardHistoryRow(
                                entry: entry,
                                isRecentlyCopied: copiedEntryID == entry.id,
                                onCopy: { handleCopy(entry) }
                            )
                            .environmentObject(clipboardHistory)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
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
            VStack(alignment: .leading, spacing: 4) {
                Text("Clipboard History")
                    .font(.headline)
                Text(clipboardHistory.isEnabled ? "Recent items copied from the editor and grid" : "History capture is turned off")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
                .font(.footnote)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
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
        VStack(spacing: 16) {
            Image(systemName: "clipboard")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            VStack(spacing: 8) {
                Text("No Clipboard Items Yet")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("Copy from the query editor or result grid to build a clipboard history.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var disabledPlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "nosign")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(.tertiary)

            VStack(spacing: 8) {
                Text("Disabled")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("Enable clipboard history in Settings to keep track of copied queries and results.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: openClipboardSettings) {
                Label("Enable in Settings", systemImage: "gearshape")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func handleCopy(_ entry: ClipboardHistoryStore.Entry) {
        clipboardHistory.copyEntry(entry)
    }

    private func openClipboardSettings() {
        #if os(macOS)
        openWindow(id: SettingsWindowScene.sceneID)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
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

private struct ClipboardHistoryRow: View {
    let entry: ClipboardHistoryStore.Entry
    let isRecentlyCopied: Bool
    let onCopy: () -> Void

    @State private var showInfo = false
#if os(macOS)
    @State private var isHovering = false
#else
    private let isHovering = false
#endif
    @EnvironmentObject private var clipboardHistory: ClipboardHistoryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                icon

                VStack(alignment: .leading, spacing: 8) {
                    headerRow
                    Text(entry.previewText)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if entry.metadata.hasDetails {
                        metadataSection
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
        }
        .background(backgroundShape)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isRecentlyCopied ? Color.accentColor.opacity(0.6) : .clear, lineWidth: 1.2)
                .animation(.easeInOut(duration: 0.2), value: isRecentlyCopied)
        )
        .overlay(alignment: .topLeading) {
            if isRecentlyCopied {
                Label("Copied", systemImage: "checkmark.circle.fill")
                    .font(.caption2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.accentColor.opacity(0.45), lineWidth: 0.8)
                    )
                    .shadow(color: Color.black.opacity(0.16), radius: 6, y: 3)
                    .padding([.top, .leading], 12)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture(perform: onCopy)
#if os(macOS)
        .onHover { hovering in
            isHovering = hovering
        }
#endif
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .animation(.easeInOut(duration: 0.2), value: isRecentlyCopied)
    }

    private var icon: some View {
        Image(systemName: entry.source.iconName)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(entry.source.tint)
            .frame(width: 32, height: 32)
            .background(entry.source.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(entry.source.caption)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(entry.timestampDisplay)
                .font(.caption2)
                .foregroundStyle(.tertiary)

            infoButton
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
                .opacity(0.15)

            HStack(spacing: 8) {
                if let server = sanitizedMetadataValue(entry.metadata.serverName) {
                    metadataBadge(icon: "server.rack", text: server, tint: connectionTint)
                }
                if let database = sanitizedMetadataValue(entry.metadata.databaseName) {
                    metadataBadge(icon: "cylinder", text: database, tint: connectionTint)
                }
                if let object = sanitizedMetadataValue(entry.metadata.objectName) {
                    metadataBadge(icon: "tablecells", text: object)
                }
            }
        }
        .padding(.top, 4)
    }

    private func metadataBadge(icon: String, text: String, tint: Color? = nil) -> some View {
        Label(text, systemImage: icon)
            .font(.caption)
            .foregroundStyle(tint ?? Color.secondary)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background((tint?.opacity(0.18) ?? Color.primary.opacity(0.04)), in: Capsule())
    }

    private func sanitizedMetadataValue(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private var connectionTint: Color {
        if let hex = sanitizedMetadataValue(entry.metadata.connectionColorHex), let color = Color(hex: hex) {
            return color
        }
        return Color.accentColor
    }

    private var backgroundShape: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(isHovering ? Color.primary.opacity(0.06) : Color.primary.opacity(0.02))
    }

    private var infoButton: some View {
        Button {
            showInfo.toggle()
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(4)
        }
        .buttonStyle(.plain)
#if os(macOS)
        .popover(isPresented: $showInfo, arrowEdge: .trailing) {
            infoPopover
                .frame(minWidth: 280, minHeight: 220)
                .padding(16)
        }
#else
        .sheet(isPresented: $showInfo) {
            infoPopover
                .padding(16)
        }
#endif
    }

    private var infoPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: entry.source.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(entry.source.tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.source.caption)
                        .font(.headline)
                    Text(entry.timestampDisplay)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(entry.formattedSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            if entry.metadata.hasDetails {
                metadataSection
            } else {
                Divider()
                    .opacity(0.15)
            }

            if let grid = parsedGrid {
                gridPreview(grid)
            } else {
                ScrollView {
                    Text(entry.content)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }

            Divider()

            Button {
                clipboardHistory.copyEntry(entry)
                showInfo = false
            } label: {
                Label("Copy Data", systemImage: "doc.on.doc")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func gridPreview(_ grid: ParsedGrid) -> some View {
        ScrollView([.vertical, .horizontal]) {
            VStack(spacing: 0) {
                HStack(spacing: 1) {
                    ForEach(grid.headers.indices, id: \.self) { index in
                        gridCell(text: grid.headers[index], isHeader: true)
                    }
                }
                .background(Color.primary.opacity(0.08))

                ForEach(Array(grid.rows.enumerated()), id: \.offset) { rowIndex, row in
                    HStack(spacing: 1) {
                        ForEach(0..<grid.headers.count, id: \.self) { columnIndex in
                            let value = columnIndex < row.count ? row[columnIndex] : ""
                            gridCell(text: value, isHeader: false)
                        }
                    }
                    .background(rowIndex.isMultiple(of: 2) ? Color.primary.opacity(0.03) : Color.clear)
                }
            }
            .padding(1)
        }
        .frame(minHeight: 180)
    }

    private func gridCell(text: String, isHeader: Bool) -> some View {
        Text(text.isEmpty ? "—" : text)
            .font(isHeader ? .subheadline.weight(.semibold) : .system(.body, design: .monospaced))
            .foregroundStyle(isHeader ? Color.primary : Color.primary)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .frame(minWidth: 80, alignment: .leading)
            .background(Color.primary.opacity(isHeader ? 0.08 : 0.02))
    }

    private var parsedGrid: ParsedGrid? {
        guard case .resultGrid(let includeHeaders) = entry.source else { return nil }

        let lines = entry.content
            .components(separatedBy: CharacterSet.newlines)
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return nil }

        let rows = lines.map { $0.components(separatedBy: "\t") }
        guard let firstRow = rows.first else { return nil }

        if includeHeaders {
            let headers = firstRow
            let remaining = Array(rows.dropFirst().prefix(50))
            return ParsedGrid(headers: headers, rows: remaining)
        } else {
            let headers = firstRow.indices.map { "Column \($0 + 1)" }
            let limitedRows = Array(rows.prefix(50))
            return ParsedGrid(headers: headers, rows: limitedRows)
        }
    }

    private struct ParsedGrid {
        var headers: [String]
        var rows: [[String]]
    }
}
