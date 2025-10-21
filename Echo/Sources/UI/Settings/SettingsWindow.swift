import SwiftUI
import Foundation
import Combine
#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Primary settings scene built with a native `NavigationSplitView`.
struct SettingsWindow: Scene {
    static let sceneID = "settings"

    var body: some Scene {
        Window("Settings", id: Self.sceneID) {
            SettingsView()
                .environmentObject(AppCoordinator.shared.appModel)
                .environmentObject(AppCoordinator.shared.appState)
                .environmentObject(AppCoordinator.shared.clipboardHistory)
                .environmentObject(ThemeManager.shared)
        }
        .defaultSize(width: 720, height: 520)
    }

}

/// Hosts the sidebar/detail split view and renders each settings section.
struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var clipboardHistory: ClipboardHistoryStore
    @EnvironmentObject private var themeManager: ThemeManager

    enum SettingsSection: String, CaseIterable, Identifiable {
        case appearance
        case queryResults
        case echoSense
        case diagrams
        case applicationCache
        case keyboardShortcuts

        var id: String { rawValue }

        var title: String {
            switch self {
            case .appearance: return "Appearance"
            case .queryResults: return "Query Results"
            case .echoSense: return "EchoSense"
            case .diagrams: return "Diagrams"
            case .applicationCache: return "Application Cache"
            case .keyboardShortcuts: return "Keyboard Shortcuts"
        }
        }

        var systemImage: String? {
            switch self {
            case .appearance: return "paintbrush"
            case .queryResults: return "tablecells"
            case .diagrams: return "rectangle.connected.to.line.below"
            case .applicationCache: return "internaldrive"
            case .keyboardShortcuts: return "command"
            case .echoSense: return nil
        }
        }

        var assetImageName: String? {
            switch self {
            case .echoSense:
                return "bulb.bolt"
            default:
                return nil
            }
        }
    }

#if os(macOS)
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
#endif
    @State private var preferredColumn: NavigationSplitViewColumn = .sidebar
    @State private var selection: SettingsSection? = .appearance
    @State private var navigationHistory: [SettingsSection] = [.appearance]
    @State private var historyIndex: Int = 0
    @State private var isUpdatingFromHistory = false

    private let fixedSidebarWidth: CGFloat = 280

    var body: some View {
        settingsSplitView
        .frame(minWidth: 720, minHeight: 520)
        .onAppear {
            if selection == nil {
                selection = .appearance
            }
#if os(macOS)
            columnVisibility = .all
#endif
            navigationHistory = [.appearance]
            historyIndex = 0
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsSection)) { notification in
            guard let raw = notification.object as? String,
                  let section = SettingsSection(rawValue: raw) else { return }
            selection = section
            preferredColumn = .sidebar
#if os(macOS)
            columnVisibility = .all
#endif
        }
        .onChange(of: selection) { _, newValue in
            guard !isUpdatingFromHistory else {
                isUpdatingFromHistory = false
                return
            }
            guard let newValue else { return }
            if historyIndex < navigationHistory.count - 1 {
                navigationHistory = Array(navigationHistory.prefix(historyIndex + 1))
            }
            guard navigationHistory.last != newValue else {
                historyIndex = navigationHistory.count - 1
                return
            }
            navigationHistory.append(newValue)
            historyIndex = navigationHistory.count - 1
        }
        .accentColor(themeManager.accentColor)
        .preferredColorScheme(themeManager.effectiveColorScheme)
        .background(themeManager.windowBackground)
    }

    @ViewBuilder
    private var settingsSplitView: some View {
#if os(macOS)
        NavigationSplitView(columnVisibility: $columnVisibility, preferredCompactColumn: $preferredColumn) {
            sidebar
        } detail: {
            detailContent
        }
        .toolbar(.hidden, for: .windowToolbar)
        .background(
            TitlebarAccessoryBridge(
                title: selection?.title ?? "Settings",
                canNavigateBack: canNavigateBack,
                canNavigateForward: canNavigateForward,
                onNavigateBack: navigateBack,
                onNavigateForward: navigateForward
            )
        )
#else
        NavigationSplitView(preferredCompactColumn: $preferredColumn) {
            sidebar
        } detail: {
            detailContent
        }
#endif
    }

    private var sidebar: some View {
        List(selection: $selection) {
            ForEach(SettingsSection.allCases) { section in
                Label {
                    Text(section.title)
                } icon: {
                    iconView(for: section)
                }
                .tag(section)
            }
        }
        .navigationTitle("Settings")
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: fixedSidebarWidth, ideal: fixedSidebarWidth, max: fixedSidebarWidth)
#if os(macOS)
        .background(Color.clear)
