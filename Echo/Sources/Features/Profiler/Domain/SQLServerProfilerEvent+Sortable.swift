import Foundation
import SQLServerKit

extension SQLServerProfilerEvent {
    var sortableTimestamp: Date {
        timestamp ?? .distantPast
    }
    
    var sortableDuration: Int64 {
        duration ?? 0
    }
    
    var sortableCPU: Int {
        cpu ?? 0
    }
    
    var sortableReads: Int64 {
        reads ?? 0
    }
    
    var sortableText: String {
        textData ?? ""
    }
}
