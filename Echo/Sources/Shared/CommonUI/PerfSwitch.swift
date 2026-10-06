import SwiftUI

/// DEBUG only: `ECHO_PERF_OFF=sidebar,rail` leaves named parts of the window out, so a trace or the frame meter shows what a part
/// costs (Scripts/perf). Release builds never leave anything out.
enum PerfSwitch {
    static func isOff(_ name: String) -> Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["ECHO_PERF_OFF"]?.split(separator: ",").contains(Substring(name)) == true
        #else
        false
        #endif
    }
}

extension View {
    /// This view, or empty space while the experiment switch `name` is off.
    @ViewBuilder
    func perfSwitch(_ name: String) -> some View {
        if PerfSwitch.isOff(name) { Color.clear } else { self }
    }
}
