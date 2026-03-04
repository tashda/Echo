import SwiftUI
import AppKit

final class ResultTableContainerView: NSView {
    private let scrollView: NSScrollView
    private let leadingView: NSView
    private var leadingWidth: CGFloat
    private var backgroundColor: NSColor

    init(scrollView: NSScrollView, leadingWidth: CGFloat) {
        self.scrollView = scrollView
        self.leadingWidth = leadingWidth
        self.backgroundColor = .clear
        self.leadingView = NSView()
        super.init(frame: .zero)
        
        leadingView.wantsLayer = true
        addSubview(leadingView)
        addSubview(scrollView)
        
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupConstraints() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        leadingView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            leadingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            leadingView.topAnchor.constraint(equalTo: topAnchor),
            leadingView.bottomAnchor.constraint(equalTo: bottomAnchor),
            leadingView.widthAnchor.constraint(equalToConstant: leadingWidth),
            
            scrollView.leadingAnchor.constraint(equalTo: leadingView.trailingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    func updateLeadingWidth(_ width: CGFloat) {
        guard leadingWidth != width else { return }
        leadingWidth = width
        leadingView.widthAnchor.constraint(equalToConstant: width).isActive = true
        needsLayout = true
    }

    func updateBackgroundColor(_ color: NSColor) {
        backgroundColor = color
        leadingView.layer?.backgroundColor = color.cgColor
    }

    var tableView: NSTableView? {
        scrollView.documentView as? NSTableView
    }
}
