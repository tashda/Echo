import Foundation

actor DiagramPrefetchService {
    struct Request: Hashable, Sendable {
        let cacheKey: DiagramCacheKey
        let connectionSessionID: UUID
        let object: SchemaObjectInfo
        let isBackgroundSweep: Bool

        func hash(into hasher: inout Hasher) {
            hasher.combine(cacheKey.projectID)
            hasher.combine(cacheKey.connectionID)
            hasher.combine(cacheKey.schema)
            hasher.combine(cacheKey.table)
            hasher.combine(cacheKey.layoutID)
            hasher.combine(connectionSessionID)
        }

        static func == (lhs: Request, rhs: Request) -> Bool {
            lhs.cacheKey.projectID == rhs.cacheKey.projectID
                && lhs.cacheKey.connectionID == rhs.cacheKey.connectionID
                && lhs.cacheKey.schema == rhs.cacheKey.schema
                && lhs.cacheKey.table == rhs.cacheKey.table
                && lhs.cacheKey.layoutID == rhs.cacheKey.layoutID
                && lhs.connectionSessionID == rhs.connectionSessionID
        }
    }

    typealias Handler = @Sendable (Request) async -> Bool

    private var queue: [Request] = []
    private var pending: Set<Request> = []
    private var handler: Handler?
    private var isProcessing = false

    func setHandler(_ handler: @escaping Handler) {
        self.handler = handler
        processNextIfNeeded()
    }

    func enqueue(_ request: Request, prioritize: Bool = false) {
        guard !pending.contains(request) else { return }
        pending.insert(request)
        if prioritize {
            queue.insert(request, at: 0)
        } else {
            queue.append(request)
        }
        processNextIfNeeded()
    }

    func cancelAll() {
        queue.removeAll()
        pending.removeAll()
        isProcessing = false
    }

    private func processNextIfNeeded() {
        guard !isProcessing, let handler, !queue.isEmpty else { return }
        isProcessing = true
        let request = queue.removeFirst()
        let priority: TaskPriority = request.isBackgroundSweep ? .utility : .userInitiated
        Task.detached(priority: priority) { [weak self] in
            let success = await handler(request)
            if request.isBackgroundSweep {
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
            await self?.finishProcessing(request: request, succeeded: success)
        }
    }

    private func finishProcessing(request: Request, succeeded: Bool) {
        pending.remove(request)
        isProcessing = false
        processNextIfNeeded()
    }
}
