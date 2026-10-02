//
//  EchoApp.swift
//  Echo
//
//  Created by Kenneth Berg on 15/09/2025.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct EchoApp: App {
    @State private var coordinator = AppDirector.shared
    #if os(macOS)
    /// Asks before quitting drops open PostgreSQL transactions (round 21).
    @NSApplicationDelegateAdaptor(EchoAppDelegate.self) private var appDelegate
    #endif

    init() {
        EchoApp.raiseFileDescriptorLimit()
        FontRegistrar.registerBundledFonts()
        #if DEBUG
        // `ECHO_CONFORMANCE=<request>`: capture a specimen for verify-round.py and quit. It needs
        // none of the user's data, so it does not wait for the app to initialize.
        AppDirector.shared.runConformanceIfRequested()
        #endif
        #if os(macOS)
        if let forced = ProcessInfo.processInfo.environment["ECHO_FORCE_APPEARANCE"] {
            switch forced.lowercased() {
            case "dark":
                NSApp?.appearance = NSAppearance(named: .darkAqua)
            case "light":
                NSApp?.appearance = NSAppearance(named: .aqua)
            default:
                break
            }
        }
        #endif
    }

    var body: some Scene {
        SwiftUI.WindowGroup {
            WorkspaceView()
                .providesEchoMotion()
                .environment(coordinator.projectStore)
                .environment(coordinator.connectionStore)
                .environment(coordinator.navigationStore)
                .environment(coordinator.tabStore)
                .environment(coordinator.resultSpoolConfigCoordinator)
                .environment(coordinator.diagramBuilder)
                .environment(coordinator.navigationStore.navigationState)
                .environment(coordinator.environmentState)
                .environment(coordinator.appState)
                .environment(coordinator.clipboardHistory)
                .environment(coordinator.appearanceStore)
                .environment(coordinator.notificationEngine)
                .environment(coordinator.activityEngine)
                .environment(coordinator.authState)
                .task {
                    // Xcode launches the app to host SwiftUI previews; skip the heavy start-up
                    // there so the canvas doesn't time out.
                    guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }
                    await coordinator.initialize()
                }
        }
        .defaultLaunchBehavior(.presented)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            QueryCommands(
                environmentState: coordinator.environmentState,
                appState: coordinator.appState,
                navigationStore: coordinator.navigationStore,
                tabStore: coordinator.tabStore,
                projectStore: coordinator.projectStore
            )
#if os(macOS)
            QueryMenuCommands(
                tabStore: coordinator.tabStore,
                navigationStore: coordinator.navigationStore,
                projectStore: coordinator.projectStore
            )
#endif
            ObjectMenuCommands(selection: .shared)
            AboutCommands()
            AppSettingsCommands()
            SparkleCommands()
#if os(macOS)
            ConnectToCommands(
                appState: coordinator.appState,
                environmentState: coordinator.environmentState,
                projectStore: coordinator.projectStore,
                connectionStore: coordinator.connectionStore,
                navigationStore: coordinator.navigationStore
            )
            ConnectMenuCommands(
                environmentState: coordinator.environmentState,
                projectStore: coordinator.projectStore,
                connectionStore: coordinator.connectionStore,
                navigationStore: coordinator.navigationStore
            )
            ViewMenuCommands(
                appState: coordinator.appState,
                environmentState: coordinator.environmentState,
                navigationStore: coordinator.navigationStore,
                tabStore: coordinator.tabStore
            )
#endif
#if DEBUG
            AutocompleteInspectorCommands()
            PerformanceMonitorCommands()
            StreamingTestHarnessCommands()
#endif
        }
        JobQueueWindow()
        UserEditorWindow()
        LoginEditorWindow()
        WindowsPrincipalPickerWindow()
        RoleEditorWindow()
        DatabaseEditorWindow()
        ServerEditorWindow()
        FunctionEditorWindow()
        PgRoleEditorWindow()
        PublicationEditorWindow()
        SubscriptionEditorWindow()
        TablePropertiesWindow()
        PermissionManagerWindow()
        TriggerEditorWindow()
        ViewEditorWindow()
        SequenceEditorWindow()
        TypeEditorWindow()
        DatabaseMailEditorWindow()
        SettingsWindowScene()
        AboutWindowScene()
#if DEBUG
        AutocompleteInspectorWindow()
        PerformanceMonitorWindow()
        StreamingTestHarnessWindow()
#endif
    }

    /// Raises the per-process file descriptor limit so NIO's kqueue and the many
    /// dedicated SQL Server connections don't exhaust the default 256 fd ceiling.
    private static func raiseFileDescriptorLimit() {
        var limits = rlimit()
        guard getrlimit(RLIMIT_NOFILE, &limits) == 0 else { return }
        limits.rlim_cur = min(limits.rlim_max, 8192)
        setrlimit(RLIMIT_NOFILE, &limits)
    }
}

#if os(macOS)
@MainActor
struct QueryCommands: Commands {
    var environmentState: EnvironmentState
    var appState: AppState
    let navigationStore: NavigationStore
    let tabStore: TabStore
    let projectStore: ProjectStore

    private var customShortcuts: [String: CustomShortcutBinding] {
        projectStore.globalSettings.customKeyboardShortcuts ?? [:]
    }

    private func key(for title: String, default defaultKey: KeyEquivalent) -> KeyEquivalent {
        customShortcuts[title]?.swiftUIKey ?? defaultKey
    }

    private func mods(for title: String, default defaultMods: EventModifiers) -> EventModifiers {
        customShortcuts[title]?.swiftUIModifiers ?? defaultMods
    }

