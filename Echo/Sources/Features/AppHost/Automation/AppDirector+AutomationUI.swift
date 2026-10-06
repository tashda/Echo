#if DEBUG
import AppKit

/// Script steps that look at and operate the window like a person: find a control through the
/// accessibility tree (in-process, no permission needed) and press it, send a key, type into the
/// focused field, list what is on screen. They are how tool tabs, sheets and editors are traced
/// beyond opening them.
///
///     { "action": "dumpUI" }                                       // prints roles and titles of the front window (a sheet if one is open)
///     { "action": "press", "target": "Add" }                       // the first control whose title, label or value contains it
///     { "action": "press", "target": "Add", "role": "button", "index": 1 }
///     { "action": "key", "target": "escape" }                      // escape, return, tab, or a letter with cmd+
///     { "action": "fieldType", "target": "perf_scratch" }          // types into the focused text field
///     { "action": "scroll", "target": "sheet", "distance": 600 }   // the largest scroll view of the sheet (or front window)
///
/// `window` limits where a step looks: `workspace`, `settings`, `manage`; by default a sheet if one is open,
/// else the key window, else the workspace window.
extension AppDirector {
    func performUIAutomationStep(_ step: AutomationScript.Step) async {
        switch step.action {
        case "axOn":
            // Asks AppKit to build the accessibility tree, as an assistive app would.
            for attribute in ["AXEnhancedUserInterface", "AXManualAccessibility"] {
                NSApp.accessibilitySetOverrideValue(true, forAttribute: NSAccessibility.Attribute(rawValue: attribute))
            }
        case "dumpUI": dumpAutomationUI(window: step.window)
        case "press": pressAutomationControl(step)
        case "click": await performAutomationClick(step)
        case "key": sendAutomationKey(step.target ?? "escape")
        case "fieldType": await typeIntoFocusedField(step.target ?? "", interval: step.seconds ?? 0.05)
        default: break
        }
    }

    // MARK: - Windows

    func automationWindow(_ name: String?) -> NSWindow? {
        let id: NSUserInterfaceItemIdentifier? = switch name {
        case "workspace": AppWindowIdentifier.workspace
        case "settings": AppWindowIdentifier.settings
        case "manage": AppWindowIdentifier.manageConnections
        default: nil
        }
        if let id { return NSApp.windows.first { $0.identifier == id && $0.isVisible } }
        let candidates = [NSApp.keyWindow, NSApp.mainWindow] + NSApp.windows.filter { $0.isVisible }
        for window in candidates.compactMap({ $0 }) {
            if let sheet = window.attachedSheet { return sheet }
            if window.isVisible { return window }
        }
        return NSApp.windows.first { $0.identifier == AppWindowIdentifier.workspace }
    }

    // MARK: - Accessibility tree

    private struct Node {
        let object: NSObject
        let role: String
        let title: String
        let depth: Int
    }

