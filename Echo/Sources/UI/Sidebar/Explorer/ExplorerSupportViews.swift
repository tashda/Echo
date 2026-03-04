import SwiftUI
import AppKit
import EchoSense

@MainActor
final class ExplorerDebugLogState {
    static let shared = ExplorerDebugLogState()
    var lastDatabaseBySession: [UUID: String] = [:]
}

struct ConnectedServerCard: View {
    let session: ConnectionSession
    let isSelected: Bool
    @Binding var isExpanded: Bool
    let showCurrentDatabase: Bool
    let onSelectServer: () -> Void
    let onPickDatabase: (String) -> Void

    @EnvironmentObject private var workspaceSessionStore: WorkspaceSessionStore
    @State private var isHovered = false

    private var availableDatabases: [DatabaseInfo] {
        if let structure = session.databaseStructure {
            return structure.databases
        }
        if let cached = session.connection.cachedStructure {
            return cached.databases
        }
        return []
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .top), count: 2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if isExpanded, !availableDatabases.isEmpty {
                Divider()
                    .padding(.horizontal, 16)
                    .padding(.top, 6)

                ScrollView {
                    LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 8) {
                        ForEach(availableDatabases) { database in
                            CompactDatabaseCard(
                                database: database,
                                isSelected: database.name == session.selectedDatabaseName,
                                serverColor: session.connection.color,
                                onSelect: {
                                    onPickDatabase(database.name)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .frame(maxHeight: 160)
                .scrollIndicators(.hidden)
            }
        }
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(isHovered || isExpanded ? 0.14 : 0.05), radius: isExpanded ? 12 : 6, x: 0, y: isExpanded ? 8 : 3)
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: isExpanded)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                icon

                VStack(alignment: .leading, spacing: 3) {
                    Text(session.connection.connectionName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("\(session.connection.username)@\(session.connection.host)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if showCurrentDatabase, let database = session.selectedDatabaseName {
                    Text(database)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(session.connection.color.opacity(0.18), in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(session.connection.color.opacity(0.35), lineWidth: 0.6)
                        )
                        .shadow(color: session.connection.color.opacity(0.2), radius: 4, x: 0, y: 2)
                }

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .frame(width: 20, height: 20)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    isExpanded.toggle()
                }
            }
            .onTapGesture(count: 2) {
                onSelectServer()
            }
        }
    }

    private var icon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(session.connection.color.opacity(0.18))
                .frame(width: 32, height: 32)
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(session.connection.color.opacity(0.35), lineWidth: 1)
            Image(session.connection.databaseType.iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 15, height: 15)
                .foregroundStyle(session.connection.color)
        }
        .shadow(color: session.connection.color.opacity(0.15), radius: 2, x: 0, y: 1)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                isSelected ? session.connection.color.opacity(0.18) : Color.primary.opacity(isHovered ? 0.07 : 0.04)
            )
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(isSelected ? session.connection.color.opacity(0.35) : Color.primary.opacity(0.05), lineWidth: 0.9)
    }
}

struct CompactDatabaseCard: View {
    let database: DatabaseInfo
    let isSelected: Bool
    let serverColor: Color
    let onSelect: () -> Void

    @State private var isHovered = false

    private var schemaCountText: String {
        let count = database.schemas.isEmpty ? database.schemaCount : database.schemas.count
        return "\(count)"
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(serverColor)
                        .frame(width: 4, height: 4)
                    Text(database.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isSelected ? serverColor : .primary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(serverColor)
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.tertiary)
                    Text(schemaCountText)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 50, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isSelected ? serverColor.opacity(0.08) : Color.clear)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        isSelected ? serverColor.opacity(0.3) : (isHovered ? Color.primary.opacity(0.05) : .clear),
                        lineWidth: isSelected ? 1 : 0.5
                    )
            )
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct ExplorerLoadingOverlay: View {
    let progress: Double?
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            if let progress {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(width: 160)
            } else {
                ProgressView()
                    .scaleEffect(0.85)
            }

            Text(message)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.22), radius: 18, x: 0, y: 12)
    }
}

#if os(macOS)
struct ExplorerSidebarFocusResetter: NSViewRepresentable {
    @Binding var isSearchFieldFocused: Bool

    func makeNSView(context: Context) -> FocusResetView {
        FocusResetView()
    }

    func updateNSView(_ nsView: FocusResetView, context: Context) {
        nsView.onDismiss = { [binding = $isSearchFieldFocused] in
            DispatchQueue.main.async {
                guard binding.wrappedValue else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    binding.wrappedValue = false
                }
            }
        }
        nsView.isSearchFieldFocused = isSearchFieldFocused
    }

    @MainActor
    final class FocusResetView: NSView {
        var onDismiss: (() -> Void)?
        var isSearchFieldFocused: Bool = false {
            didSet { updateMonitor() }
        }

        private var monitor: Any?

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            translatesAutoresizingMaskIntoConstraints = false
            wantsLayer = false
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            updateMonitor()
        }

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            if newWindow == nil {
                removeMonitor()
            }
            super.viewWillMove(toWindow: newWindow)
        }

        @MainActor deinit {
            removeMonitor()
        }

        private func updateMonitor() {
            guard window != nil else {
                removeMonitor()
                return
            }

            if isSearchFieldFocused {
                installMonitorIfNeeded()
            } else {
                removeMonitor()
            }
        }

        private func installMonitorIfNeeded() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
                guard let self else { return event }
                guard let window = self.window else {
                    self.onDismiss?()
                    return event
                }

                if event.window !== window {
                    self.onDismiss?()
                    return event
                }

                let locationInWindow = event.locationInWindow
                let locationInView = self.convert(locationInWindow, from: nil)
                if !self.bounds.contains(locationInView) {
                    self.onDismiss?()
                }

                return event
            }
        }

        private func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }
    }
}
#else
struct ExplorerSidebarFocusResetter: View {
    @Binding var isSearchFieldFocused: Bool
    var body: some View {
        EmptyView()
    }
}
#endif
