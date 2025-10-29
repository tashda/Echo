import Foundation
#if canImport(NIOCore)
import NIOCore
#endif
#if canImport(NIOPosix)
import NIOPosix
#endif
#if canImport(NIO)
import NIO
#endif

enum EchoEventLoopGroup {
    // Single shared EventLoopGroup for all SQL Server connections in the app.
    // Prevents scheduling work on a shutdown loop when connections are closed.
    static let shared: EventLoopGroup = {
        // Use a modest number of threads; 1–2 is sufficient for metadata/query tasks
        let threads = max(1, min(2, System.coreCount))
        return MultiThreadedEventLoopGroup(numberOfThreads: threads)
    }()

    static func shutdown() {
        do { try shared.syncShutdownGracefully() } catch { /* ignore at app teardown */ }
    }
}
