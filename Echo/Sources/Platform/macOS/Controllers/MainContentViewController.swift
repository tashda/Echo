//
//  MainContentViewController.swift
//  Echo
//
//  Created by Codex on 07/10/2025.
//

import AppKit
import SwiftUI

final class MainContentViewController: NSViewController {
    private let tabID: UUID?
    private let appModel: AppModel
    private let appState: AppState
    private let clipboardHistory: ClipboardHistoryStore
    private var hostingController: NSHostingController<MainContentWrapperView>?

    init(
        tabID: UUID?,
        appModel: AppModel,
        appState: AppState,
        clipboardHistory: ClipboardHistoryStore
    ) {
        self.tabID = tabID
        self.appModel = appModel
        self.appState = appState
        self.clipboardHistory = clipboardHistory
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let contentView = MainContentWrapperView(
            tabID: tabID,
            appModel: appModel,
            appState: appState,
            clipboardHistory: clipboardHistory,
            themeManager: ThemeManager.shared
        )
        let hosting = NSHostingController(rootView: contentView)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let container = NSView()
        container.addSubview(hosting.view)

        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        self.hostingController = hosting
        self.view = container
    }
}

private struct MainContentWrapperView: View {
    let tabID: UUID?
    @ObservedObject var appModel: AppModel
    @ObservedObject var appState: AppState
    @ObservedObject var clipboardHistory: ClipboardHistoryStore
    @ObservedObject var themeManager: ThemeManager

    private var selectedConnection: SavedConnection? { appModel.selectedConnection }
    private var selectedSession: ConnectionSession? {
        guard let connection = selectedConnection else { return nil }
        return appModel.sessionManager.sessionForConnection(connection.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab strip below toolbar (if showing)
            if showsTabStrip {
                QueryTabStrip(
                    leadingPadding: 0,
                    trailingPadding: 0,
                    createNewTab: createNewTab,
                    toggleOverview: { appState.showTabOverview.toggle() }
                )
                .frame(height: 44)
            }

            // Main content
            queryContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeManager.windowBackground)
        .ignoresSafeArea()
        .environmentObject(appModel)
        .environmentObject(appState)
        .environmentObject(clipboardHistory)
        .environmentObject(themeManager)
        .environment(\.useNativeTabBar, false)
    }

    private var queryContent: some View {
        Group {
            if let connection = selectedConnection, let session = selectedSession {
                if appModel.tabManager.activeTab != nil {
                    QueryTabsView(showsTabStrip: false)
                        .environmentObject(appModel)
                        .environmentObject(appState)
                        .environmentObject(themeManager)
                } else {
                    ActiveConnectionView(connection: connection, session: session)
                        .environmentObject(appModel)
                        .environmentObject(appState)
                }
            } else if let connection = selectedConnection {
                DisconnectedConnectionView(connection: connection)
                    .environmentObject(appModel)
                    .environmentObject(appState)
            } else {
                NoConnectionSelectedView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    func createNewTab() {
        guard let activeSession = appModel.sessionManager.activeSession else { return }
        appModel.openQueryTab(for: activeSession)
    }

    private var showsTabStrip: Bool {
        !appModel.tabManager.tabs.isEmpty
    }
}

private struct ActiveConnectionView: View {
    let connection: SavedConnection
    let session: ConnectionSession
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Connected to \(connection.connectionName)")
                .font(.title2)
                .fontWeight(.semibold)

            Text(session.selectedDatabaseName.map { "Database: \($0)" } ?? "No database selected")
                .foregroundStyle(.secondary)

            Button("Disconnect") {
                Task { await appModel.disconnectSession(withID: session.id) }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct DisconnectedConnectionView: View {
    let connection: SavedConnection
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Not Connected")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Connect to \(connection.connectionName) to start working.")
                .foregroundStyle(.secondary)

            Button("Connect") {
                Task { await appModel.connect(to: connection) }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct NoConnectionSelectedView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("No Connection Selected")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Open or add a connection to get started.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
