import SwiftUI

struct BookmarkRow: View {
    let bookmark: Bookmark
    let connection: SavedConnection
    @Binding var activePopoverID: UUID?
    let isRecentlyOpened: Bool
    let onOpen: () -> Void
    let onCopy: () -> Void
    let onRename: (String?) -> Void
    let onDelete: () -> Void

    @State private var isHovering = false
    @State private var isRenaming = false
    @State private var renameText = ""
    @FocusState private var renameFieldFocused: Bool

    private var isInfoPresented: Bool { activePopoverID == bookmark.id }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            HStack(alignment: .top, spacing: SpacingTokens.sm) {
                icon
                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    headerRow
                    Text(bookmark.preview).font(TypographyTokens.standard.weight(.medium).monospaced()).foregroundStyle(ColorTokens.Text.primary).lineLimit(3).frame(maxWidth: .infinity, alignment: .leading)
                    metadataSection
                }
            }
            .padding(.vertical, SpacingTokens.sm).padding(.horizontal, SpacingTokens.sm2)
        }
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(isHovering ? ColorTokens.Text.primary.opacity(0.06) : ColorTokens.Text.primary.opacity(0.02)))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(isRecentlyOpened ? ColorTokens.accent.opacity(0.6) : .clear, lineWidth: 1.2))
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture(perform: onOpen)
        .contextMenu {
            Button("Open in New Tab", systemImage: "arrow.up.right.square", action: onOpen)
            Button("Copy", systemImage: "doc.on.doc", action: onCopy)
            Button("Rename", systemImage: "pencil", action: beginRenaming)
            Divider()
            Button("Delete Bookmark", systemImage: "trash", role: .destructive, action: onDelete)
        }
        .onHover { isHovering = $0 }
        .popover(isPresented: Binding(get: { isInfoPresented }, set: { activePopoverID = $0 ? bookmark.id : nil }), arrowEdge: .leading) { popoverContent.frame(width: 420) }
        .onChange(of: bookmark.id) { _, _ in cancelRenaming() }
        .onChange(of: bookmark.title) { _, _ in if !isRenaming { renameText = currentTitleSeed } }
    }

    private var icon: some View {
        TintedIcon(systemImage: sourceIconName, tint: sourceTint, size: 18, boxSize: 32)
    }

    private var headerRow: some View {
        HStack(alignment: .center, spacing: SpacingTokens.xs) {
            if isRenaming {
                TextField("Bookmark title", text: $renameText, onCommit: commitRename).textFieldStyle(.plain).font(TypographyTokens.subheadline.weight(.semibold)).foregroundStyle(ColorTokens.Text.primary).lineLimit(1).focused($renameFieldFocused).onAppear { renameText = currentTitleSeed; Task { renameFieldFocused = true } }.onChange(of: renameFieldFocused) { _, f in if !f { commitRename() } }
            } else { Text(bookmark.primaryLine).font(TypographyTokens.subheadline.weight(.semibold)).foregroundStyle(ColorTokens.Text.primary).lineLimit(1) }
            Spacer(minLength: 0); Text(bookmark.createdAt.formatted(date: .abbreviated, time: .shortened)).font(TypographyTokens.caption2).foregroundStyle(ColorTokens.Text.secondary).opacity(isRenaming ? 0 : 1)
            if !isRenaming { Button { toggleInfoPopover() } label: { Image(systemName: "info.circle").font(TypographyTokens.standard.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary) }.buttonStyle(.plain) }
        }
    }

    private var metadataSection: some View {
        HStack(spacing: SpacingTokens.xs) {
            metadataBadge(icon: "server.rack", text: connectionDisplayName, tint: connectionTint)
            if let db = bookmark.databaseName?.trimmingCharacters(in: .whitespacesAndNewlines), !db.isEmpty { metadataBadge(icon: "cylinder", text: db, tint: connectionTint) }
        }
    }

    private var popoverContent: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            Text("Bookmark Details").font(TypographyTokens.headline)
            ScrollView { Text(bookmark.query).font(TypographyTokens.standard.weight(.medium).monospaced()).frame(maxWidth: .infinity, alignment: .leading) }.frame(maxHeight: 260)
            HStack(spacing: SpacingTokens.sm) {
                Button(action: onOpen) { Label("Open in New Tab", systemImage: "arrow.up.right.square") }.buttonStyle(.borderedProminent)
                Button(action: onCopy) { Label("Copy", systemImage: "doc.on.doc") }.buttonStyle(.bordered)
            }
        }.padding(SpacingTokens.md)
    }

    private var currentTitleSeed: String { bookmark.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? bookmark.title! : bookmark.primaryLine }
    private func beginRenaming() { renameText = currentTitleSeed; isRenaming = true; activePopoverID = nil; Task { renameFieldFocused = true } }
    private func commitRename() { guard isRenaming else { return }; let t = renameText.trimmingCharacters(in: .whitespacesAndNewlines); let n = t.isEmpty ? nil : t; if n != bookmark.title { onRename(n) }; finishRenaming() }
    private func cancelRenaming() { guard isRenaming else { return }; finishRenaming() }
    private func finishRenaming() { isRenaming = false; renameFieldFocused = false }
    private func toggleInfoPopover() { activePopoverID = isInfoPresented ? nil : bookmark.id }
    private func metadataBadge(icon: String, text: String, tint: Color) -> some View { Label(text, systemImage: icon).font(TypographyTokens.caption).foregroundStyle(tint).padding(.vertical, SpacingTokens.xxs).padding(.horizontal, SpacingTokens.xs).background(tint.opacity(0.18), in: Capsule()) }
    private var connectionTint: Color { connection.metadataColorHex.flatMap { Color(hex: $0) } ?? connection.color }
    private var connectionDisplayName: String { let n = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines); return n.isEmpty ? connection.host : n }
    private var sourceIconName: String { switch bookmark.source { case .queryEditorSelection: return "text.cursor"; case .savedQuery: return "bookmark"; case .tab: return "doc.text" } }
    private var sourceTint: Color { switch bookmark.source { case .queryEditorSelection: return .accentColor; case .savedQuery: return .orange; case .tab: return .blue } }
}
