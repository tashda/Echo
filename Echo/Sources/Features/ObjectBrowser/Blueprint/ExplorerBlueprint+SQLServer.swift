import Foundation

extension ExplorerBlueprint {
    /// Microsoft SQL Server, in SSMS's order.
    nonisolated static let sqlServer = ExplorerBlueprint {
        Databases()
        Folder(.serverSecurity, loading: .serverSecurity) {
            Folder(.logins) {
                Items(.logins)
                Folder(.certificateLogins, hidesWhenEmpty: true) {
                    Items(.certificateLogins)
                }
            }
            ItemFolder(.serverRoles)
            ItemFolder(.credentials)
        }
        ItemFolder(.databaseSnapshots, loading: .databaseSnapshots)
        Folder(.agentJobs, loading: .agentJobs) {
            Tool(.jobQueue)
            Items(.agentJobs)
        }
        Folder(.management) {
            Tool(.extendedEvents)
            Tool(.databaseMail)
            Tool(.sqlProfiler)
            Tool(.resourceGovernor)
            Tool(.tuningAdvisor)
            Tool(.policyManagement)
            Tool(.activityMonitor)
            Tool(.sqlServerLogs)
        }
        ItemFolder(.integrationServices, loading: .integrationServices)
        ItemFolder(.linkedServers, loading: .linkedServers)
        ItemFolder(.serverTriggers, loading: .serverTriggers)
    } database: {
        ObjectFolders(.tables, .views, .functions, .procedures, .triggers, .synonyms)
        WhenOnline {
            Folder(.databaseSecurity, loading: .databaseSecurity) {
                ItemFolder(.users)
                ItemFolder(.databaseRoles)
                ItemFolder(.applicationRoles)
                ItemFolder(.schemas)
            }
            ItemFolder(.databaseTriggers, loading: .databaseTriggers)
            Folder(.serviceBroker, loading: .serviceBroker) {
                ItemFolder(.messageTypes)
                ItemFolder(.contracts)
                ItemFolder(.queues)
                ItemFolder(.services)
                ItemFolder(.routes)
                ItemFolder(.remoteServiceBindings)
            }
            Folder(.externalResources, loading: .externalResources) {
                ItemFolder(.externalDataSources)
                ItemFolder(.externalTables)
                ItemFolder(.externalFileFormats)
            }
        }
    }
}
