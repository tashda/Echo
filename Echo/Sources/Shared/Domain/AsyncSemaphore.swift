/// A simple counting semaphore for structured concurrency. Limits the number
/// of concurrent operations — callers `await wait()` before starting work and
/// call `signal()` when done.
actor AsyncSemaphore {
    private let limit: Int
    private var count: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) {
        precondition(limit > 0)
        self.limit = limit
        self.count = limit
    }

    /// Suspends until a slot is available.
    func wait() async {
        if count > 0 {
            count -= 1
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    /// Releases a slot, resuming the next waiter if any.
    func signal() {
        if let next = waiters.first {
            waiters.removeFirst()
            next.resume()
        } else {
            count = min(count + 1, limit)
        }
    }
}
