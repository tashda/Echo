#if os(macOS)
import AppKit
import SwiftUI

/// Rounds 28.12 and 28.13: the editor's own find and replace, in place of the system's find bar.
/// ⌘F opens Find, ⌥⌘F Find and Replace (SH0); ⌘G, ⇧⌘G and ⌘E work as on every Mac. A word selected
/// when it opens becomes the search (SE1); a selection over several lines becomes its scope (SS4).
extension SQLTextView {
    func showFind(replace: Bool) {
        let selection = selectedRange()
        let text = string as NSString
        if selection.length > 0, NSMaxRange(selection) <= text.length {
            let selected = text.substring(with: selection)
            if selected.contains("\n") {
                find.scope = selection
                find.isScopeOn = true
            } else {
                find.scope = nil
                find.isScopeOn = false
                find.query = selected
            }
        }
        // FO0: ⌘F with Replace open leaves it open.
        if replace { find.isReplaceOpen = true }
        find.isOpen = true
        find.focusRequest += 1
        installFindBar()
        refreshFind()
    }

    func closeFind() {
        find.isOpen = false
        find.isReplaceOpen = false
        find.scope = nil
        findBarView?.removeFromSuperview()
        findBarView = nil
        clearReplacePreview()
        setNeedsDisplay(visibleRect)
        window?.makeFirstResponder(self)
    }

    /// Recomputes the matches after the search, its options or the text changed.
    func refreshFind() {
        guard find.isOpen else { return }
        let scope = find.isScopeOn ? find.scope : nil
        find.matches = EditorFind.matches(of: find.query, in: string as NSString, scope: scope,
                                          matchCase: find.matchCase, wholeWords: find.wholeWords)
        let caret = selectedRange().location
        if !find.matches.indices.contains(find.current) {
            find.current = find.matches.firstIndex { $0.location >= caret } ?? 0
        }
        updateReplacePreview()
        setNeedsDisplay(visibleRect)
    }

    func findNext(_ direction: Int) {
        if !find.isOpen { showFind(replace: false) }
        guard !find.matches.isEmpty else { NSSound.beep(); return }
        find.current = (find.current + direction + find.matches.count) % find.matches.count
        if let match = find.currentMatch { scrollRangeToVisible(match) }
        setNeedsDisplay(visibleRect)
    }

    /// RK0: replaces the current match; the next one becomes current.
    func replaceCurrentMatch() {
        guard let match = find.currentMatch, shouldChangeText(in: match, replacementString: find.replacement) else { return }
        clearReplacePreview()
        textStorage?.replaceCharacters(in: match, with: find.replacement)
        didChangeText()
        let replacedEnd = match.location + (find.replacement as NSString).length
        shiftScope(by: (find.replacement as NSString).length - match.length)
        refreshFind()
        // The next match after what was just written (a replacement can contain the search).
        find.current = find.matches.firstIndex { $0.location >= replacedEnd } ?? 0
        setNeedsDisplay(visibleRect)
        if let next = find.currentMatch { scrollRangeToVisible(next) }
    }

    /// UN0: every match replaced as one change, undone with one ⌘Z; RA0: the count says how many.
    func replaceAllMatches() {
        let ranges = find.matches
        guard !ranges.isEmpty else { return }
        let replacements = Array(repeating: find.replacement, count: ranges.count)
        guard shouldChangeText(inRanges: ranges.map { NSValue(range: $0) }, replacementStrings: replacements) else { return }
        clearReplacePreview()
        textStorage?.beginEditing()
        for range in ranges.reversed() { textStorage?.replaceCharacters(in: range, with: find.replacement) }
        textStorage?.endEditing()
        didChangeText()
        shiftScope(by: ((find.replacement as NSString).length - (find.query as NSString).length) * ranges.count)
        refreshFind()
        find.status = "Replaced \(ranges.count)"
    }

    private func shiftScope(by delta: Int) {
        guard let scope = find.scope else { return }
        find.scope = NSRange(location: scope.location, length: max(scope.length + delta, 0))
    }

    /// The bar floats over the top of the editor, centred (FB5).
    private func installFindBar() {
        guard findBarView == nil, let host = enclosingScrollView?.superview ?? enclosingScrollView else { return }
        find.onChange = { [weak self] in self?.refreshFind() }
        find.onNext = { [weak self] in self?.findNext(1) }
        find.onPrevious = { [weak self] in self?.findNext(-1) }
        find.onReplace = { [weak self] in self?.replaceCurrentMatch() }
        find.onReplaceAll = { [weak self] in self?.replaceAllMatches() }
        find.onClose = { [weak self] in self?.closeFind() }
        let bar = NSHostingView(rootView: EditorFindBar(find: find))
        bar.sizingOptions = [.intrinsicContentSize]
        bar.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(bar)
        NSLayoutConstraint.activate([
            bar.centerXAnchor.constraint(equalTo: host.centerXAnchor),
            bar.topAnchor.constraint(equalTo: host.topAnchor, constant: SpacingTokens.xs),
        ])
        findBarView = bar
    }

    /// Edit › Find's items (they send the system's find actions by tag).
    override func performTextFinderAction(_ sender: Any?) {
        handleFindAction(tag: (sender as? NSValidatedUserInterfaceItem)?.tag ?? NSTextFinder.Action.showFindInterface.rawValue)
    }

    override func performFindPanelAction(_ sender: Any?) {
        handleFindAction(tag: (sender as? NSValidatedUserInterfaceItem)?.tag ?? NSTextFinder.Action.showFindInterface.rawValue)
    }

    private func handleFindAction(tag: Int) {
        switch NSTextFinder.Action(rawValue: tag) {
        case .showReplaceInterface: showFind(replace: true)
        case .nextMatch: findNext(1)
        case .previousMatch: findNext(-1)
        case .replaceAll, .replaceAllInSelection: replaceAllMatches()
        case .replace, .replaceAndFind: replaceCurrentMatch()
        case .setSearchString:
            let selection = selectedRange()
            if selection.length > 0 { find.query = (string as NSString).substring(with: selection) }
        case .hideFindInterface: closeFind()
        case .hideReplaceInterface: find.isReplaceOpen = false
        default: showFind(replace: false)
        }
    }

    override func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(performTextFinderAction(_:)) || item.action == #selector(performFindPanelAction(_:)) {
            return true
        }
        return super.validateUserInterfaceItem(item)
    }

    /// The find keys, before the menu sees them.
    func handleFindKey(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let key = event.charactersIgnoringModifiers?.lowercased()
        switch (modifiers, key) {
        case ([.command], "f"): showFind(replace: false)
        case ([.command, .option], "f"): showFind(replace: true)
        case ([.command], "g"): findNext(1)
        case ([.command, .shift], "g"): findNext(-1)
        case ([.command], "e"): handleFindAction(tag: NSTextFinder.Action.setSearchString.rawValue)
        default: return false
        }
        return true
    }
}
#endif