#else
        .scrollContentBackground(.hidden)
        .background(themeManager.surfaceBackgroundColor)
#endif
    }

    private var detailContent: some View {
#if os(macOS)
        detailBaseContent
            .frame(minWidth: 560, minHeight: 420)
            .background(themeManager.surfaceBackgroundColor)
#else
        detailBaseContent
            .frame(minWidth: 560, minHeight: 420)
            .background(themeManager.surfaceBackgroundColor)
            .navigationTitle(selection?.title ?? "Settings")
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Button(action: navigateBack, label: {
                        Image(systemName: "chevron.left")
                    })
                    .disabled(!canNavigateBack)

                    Button(action: navigateForward, label: {
                        Image(systemName: "chevron.right")
                    })
                    .disabled(!canNavigateForward)
                }
                ToolbarItem(placement: .principal) {
                    Text(selection?.title ?? "Settings")
                        .font(.system(size: 28, weight: .bold))
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
#endif
    }

    private var detailBaseContent: some View {
        Group {
            if let selection {
                sectionView(for: selection)
                    .id(selection)
            } else {
                ContentUnavailableView {
                    Label("Select a Section", systemImage: "slider.horizontal.3")
                } description: {
                    Text("Choose a settings category to view its options.")
                }
            }
        }
    }

    @ViewBuilder
    private func sectionView(for section: SettingsSection) -> some View {
        switch section {
        case .appearance:
            AppearanceSettingsView()
                .environmentObject(appModel)
                .environmentObject(appState)
                .environmentObject(themeManager)

        case .queryResults:
            QueryResultsSettingsView()
                .environmentObject(appModel)
                .environmentObject(appState)
                .environmentObject(themeManager)

        case .echoSense:
            EchoSenseSettingsView()
                .environmentObject(appModel)
                .environmentObject(appState)
                .environmentObject(themeManager)

        case .diagrams:
            DiagramSettingsView()
                .environmentObject(appModel)
                .environmentObject(themeManager)

        case .applicationCache:
            ApplicationCacheSettingsView()
                .environmentObject(clipboardHistory)

        case .keyboardShortcuts:
            KeyboardShortcutsSettingsView()
        }
    }

#if os(macOS)
    @ViewBuilder
    private func iconView(for section: SettingsSection) -> some View {
        if let systemName = section.systemImage {
            Image(systemName: systemName)
        } else if let assetName = section.assetImageName {
            Image(assetName)
                .renderingMode(.template)
        } else {
            Image(systemName: "square")
        }
    }
#else
    @ViewBuilder
    private func iconView(for section: SettingsSection) -> some View {
        if let systemName = section.systemImage {
            Image(systemName: systemName)
        } else if let assetName = section.assetImageName {
            Image(assetName)
                .renderingMode(.template)
        } else {
            Image(systemName: "square")
        }
    }
#endif


#if os(macOS)
    private var canNavigateBack: Bool {
        historyIndex > 0
    }

    private var canNavigateForward: Bool {
        historyIndex + 1 < navigationHistory.count
    }

    private func navigateBack() {
        guard canNavigateBack else { return }
        historyIndex -= 1
        isUpdatingFromHistory = true
        selection = navigationHistory[historyIndex]
    }

    private func navigateForward() {
        guard canNavigateForward else { return }
        historyIndex += 1
        isUpdatingFromHistory = true
        selection = navigationHistory[historyIndex]
    }

#else
    private var canNavigateBack: Bool { historyIndex > 0 }
    private var canNavigateForward: Bool { historyIndex + 1 < navigationHistory.count }
    private func navigateBack() { if canNavigateBack { historyIndex -= 1; isUpdatingFromHistory = true; selection = navigationHistory[historyIndex] } }
    private func navigateForward() { if canNavigateForward { historyIndex += 1; isUpdatingFromHistory = true; selection = navigationHistory[historyIndex] } }
