import Foundation

final class ResultSpoolRowCache: @unchecked Sendable {
    private struct Page {
        var rows: ContiguousArray<[String?]?>
        var terminalCount: Int?

        init(pageSize: Int) {
            self.rows = ContiguousArray(repeating: nil, count: pageSize)
            self.terminalCount = nil
        }

        mutating func insert(rows slice: ArraySlice<[String?]>, startingAt offset: Int) {
            guard !slice.isEmpty else { return }
            var index = offset
            for row in slice {
                guard index < rows.count else { break }
                rows[index] = row
                index += 1
            }
            if let terminal = terminalCount {
                terminalCount = max(terminal, offset + slice.count)
            }
        }

        mutating func overwrite(with newRows: [[String?]], isTerminal: Bool) {
            var updated = ContiguousArray<[String?]?>(repeating: nil, count: rows.count)
            let limit = min(newRows.count, updated.count)
            for index in 0..<limit {
                updated[index] = newRows[index]
            }
            rows = updated
            terminalCount = isTerminal ? newRows.count : nil
        }

        func row(at offset: Int) -> [String?]? {
            guard offset >= 0 else { return nil }
            if let terminal = terminalCount, offset >= terminal {
                return nil
            }
            guard offset < rows.count else { return nil }
            return rows[offset]
        }

        func contains(offsetRange: Range<Int>) -> Bool {
            guard !offsetRange.isEmpty else { return true }
            if let terminal = terminalCount, offsetRange.upperBound > terminal {
                return false
            }
            let clippedUpper = min(offsetRange.upperBound, rows.count)
            if clippedUpper <= offsetRange.lowerBound { return true }
            for index in offsetRange.lowerBound..<clippedUpper {
                if rows[index] == nil {
                    return false
                }
            }
            return true
        }
    }

    private let pageSize: Int
    private let maxPages: Int
    private let lock = NSLock()
    private var pages: [Int: Page] = [:]
    private var lru: [Int] = []
    private var pending: Set<Int> = []

    init(pageSize: Int = 512, maxPages: Int = 24) {
        self.pageSize = max(pageSize, 1)
        self.maxPages = max(maxPages, 1)
    }

    func reset() {
        lock.lock()
        pages.removeAll(keepingCapacity: false)
        lru.removeAll(keepingCapacity: false)
        pending.removeAll(keepingCapacity: false)
        lock.unlock()
    }

    func ingest(rows: [[String?]], startingAt index: Int) {
        guard !rows.isEmpty, index >= 0 else { return }
        lock.lock()
        defer { lock.unlock() }

        var cursor = 0
        var globalIndex = index

        while cursor < rows.count {
            let pageIndex = globalIndex / pageSize
            let offset = globalIndex % pageSize
            let remainingInPage = pageSize - offset
            let chunkCount = min(remainingInPage, rows.count - cursor)
            let chunk = rows[cursor..<(cursor + chunkCount)]

            var page = pages[pageIndex] ?? Page(pageSize: pageSize)
            page.insert(rows: chunk, startingAt: offset)
            pages[pageIndex] = page
            touchPageLocked(pageIndex)

            cursor += chunkCount
            globalIndex += chunkCount
        }

        trimIfNeededLocked()
    }

    func row(at index: Int) -> [String?]? {
        guard index >= 0 else { return nil }
        lock.lock()
        defer { lock.unlock() }

        let pageIndex = index / pageSize
        let offset = index % pageSize
        guard let page = pages[pageIndex] else { return nil }
        touchPageLocked(pageIndex)
        return page.row(at: offset)
    }

    func prefetch(range: Range<Int>, using handle: ResultSpoolHandle, onPageLoaded: @escaping (Range<Int>) -> Void) {
        guard !range.isEmpty else { return }
        let clampedLower = max(range.lowerBound, 0)
        let clampedUpper = max(range.upperBound, clampedLower + 1)
        let startPage = clampedLower / pageSize
        let endPage = (clampedUpper - 1) / pageSize
        guard startPage <= endPage else { return }

        var targets: [Int] = []

        lock.lock()
        for pageIndex in startPage...endPage {
            let pageStart = pageIndex * pageSize
            let localLower = max(clampedLower, pageStart) - pageStart
            let localUpper = min(clampedUpper, pageStart + pageSize) - pageStart
            let localRange = localLower..<max(localUpper, localLower)
            if localRange.isEmpty {
                continue
            }

            if let page = pages[pageIndex], page.contains(offsetRange: localRange) {
                continue
            }

            if pending.contains(pageIndex) {
                continue
            }

            pending.insert(pageIndex)
            targets.append(pageIndex)
        }
        lock.unlock()

        guard !targets.isEmpty else { return }

        for pageIndex in targets {
            Task(priority: .utility) { [weak self] in
                guard let self else { return }
                do {
                    let offset = pageIndex * self.pageSize
                    let rows = try await handle.loadRows(offset: offset, limit: self.pageSize)
                    let isTerminal = rows.count < self.pageSize
                    self.storeFetchedPage(rows: rows, pageIndex: pageIndex, isTerminal: isTerminal)
                    if !rows.isEmpty {
                        let fetchedRange = offset..<(offset + rows.count)
                        await MainActor.run {
                            onPageLoaded(fetchedRange)
                        }
                    } else {
                        await MainActor.run {
                            onPageLoaded(offset..<offset)
                        }
                    }
                } catch {
                    self.handlePrefetchFailure(pageIndex: pageIndex)
                }
            }
        }
    }

    private func storeFetchedPage(rows: [[String?]], pageIndex: Int, isTerminal: Bool) {
        lock.lock()
        defer { lock.unlock() }

        var page = pages[pageIndex] ?? Page(pageSize: pageSize)
        page.overwrite(with: rows, isTerminal: isTerminal)
        pages[pageIndex] = page
        pending.remove(pageIndex)
        touchPageLocked(pageIndex)
        trimIfNeededLocked()
    }

    private func handlePrefetchFailure(pageIndex: Int) {
        lock.lock()
        pending.remove(pageIndex)
        lock.unlock()
    }

    private func touchPageLocked(_ index: Int) {
        if let existing = lru.firstIndex(of: index) {
            lru.remove(at: existing)
        }
        lru.append(index)
    }

    private func trimIfNeededLocked() {
        guard pages.count > maxPages else { return }
        while pages.count > maxPages {
            guard let oldest = lru.first else { break }
            pages.removeValue(forKey: oldest)
            lru.removeFirst()
        }
    }
}
