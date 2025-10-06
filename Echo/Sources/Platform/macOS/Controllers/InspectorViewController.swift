//
//  InspectorViewController.swift
//  Echo
//
//  Created by Codex on 07/10/2025.
//

import AppKit
import SwiftUI

final class InspectorViewController: NSViewController {
    private let appModel: AppModel
    private var hostingController: NSHostingController<InspectorWrapperView>?

    init(appModel: AppModel) {
        self.appModel = appModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let inspectorView = InspectorWrapperView(appModel: appModel)
        let hosting = NSHostingController(rootView: inspectorView)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = NSColor.clear.cgColor

        // Create container view that extends to top
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

private struct InspectorWrapperView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        InfoSidebarView()
            .environmentObject(appModel)
            .ignoresSafeArea()
    }
}
