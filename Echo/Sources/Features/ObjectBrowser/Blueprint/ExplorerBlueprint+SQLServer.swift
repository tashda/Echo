import Foundation

extension ExplorerBlueprint {
    /// Microsoft SQL Server in five sections, grouped as SSMS groups them (round 19): Database
    /// Snapshots at the end of Databases, Linked Servers and Server Triggers in Server Objects,
    /// Integration Services with the other tools under Management.
    nonisolated static let sqlServer = ExplorerBlueprint {
        Databases {
            ItemFolder(.databaseSnapshots, loading: .databaseSnapshots)
        }
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
        Folder(.serverObjects) {
            ItemFolder(.linkedServers, loading: .linkedServers)
            ItemFolder(.serverTriggers, loading: .serverTriggers)
        }
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
            ItemFolder(.integrationServices, loading: .integrationServices)
        }
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
