import Foundation

/// An unattended run (`ECHO_AUTOMATION_ISOLATED=1`, DEBUG builds only) must not touch the person's
/// Keychain, account or stored data: no permission prompts, no sign-in, no shared files. It keeps
/// secrets in memory and its local storage in a throwaway folder.
nonisolated enum AutomationIsolation {
    static let isActive: Bool = {
        #if DEBUG
        ProcessInfo.processInfo.environment["ECHO_AUTOMATION_ISOLATED"] == "1"
        #else
        false
        #endif
    }()
}
