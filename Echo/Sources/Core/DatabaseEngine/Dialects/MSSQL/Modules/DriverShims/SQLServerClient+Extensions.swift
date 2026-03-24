import Foundation
import SQLServerKit

extension SQLServerClient {
    var tuning: SQLServerTuningClient { SQLServerTuningClient(client: self) }
    var profiler: SQLServerProfilerClient { SQLServerProfilerClient(client: self) }
    var resourceGovernor: SQLServerResourceGovernorClient { SQLServerResourceGovernorClient(client: self) }
    var policy: SQLServerPolicyClient { SQLServerPolicyClient(client: self) }
    var dependencies: SQLServerDependencyClient { SQLServerDependencyClient(client: self) }
    var dac: SQLServerDACClient { SQLServerDACClient(client: self) }
    var bulkCopy: SQLServerBulkCopyClient { SQLServerBulkCopyClient(client: self) }
    var ssis: SQLServerSSISClient { SQLServerSSISClient(client: self) }
    var ssas: SQLServerSSASClient { SQLServerSSASClient(client: self) }
    var ssrs: SQLServerSSRSClient { SQLServerSSRSClient(client: self) }
}