    private var savableTab: WorkspaceTab? {
        guard navigationStore.isWorkspaceWindowKey, let tab = tabStore.activeTab, tab.query != nil else { return nil }
        return tab
    }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button {
                environmentState.openQueryTab()
            } label: {
                Label("New Query Tab", systemImage: "plus.square.on.square")
            }
            .keyboardShortcut(key(for: "New Query Tab", default: "t"), modifiers: mods(for: "New Query Tab", default: [.command]))

            Button(action: {
                guard navigationStore.isWorkspaceWindowKey else { return }
                tabStore.activateNextTab()
            }) {
                Label("Next Tab", systemImage: "chevron.right.square")
            }
            .keyboardShortcut(key(for: "Next Tab", default: .tab), modifiers: mods(for: "Next Tab", default: [.control]))

            Button(action: {
                guard navigationStore.isWorkspaceWindowKey else { return }
                tabStore.activatePreviousTab()
            }) {
                Label("Previous Tab", systemImage: "chevron.left.square")
            }
            .keyboardShortcut(key(for: "Previous Tab", default: .tab), modifiers: mods(for: "Previous Tab", default: [.control, .shift]))

            Button(action: {
                guard navigationStore.isWorkspaceWindowKey else { return }
                _ = tabStore.reopenLastClosedTab(activate: true)
            }) {
                Label("Reopen Closed Tab", systemImage: "arrow.uturn.backward.square")
            }
            .keyboardShortcut(key(for: "Reopen Closed Tab", default: "t"), modifiers: mods(for: "Reopen Closed Tab", default: [.command, .shift]))

            Button {
                if navigationStore.isWorkspaceWindowKey {
                    if let active = tabStore.activeTab {
                        tabStore.closeTab(id: active.id)
                    }
                } else if let keyWindow = NSApplication.shared.keyWindow {
                    keyWindow.performClose(nil)
                }
            } label: {
                Label("Close Query Tab", systemImage: "xmark.square")
            }
            .keyboardShortcut(key(for: "Close Query Tab", default: "w"), modifiers: mods(for: "Close Query Tab", default: [.command]))
        }

        // Round IC (H1): Save writes to the tab's home (its bookmark or .sql file); the first time
        // the Save card asks where. Save As… always asks and moves the home; Save to Bookmarks…
        // and Save to File… keep a copy without moving it.
        CommandGroup(replacing: .saveItem) {
            Button {
                guard let tab = savableTab else { return }
                environmentState.saveTab(tab)
            } label: {
                Label("Save", systemImage: "square.and.arrow.down")
            }
            .keyboardShortcut(key(for: "Save", default: "s"), modifiers: mods(for: "Save", default: [.command]))
            .disabled(savableTab == nil)

            Button {
                guard let tab = savableTab else { return }
                environmentState.presentSaveCard(for: tab, destination: nil, movesHome: true)
            } label: {
                Label("Save As…", systemImage: "square.and.arrow.down.on.square")
            }
            .keyboardShortcut(key(for: "Save As", default: "s"), modifiers: mods(for: "Save As", default: [.command, .shift]))
            .disabled(savableTab == nil)

            Divider()

            Button {
                guard let tab = savableTab else { return }
                environmentState.presentSaveCard(for: tab, destination: .bookmarks)
            } label: {
                Label("Save to Bookmarks…", systemImage: "bookmark")
            }
            .disabled(savableTab == nil)

            Button {
                guard let tab = savableTab else { return }
                environmentState.presentSaveCard(for: tab, destination: .file)
            } label: {
                Label("Save to File…", systemImage: "doc")
            }
            .disabled(savableTab == nil)

            Divider()

            Button {
                guard let tab = savableTab else { return }
                Task { await environmentState.revertToSaved(tab) }
            } label: {
                Label("Revert to Saved", systemImage: "arrow.uturn.backward")
            }
            .disabled(savableTab.map { !environmentState.canRevertToSaved($0) } ?? true)
        }

        CommandGroup(after: .newItem) {
            Button {
                Task { await environmentState.openSQLFile() }
            } label: {
                Label("Open SQL File…", systemImage: "doc.text")
            }
            .keyboardShortcut(key(for: "Open SQL File", default: "o"), modifiers: mods(for: "Open SQL File", default: [.command]))
            .disabled(!navigationStore.isWorkspaceWindowKey)
        }
    }
}

struct AboutCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button {
                openWindow(id: AboutWindowScene.sceneID)
            } label: {
                Label("About Echo", systemImage: "info.circle")
            }
        }
    }
}

struct AutocompleteInspectorCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .help) {
            Button {
                openWindow(id: AutocompleteInspectorWindow.sceneID)
            } label: {
                Label("Autocomplete Management", systemImage: "text.magnifyingglass")
            }
            .keyboardShortcut("m", modifiers: [.command, .option])
        }
    }
}

struct PerformanceMonitorCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .help) {
            Button {
                openWindow(id: PerformanceMonitorWindow.sceneID)
            } label: {
                Label("Performance Monitor", systemImage: "waveform.path.ecg")
            }
            .keyboardShortcut("p", modifiers: [.command, .option])
        }
    }
}

struct StreamingTestHarnessCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .help) {
            Button {
                openWindow(id: StreamingTestHarnessWindow.sceneID)
            } label: {
                Label("Streaming Test Harness", systemImage: "dot.radiowaves.left.and.right")
            }
            .keyboardShortcut("t", modifiers: [.command, .option, .shift])
        }
    }
}

struct AppSettingsCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button {
                openWindow(id: SettingsWindowScene.sceneID)
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .keyboardShortcut(",", modifiers: [.command])
        }
    }
}

struct SparkleCommands: Commands {
    private var updater = SparkleUpdater.shared

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button {
                updater.checkForUpdates()
            } label: {
                Label("Check for Updates", systemImage: "arrow.clockwise.circle")
            }
            .disabled(!updater.canCheckForUpdates)
        }
    }
}

#endif