    private func nodes(in window: NSWindow, limit: Int = 6000) -> [Node] {
        var found: [Node] = []
        func visit(_ element: Any, depth: Int) {
            guard found.count < limit, depth < 40, let object = element as? NSObject, let accessible = element as? NSAccessibilityProtocol
            else { return }
            let role = accessible.accessibilityRole()?.rawValue ?? ""
            let title = [accessible.accessibilityTitle(), accessible.accessibilityLabel(),
                         (accessible.accessibilityValue() as? String)]
                .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " | ")
            found.append(Node(object: object, role: role, title: title, depth: depth))
            for child in accessible.accessibilityChildren() ?? [] { visit(child, depth: depth + 1) }
        }
        if let content = window.contentView { visit(content, depth: 0) }
        return found
    }

    private func dumpAutomationUI(window name: String?) {
        guard let window = automationWindow(name) else { print("automation-ui no window"); fflush(stdout); return }
        let all = nodes(in: window)
        print("automation-ui window \(window.identifier?.rawValue ?? "?") title '\(window.title)' sheet=\(window.isSheet) nodes \(all.count)")
        for node in all where !node.title.isEmpty || Self.pressableRoles.contains(node.role) {
            let identifier = (node.object as? NSAccessibilityElementProtocol).map { _ in "" } ?? ""
            print("automation-ui \(String(repeating: " ", count: min(node.depth, 14)))\(node.role.replacingOccurrences(of: "AX", with: "")) \(node.title.prefix(70))\(identifier)")
        }
        fflush(stdout)
    }

    private static let pressableRoles: Set<String> = ["AXButton", "AXMenuItem", "AXMenuButton", "AXPopUpButton", "AXRadioButton",
                                                      "AXCheckBox", "AXTab", "AXLink", "AXDisclosureTriangle", "AXRow", "AXCell",
                                                      "AXTextField", "AXTextArea", "AXComboBox", "AXSegmentedControl"]

    private func pressAutomationControl(_ step: AutomationScript.Step) {
        guard let window = automationWindow(step.window), let query = step.target?.lowercased() else { return }
        let matches = nodes(in: window).filter { node in
            guard node.title.lowercased().contains(query) else { return false }
            if let role = step.role { return node.role.lowercased().contains(role.lowercased()) }
            return Self.pressableRoles.contains(node.role)
        }
        let index = step.index ?? 0
        guard matches.indices.contains(index) else {
            print("automation-press not found '\(query)' (matches \(matches.count)) in \(window.identifier?.rawValue ?? "?")")
            fflush(stdout)
            return
        }
        let node = matches[index]
        let accessible = node.object as? NSAccessibilityProtocol
        if node.role == "AXRow" || node.role == "AXCell" {
            accessible?.setAccessibilitySelected(true)
        }
        let pressed = accessible?.accessibilityPerformPress() ?? false
        print("automation-press \(pressed ? "ok" : "no-press") \(node.role) '\(node.title.prefix(60))'")
        fflush(stdout)
    }

    // MARK: - Mouse

    /// A click at a point of a window, sent to the window as the system would (no cursor moves): the point is
    /// in points from the window's top-left, as `Scripts/perf/axdump` prints it. `index` is the click count,
    /// `role` `right` clicks the right button, `seconds` holds the button down for that long.
    private func performAutomationClick(_ step: AutomationScript.Step) async {
        guard let window = automationWindow(step.window), let x = step.x, let y = step.y else {
            print("automation-click no window or point"); fflush(stdout); return
        }
        let location = NSPoint(x: x, y: window.frame.height - y)
        let isRight = step.role == "right"
        let (down, up): (NSEvent.EventType, NSEvent.EventType) = isRight ? (.rightMouseDown, .rightMouseUp) : (.leftMouseDown, .leftMouseUp)
        func send(_ type: NSEvent.EventType, count: Int) {
            guard let event = NSEvent.mouseEvent(with: type, location: location, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                                 windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: count,
                                                 pressure: type == up ? 0 : 1) else { return }
            // Posted, not sent: a control that tracks the mouse (a column header, a slider) waits for its mouse-up in the event queue.
            NSApp.postEvent(event, atStart: false)
        }
        if let move = NSEvent.mouseEvent(with: .mouseMoved, location: location, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                         windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 0, pressure: 0) {
            NSApp.postEvent(move, atStart: false)
        }
        try? await Task.sleep(for: .milliseconds(60))
        for count in 1...max(step.index ?? 1, 1) {
            send(down, count: count)
            try? await Task.sleep(for: .seconds(step.seconds ?? 0.05))
            send(up, count: count)
            try? await Task.sleep(for: .milliseconds(60))
        }
    }

    // MARK: - Keys and text

    private func sendAutomationKey(_ spec: String) {
        guard let window = automationWindow(nil) else { return }
        let parts = spec.lowercased().split(separator: "+").map(String.init)
        let key = parts.last ?? "escape"
        var flags: NSEvent.ModifierFlags = []
        if parts.contains("cmd") { flags.insert(.command) }
        if parts.contains("shift") { flags.insert(.shift) }
        if parts.contains("alt") { flags.insert(.option) }
        let named: [String: (UInt16, String)] = ["escape": (53, "\u{1b}"), "return": (36, "\r"), "tab": (48, "\t"),
                                                 "down": (125, ""), "up": (126, ""), "space": (49, " "), "delete": (51, "\u{7f}"), "a": (0, "a")]
        let (code, characters) = named[key] ?? (0, key)
        for type in [NSEvent.EventType.keyDown, .keyUp] {
            guard let event = NSEvent.keyEvent(with: type, location: .zero, modifierFlags: flags, timestamp: ProcessInfo.processInfo.systemUptime,
                                               windowNumber: window.windowNumber, context: nil, characters: characters,
                                               charactersIgnoringModifiers: characters, isARepeat: false, keyCode: code)
            else { continue }
            NSApp.postEvent(event, atStart: false)
        }
    }

    private func typeIntoFocusedField(_ text: String, interval: Double) async {
        guard let window = automationWindow(nil), let responder = window.firstResponder as? NSTextView else {
            print("automation-type no focused text field"); fflush(stdout); return
        }
        for character in text {
            Self.markAutomationEvent(String(character))
            responder.insertText(String(character), replacementRange: responder.selectedRange())
            try? await Task.sleep(for: .seconds(interval))
        }
    }
}
#endif