#endif
}

#Preview("Settings Window") {
    SettingsView()
}

extension Notification.Name {
    static let openSettingsSection = Notification.Name("com.fuzee.settings.openSection")
}

#if os(macOS)
private struct TitlebarAccessoryBridge: NSViewRepresentable {
    let title: String
    let canNavigateBack: Bool
    let canNavigateForward: Bool
    let onNavigateBack: () -> Void
    let onNavigateForward: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = AttachmentView()
        view.onWindowChange = { window in
            context.coordinator.update(window: window,
                                       title: title,
                                       canNavigateBack: canNavigateBack,
                                       canNavigateForward: canNavigateForward,
                                       onNavigateBack: onNavigateBack,
                                       onNavigateForward: onNavigateForward)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.update(window: nsView.window,
                                   title: title,
                                   canNavigateBack: canNavigateBack,
                                   canNavigateForward: canNavigateForward,
                                   onNavigateBack: onNavigateBack,
                                   onNavigateForward: onNavigateForward)
        if let attachment = nsView as? AttachmentView {
            attachment.onWindowChange = { window in
                context.coordinator.update(window: window,
                                           title: title,
                                           canNavigateBack: canNavigateBack,
                                           canNavigateForward: canNavigateForward,
                                           onNavigateBack: onNavigateBack,
                                           onNavigateForward: onNavigateForward)
            }
        }
    }

    final class Coordinator {
        final class Configuration: ObservableObject {
            @Published private(set) var title: String
            @Published private(set) var canNavigateBack: Bool
            @Published private(set) var canNavigateForward: Bool
            var onBack: () -> Void
            var onForward: () -> Void

            init(title: String,
                 canNavigateBack: Bool,
                 canNavigateForward: Bool,
                 onNavigateBack: @escaping () -> Void,
                 onNavigateForward: @escaping () -> Void) {
                self.title = title
                self.canNavigateBack = canNavigateBack
                self.canNavigateForward = canNavigateForward
                self.onBack = onNavigateBack
                self.onForward = onNavigateForward
            }

            func update(title: String,
                        canNavigateBack: Bool,
                        canNavigateForward: Bool,
                        onNavigateBack: @escaping () -> Void,
                        onNavigateForward: @escaping () -> Void) {
                if self.title != title {
                    self.title = title
                }
                if self.canNavigateBack != canNavigateBack {
                    self.canNavigateBack = canNavigateBack
                }
                if self.canNavigateForward != canNavigateForward {
                    self.canNavigateForward = canNavigateForward
                }
                onBack = onNavigateBack
                onForward = onNavigateForward
            }
        }

        private weak var currentWindow: NSWindow?
        private var configuration: Configuration?
        private var accessory: NSTitlebarAccessoryViewController?
        private var hostingView: NSHostingView<TitlebarAccessoryView>?
        private var containerView: NSView?

        func update(window: NSWindow?,
                    title: String,
                    canNavigateBack: Bool,
                    canNavigateForward: Bool,
                    onNavigateBack: @escaping () -> Void,
                    onNavigateForward: @escaping () -> Void) {
            guard let window else { return }

            if currentWindow !== window {
                configureWindow(window)
                currentWindow = window
            }

            ensureConfiguration(
                title: title,
                canNavigateBack: canNavigateBack,
                canNavigateForward: canNavigateForward,
                onNavigateBack: onNavigateBack,
                onNavigateForward: onNavigateForward
            )

            ensureAccessory(on: window)

            configuration?.update(
                title: title,
                canNavigateBack: canNavigateBack,
                canNavigateForward: canNavigateForward,
                onNavigateBack: onNavigateBack,
                onNavigateForward: onNavigateForward
            )
        }

        private func configureWindow(_ window: NSWindow) {
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.toolbarStyle = .unified
            window.standardWindowButton(.closeButton)?.isHidden = false
            window.standardWindowButton(.miniaturizeButton)?.isHidden = false
            window.standardWindowButton(.zoomButton)?.isHidden = false
        }

