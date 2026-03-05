#if os(macOS)
import AppKit
import SwiftUI
import QuartzCore

final class ResultTableHeaderView: NSTableHeaderView {
    weak var coordinator: QueryResultsTableView.Coordinator?
    private var isDraggingColumns = false
    private let backgroundLayer = CAGradientLayer()
    private let sheenLayer = CAGradientLayer()
    private let topHighlightLayer = CALayer()
    private let bottomBorderLayer = CALayer()
    private var separatorLayers: [CALayer] = []
    private var separatorColor: CGColor?
    private let resizeEdgeTolerance: CGFloat = 5

    init(coordinator: QueryResultsTableView.Coordinator?) {
        self.coordinator = coordinator
        super.init(frame: .zero)
        configureLayers()
        updateAppearance(with: AppearanceStore.shared)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLayers()
        updateAppearance(with: AppearanceStore.shared)
    }

    private func configureLayers() {
        wantsLayer = true
        layer?.masksToBounds = false

        backgroundLayer.startPoint = CGPoint(x: 0, y: 0)
        backgroundLayer.endPoint = CGPoint(x: 0, y: 1)
        backgroundLayer.locations = [0, 1]
        backgroundLayer.zPosition = -10

        sheenLayer.startPoint = CGPoint(x: 0, y: 0)
        sheenLayer.endPoint = CGPoint(x: 0, y: 1)
        sheenLayer.locations = [0, 0.4, 1]
        sheenLayer.zPosition = -5

        topHighlightLayer.masksToBounds = true
        topHighlightLayer.zPosition = 2
        bottomBorderLayer.masksToBounds = true
        bottomBorderLayer.zPosition = 2

        layer?.addSublayer(backgroundLayer)
        layer?.addSublayer(sheenLayer)
        layer?.addSublayer(topHighlightLayer)
        layer?.addSublayer(bottomBorderLayer)
    }

    func updateAppearance(with theme: AppearanceStore) {
        let style = ResultTableHeaderStyle.make(for: theme)

        backgroundLayer.colors = [
            style.topColor.cgColor,
            style.bottomColor.cgColor
        ]

        sheenLayer.colors = [
            NSColor.white.withAlphaComponent(style.sheenTopAlpha).cgColor,
            NSColor.white.withAlphaComponent(style.sheenMidAlpha).cgColor,
            NSColor.clear.cgColor
        ]

        topHighlightLayer.backgroundColor = NSColor.white.withAlphaComponent(style.highlightAlpha).cgColor
        bottomBorderLayer.backgroundColor = style.borderColor.cgColor
        separatorColor = style.separatorColor
        separatorLayers.forEach { $0.backgroundColor = separatorColor }

        needsLayout = true
        needsDisplay = true
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        backgroundLayer.frame = bounds
        sheenLayer.frame = bounds
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1
        let lineWidth = 1 / max(scale, 1)
        topHighlightLayer.frame = CGRect(x: 0, y: bounds.height - lineWidth, width: bounds.width, height: lineWidth)
        bottomBorderLayer.frame = CGRect(x: 0, y: 0, width: bounds.width, height: lineWidth)
        updateSeparatorFrames(lineWidth: lineWidth)
        CATransaction.commit()
    }

    override func mouseDown(with event: NSEvent) {
        guard event.buttonNumber == 0,
              !event.modifierFlags.contains(.control),
              let tableView = tableView else {
            super.mouseDown(with: event)
            return
        }

        let location = convert(event.locationInWindow, from: nil)
        let column = tableView.column(at: location)
        if column >= 0 {
            let columnRect = headerRect(ofColumn: column)
            let isNearLeftEdge = column > 0 && abs(location.x - columnRect.minX) <= resizeEdgeTolerance
            let isNearRightEdge = abs(location.x - columnRect.maxX) <= resizeEdgeTolerance
            if isNearLeftEdge || isNearRightEdge {
                isDraggingColumns = false
                super.mouseDown(with: event)
                return
            }
            coordinator?.beginColumnSelection(at: column, modifiers: event.modifierFlags)
            isDraggingColumns = true
        } else {
            isDraggingColumns = false
        }
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard event.buttonNumber == 0,
              !event.modifierFlags.contains(.control),
              isDraggingColumns,
              let tableView = tableView else {
            super.mouseDragged(with: event)
            return
        }
        guard !tableView.tableColumns.isEmpty else {
            super.mouseDragged(with: event)
            return
        }
        let location = convert(event.locationInWindow, from: nil)
        var column = tableView.column(at: location)
        if column < 0 {
            column = location.x < 0 ? 0 : tableView.tableColumns.count - 1
        }
        coordinator?.continueColumnSelection(to: column)
        super.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        if isDraggingColumns, event.buttonNumber == 0 {
            coordinator?.endColumnSelection()
        }
        isDraggingColumns = false
        super.mouseUp(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        super.rightMouseDown(with: event)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let location = convert(event.locationInWindow, from: nil)
        let column = tableView?.column(at: location) ?? -1
        coordinator?.prepareHeaderContextMenu(at: column >= 0 ? column : nil)
        return menu ?? super.menu(for: event)
    }

    private func updateSeparatorFrames(lineWidth: CGFloat) {
        guard let tableView else {
            separatorLayers.forEach { $0.removeFromSuperlayer() }
            separatorLayers.removeAll()
            return
        }

        let columnCount = tableView.numberOfColumns
        let required = max(columnCount - 1, 0)

        if separatorLayers.count != required {
            separatorLayers.forEach { $0.removeFromSuperlayer() }
            separatorLayers.removeAll()

            guard required > 0 else { return }

            for _ in 0..<required {
                let layer = CALayer()
                layer.zPosition = 1
                layer.backgroundColor = separatorColor
                self.layer?.addSublayer(layer)
                separatorLayers.append(layer)
            }
        }

        guard !separatorLayers.isEmpty else { return }

        for (index, layer) in separatorLayers.enumerated() {
            let columnRect = tableView.rect(ofColumn: index)
            let converted = convert(columnRect, from: tableView)
            let xPosition = converted.maxX - lineWidth / 2
            layer.backgroundColor = separatorColor
            layer.frame = CGRect(x: xPosition, y: 0, width: lineWidth, height: bounds.height)
        }
    }
}
#endif
