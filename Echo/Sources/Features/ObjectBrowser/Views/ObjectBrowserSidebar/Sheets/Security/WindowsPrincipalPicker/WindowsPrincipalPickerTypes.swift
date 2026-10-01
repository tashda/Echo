import Foundation
import ActiveDirectory

/// Identifies a single Browse-Active-Directory window invocation. A fresh
/// requestID is generated each time the user clicks "Browse" so multiple
/// pickers can coexist (e.g. one against the Login Editor and one against a
/// Database User Editor on a different connection).
struct WindowsPrincipalPickerWindowValue: Codable, Hashable {
    let requestID: UUID
    let connectionSessionID: UUID
}

/// Callback signature for delivering a picker result back to the caller.
/// Invoked with the resolved `DOMAIN\sAMAccountName` (or UPN if no NetBIOS
/// is known) when the user confirms, or `nil` if they cancel or close the
/// window. The picker owns the format decision because it has the forest's
/// domain catalog and the caller does not.
typealias WindowsPrincipalPickerCallback = @MainActor (String?) -> Void