        private func ensureConfiguration(title: String,
                                         canNavigateBack: Bool,
                                         canNavigateForward: Bool,
                                         onNavigateBack: @escaping () -> Void,
                                         onNavigateForward: @escaping () -> Void) {
            guard configuration == nil else { return }
            let config = Configuration(
                title: title,
                canNavigateBack: canNavigateBack,
                canNavigateForward: canNavigateForward,
                onNavigateBack: onNavigateBack,
                onNavigateForward: onNavigateForward
            )
            configuration = config
            hostingView = NSHostingView(rootView: TitlebarAccessoryView(configuration: config))
            hostingView?.translatesAutoresizingMaskIntoConstraints = false
            hostingView?.setContentHuggingPriority(.defaultLow, for: .horizontal)
            hostingView?.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }

        private func ensureAccessory(on window: NSWindow) {
            guard let hostingView else { return }
            let controller: NSTitlebarAccessoryViewController
            if let existing = accessory {
                controller = existing
            } else {
                controller = NSTitlebarAccessoryViewController()
                controller.layoutAttribute = .left
                controller.fullScreenMinHeight = 56
                accessory = controller
            }

            let container: NSView
            if let existingContainer = containerView {
                container = existingContainer
            } else {
                container = NSView()
                container.translatesAutoresizingMaskIntoConstraints = false
                container.setContentHuggingPriority(.required, for: .horizontal)
                container.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

                hostingView.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(hostingView)

                NSLayoutConstraint.activate([
                    hostingView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    hostingView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                    hostingView.topAnchor.constraint(equalTo: container.topAnchor),
                    hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
                ])

                containerView = container
            }

            if controller.view !== container {
                controller.view = container
            }

            if window.titlebarAccessoryViewControllers.contains(controller) == false {
                window.addTitlebarAccessoryViewController(controller)
            }
        }
    }

    private final class AttachmentView: NSView {
        var onWindowChange: ((NSWindow?) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onWindowChange?(window)
        }
    }
}

private struct TitlebarAccessoryView: View {
    @ObservedObject var configuration: TitlebarAccessoryBridge.Coordinator.Configuration

    var body: some View {
        HStack(spacing: 14) {
            NavigationSegmentControl(
                canNavigateBack: configuration.canNavigateBack,
                canNavigateForward: configuration.canNavigateForward,
                onBack: configuration.onBack,
                onForward: configuration.onForward
            )
            .frame(width: 66)

            Text("Settings")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 36)

            Text(configuration.title)
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 26)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(Material.ultraThin)
                        .shadow(color: Color.black.opacity(0.14), radius: 12, y: 8)
                )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

private struct NavigationSegmentControl: NSViewRepresentable {
    let canNavigateBack: Bool
    let canNavigateForward: Bool
    let onBack: () -> Void
    let onForward: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl(
            images: [symbol(named: "chevron.left"), symbol(named: "chevron.right")],
            trackingMode: .momentary,
            target: context.coordinator,
            action: #selector(Coordinator.handle(_:))
        )
        control.segmentStyle = .separated
        control.controlSize = .small
        control.setWidth(30, forSegment: 0)
        control.setWidth(30, forSegment: 1)
        update(control)
        return control
    }

    func updateNSView(_ nsView: NSSegmentedControl, context: Context) {
        context.coordinator.parent = self
        update(nsView)
    }

    private func update(_ control: NSSegmentedControl) {
        control.setEnabled(canNavigateBack, forSegment: 0)
        control.setEnabled(canNavigateForward, forSegment: 1)
    }

    private func symbol(named name: String) -> NSImage {
        let configuration = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) ?? NSImage()
    }

    final class Coordinator: NSObject {
        var parent: NavigationSegmentControl

        init(parent: NavigationSegmentControl) {
            self.parent = parent
        }

        @objc func handle(_ sender: NSSegmentedControl) {
            defer { sender.selectedSegment = -1 }
            switch sender.selectedSegment {
            case 0 where parent.canNavigateBack:
                parent.onBack()
            case 1 where parent.canNavigateForward:
                parent.onForward()
            default:
                break
            }
        }
    }
}
#endif
