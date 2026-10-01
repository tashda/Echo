import AppKit

/// Round 44: the grid's rows, the AppKit blur of the chosen technique on the clip view's visible
/// bottom (where Echo keeps its blur), and a slow scroll so the rows move under it.
@MainActor
final class LabFBGridCoordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    weak var scrollView: NSScrollView?
    /// An unflipped view holding the grid: the variable blur reads its mask upside down in the
    /// flipped clip view, so it sits here, over the grid's bottom.
    weak var host: NSView?
    var columns: [LabColumn] = []
    private let rows = Array(repeating: LabResultsData.rows, count: 10).flatMap { $0 }
    private var look: LabFBLook?
    private var blurViews: [NSView] = []
    private var hostedViews: [NSView] = []
    private var echoBlur: BackdropEdgeBlur?
    private var observer: NSObjectProtocol?
    private var scrollTask: Task<Void, Never>?

    // MARK: Technique

    func apply(_ look: LabFBLook) {
        guard look != self.look, let clip = scrollView?.contentView else { return }
        self.look = look
        (blurViews + hostedViews).forEach { $0.removeFromSuperview() }
        blurViews = []
        hostedViews = []
        echoBlur = nil
        let scale = scrollView?.window?.backingScaleFactor ?? 2
        let pixels = look.reach * scale
        let amount: (CGFloat) -> CGFloat = { t in look.curve.amount(t, holdShare: LabFBLook.footerZone / look.reach) }
        switch look.technique {
        case .echoToday:
            // Exactly Echo's: ScrollBarBlur resting at the footer's room plus the fade.
            let blur = BackdropEdgeBlur(container: clip)
            blur.update(edge: .bottom, height: LabFBLook.footerZone + LayoutTokens.EdgeBlur.fade, radii: LayoutTokens.EdgeBlur.radii)
            echoBlur = blur
        case .stacked:
            let count = look.steps
            for step in 1...count {
                let level = look.strongest * CGFloat(step) / CGFloat(count)
                let below = look.strongest * CGFloat(step - 1) / CGFloat(count)
                let view = LabFBStepView(radius: (level * level - below * below).squareRoot())
                view.setMask(LabFBMaskImage.column(height: Int(pixels)) { t in
                    let x = min(max(amount(t) * CGFloat(count) - CGFloat(step - 1), 0), 1)
                    return x * x * (3 - 2 * x)
                })
                blurViews.append(view)
            }
        case .maskedVariable:
            let view = LabFBMaskedBlurView(frame: .zero)
            view.configure(radius: look.strongest, amount: amount)
            hostedViews.append(view)
        case .material, .fade:
            break
        }
        blurViews.forEach { clip.addSubview($0) }
        hostedViews.forEach { host?.addSubview($0) }
        observe(clip)
        place()
    }

    private func observe(_ clip: NSClipView) {
        guard observer == nil else { return }
        clip.postsBoundsChangedNotifications = true
        clip.postsFrameChangedNotifications = true
        observer = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: clip, queue: nil) { [weak self] _ in
            MainActor.assumeIsolated { self?.place() }
        }
    }

    /// Keeps the views on the clip view's visible bottom as it scrolls.
    func place() {
        guard let clip = scrollView?.contentView, let look else { return }
        let area = clip.bounds
        let y = clip.isFlipped ? area.maxY - look.reach : area.minY
        for view in blurViews {
            view.frame = NSRect(x: area.minX, y: y, width: area.width, height: look.reach)
        }
        if let host {
            for view in hostedViews {
                view.frame = NSRect(x: 0, y: 0, width: host.bounds.width, height: look.reach)
                view.autoresizingMask = [.width, .maxYMargin]
            }
        }
    }

    // MARK: Motion

    func setScrolling(_ scrolling: Bool) {
        scrollTask?.cancel()
        guard scrolling else { return }
        scrollTask = Task(name: "lab-footer-blur-scroll") { @MainActor [weak self] in
            var direction: CGFloat = 1
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(16))
                guard let self, let scrollView = self.scrollView, let document = scrollView.documentView else { return }
                let clip = scrollView.contentView
                let limit = max(document.frame.height - clip.bounds.height + scrollView.contentInsets.bottom, 0)
                var origin = clip.bounds.origin
                origin.y += direction * 0.4
                if origin.y >= limit || origin.y <= 0 { direction *= -1; origin.y = min(max(origin.y, 0), limit) }
                clip.scroll(to: origin)
                scrollView.reflectScrolledClipView(clip)
            }
        }
    }

    func stop() { scrollTask?.cancel() }

    // MARK: Rows

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn,
              let index = columns.firstIndex(where: { $0.id == tableColumn.identifier.rawValue }) else { return nil }
        let label = NSTextField(labelWithString: rows[row][index % rows[row].count])
        label.font = .systemFont(ofSize: NSFont.systemFontSize)
        label.textColor = columns[index].isNumeric ? .linkColor : .labelColor
        label.alignment = columns[index].isNumeric ? .right : .left
        label.lineBreakMode = .byTruncatingTail
        let cell = NSTableCellView()
        label.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: SpacingTokens.xs),
            label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -SpacingTokens.xs),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }
}
