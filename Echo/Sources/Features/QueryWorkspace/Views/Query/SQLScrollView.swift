#if os(macOS)
import AppKit
import SwiftUI
import EchoSense

final class SQLScrollView: NSScrollView {
    let sqlTextView: SQLTextView
    private var theme: SQLEditorTheme
    private var displayOptions: SQLEditorDisplayOptions
    private let lineNumberRuler: LineNumberRulerView
    private var backgroundOverride: NSColor?
    var completionContext: SQLEditorCompletionContext? {
        didSet { sqlTextView.completionContext = completionContext }
    }

    var currentDisplayOptions: SQLEditorDisplayOptions { displayOptions }

    init(theme: SQLEditorTheme,
         display: SQLEditorDisplayOptions,
         backgroundOverride: NSColor?,
         completionContext: SQLEditorCompletionContext? = nil,
         ruleTraceConfig: SQLAutocompleteRuleTraceConfiguration? = nil) {
        self.displayOptions = display
        self.backgroundOverride = backgroundOverride
        self.completionContext = completionContext
        self.sqlTextView = SQLTextView(
            theme: theme,
            displayOptions: display,
            backgroundOverride: backgroundOverride,
            completionContext: completionContext,
            ruleTraceConfig: ruleTraceConfig
        )
        self.lineNumberRuler = LineNumberRulerView(textView: sqlTextView, theme: theme)
        self.theme = theme
        super.init(frame: .zero)
        drawsBackground = false
        wantsLayer = true
        layer?.cornerRadius = 0
        layer?.masksToBounds = false
        borderType = .noBorder
        drawsBackground = false
        backgroundColor = .clear
        contentView.drawsBackground = false
        contentView.backgroundColor = .clear
        hasVerticalScroller = true
        hasHorizontalScroller = false
        autohidesScrollers = true
        autoresizesSubviews = true
        documentView = sqlTextView
        scrollerStyle = .overlay
        verticalScrollElasticity = .automatic
        automaticallyAdjustsContentInsets = false
        contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        sqlTextView.minSize = NSSize(width: 0, height: 320)
        sqlTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        sqlTextView.isVerticallyResizable = true
        sqlTextView.isHorizontallyResizable = false
        sqlTextView.autoresizingMask = [.width]
        sqlTextView.setAccessibilityIdentifier("QueryEditorTextView")

        hasVerticalRuler = true
        rulersVisible = true
        verticalRulerView = lineNumberRuler

        if let textContainer = sqlTextView.textContainer {
            textContainer.widthTracksTextView = true
            textContainer.containerSize = NSSize(width: 800, height: CGFloat.greatestFiniteMagnitude)
            textContainer.lineFragmentPadding = SpacingTokens.xxs1
        }

        sqlTextView.setFrameSize(NSSize(width: 800, height: 360))
        lineNumberRuler.needsDisplay = true
        applyTheme()
        applyDisplay()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        Task { @MainActor [weak sqlTextView] in
            sqlTextView?.cancelPendingCompletions()
        }
    }

    func updateTheme(_ theme: SQLEditorTheme) {
        guard self.theme != theme else { return }
        self.theme = theme
        applyTheme()
    }

    func updateBackgroundOverride(_ color: NSColor?) {
        guard backgroundOverride != color else { return }
        backgroundOverride = color
        contentView.backgroundColor = color ?? .clear
        sqlTextView.backgroundOverride = color
    }

    func updateDisplay(_ options: SQLEditorDisplayOptions) {
        guard displayOptions != options else { return }
        displayOptions = options
        sqlTextView.displayOptions = options
        applyDisplay()
    }

    func setRulerVisible(_ visible: Bool) {
        if displayOptions.showLineNumbers != visible {
            displayOptions.showLineNumbers = visible
            applyDisplay()
        }
    }

    private func applyTheme() {
        backgroundColor = .clear
        contentView.backgroundColor = backgroundOverride ?? .clear
        sqlTextView.theme = theme
        sqlTextView.backgroundOverride = backgroundOverride
        lineNumberRuler.theme = theme
    }

    private func applyDisplay() {
        sqlTextView.displayOptions = displayOptions

        if displayOptions.wrapLines {
            hasHorizontalScroller = false
            autohidesScrollers = true
            sqlTextView.isHorizontallyResizable = false
            sqlTextView.textContainer?.widthTracksTextView = true
        } else {
            hasHorizontalScroller = true
            autohidesScrollers = false
            sqlTextView.isHorizontallyResizable = true
            sqlTextView.textContainer?.widthTracksTextView = false
            sqlTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        }

        if displayOptions.showLineNumbers {
            hasVerticalRuler = true
            rulersVisible = true
            verticalRulerView = lineNumberRuler
            lineNumberRuler.ruleThickness = SpacingTokens.xl
            lineNumberRuler.setFrameSize(NSSize(width: SpacingTokens.xl, height: lineNumberRuler.frame.size.height))
            lineNumberRuler.setBoundsSize(NSSize(width: SpacingTokens.xl, height: lineNumberRuler.bounds.size.height))
            lineNumberRuler.clientView = sqlTextView
            lineNumberRuler.theme = theme
            lineNumberRuler.sqlTextView = sqlTextView
            lineNumberRuler.needsDisplay = true
        } else {
            hasVerticalRuler = false
            rulersVisible = false
            verticalRulerView = nil
        }
    }
}
#endif
