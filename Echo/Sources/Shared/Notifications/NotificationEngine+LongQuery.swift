import SwiftUI
#if os(macOS)
import AppKit
#endif

extension NotificationEngine {
    /// Round 20 (N1): a query of 30 s or more that ends while another app is in front gets a macOS
    /// notification. A success is also kept in the history; a failure is already recorded there
    /// (plan N4), so it only gets the banner.
    func noteQueryEnded(tabTitle: String, succeeded: Bool, duration: TimeInterval?, context: NotificationContext?) {
        guard LongQueryNotice.shouldNotify(duration: duration, echoIsActive: Self.echoIsActive), let duration else { return }
        let body = LongQueryNotice.body(tabTitle: tabTitle, succeeded: succeeded, duration: duration)
        if succeeded {
            history.append(NotificationRecord(category: .generalSuccess, message: body, severity: .success, context: context))
        }
        sendNativeNotification(title: LongQueryNotice.title(succeeded: succeeded), body: body)
    }

    private static var echoIsActive: Bool {
        #if os(macOS)
        return NSApp?.isActive ?? true
        #else
        return true
        #endif
    }
}
