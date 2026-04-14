import XCTest
@testable import Echo

/// Thread-safe accumulator for collecting stream updates in tests.
private final class UpdateCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var _updates: [QueryStreamUpdate] = []

    func append(_ update: QueryStreamUpdate) {
        lock.lock()
        _updates.append(update)
        lock.unlock()
    }

    var updates: [QueryStreamUpdate] {
        lock.lock()
        defer { lock.unlock() }
        return _updates
    }

    var maxRowCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _updates.map(\.totalRowCount).max() ?? 0
    }

    var last: QueryStreamUpdate? {
        lock.lock()
        defer { lock.unlock() }
        return _updates.last
    }
}

final class ResultStreamBatchWorkerTests: XCTestCase {

    private let testColumns = [
        ColumnInfo(name: "id", dataType: "int"),
        ColumnInfo(name: "name", dataType: "text"),
        ColumnInfo(name: "value", dataType: "text")
    ]

    // MARK: - String Values Storage

    func testStringValuesStorageEncodesCorrectly() async {
        let expectation = XCTestExpectation(description: "Progress handler called")
        let collector = UpdateCollector()

        let worker = ResultStreamBatchWorker(
            label: "test.stringValues",
            columns: testColumns,
            streamingPreviewLimit: 200,
            maxFlushLatency: 0.015,
            operationStart: CFAbsoluteTimeGetCurrent(),
            progressHandler: { update in
                collector.append(update)
                if update.totalRowCount >= 3 {
                    expectation.fulfill()
                }
            }
        )

        let payloads = [
            ResultStreamBatchWorker.Payload(
                previewValues: ["1", "Alice", "100"],
                storage: .stringValues(["1", "Alice", "100"]),
                totalRowCount: 1,
                decodeDuration: 0
            ),
            ResultStreamBatchWorker.Payload(
                previewValues: ["2", "Bob", nil],
                storage: .stringValues(["2", "Bob", nil]),
                totalRowCount: 2,
                decodeDuration: 0
            ),
            ResultStreamBatchWorker.Payload(
                previewValues: ["3", "Charlie", "300"],
                storage: .stringValues(["3", "Charlie", "300"]),
                totalRowCount: 3,
                decodeDuration: 0
            ),
        ]

        worker.enqueueBatch(payloads)
        worker.finish(totalRowCount: 3)

        await fulfillment(of: [expectation], timeout: 5.0)

        XCTAssertFalse(collector.updates.isEmpty, "Should receive at least one progress update")
        XCTAssertEqual(collector.last?.totalRowCount, 3)
    }

    // MARK: - Batch Enqueue Flushes

    func testBatchEnqueueFlushesCorrectly() async {
        let expectation = XCTestExpectation(description: "Large batch flushed")
        let collector = UpdateCollector()

        let worker = ResultStreamBatchWorker(
            label: "test.batchFlush",
            columns: testColumns,
            streamingPreviewLimit: 50,
            maxFlushLatency: 0.015,
            operationStart: CFAbsoluteTimeGetCurrent(),
            progressHandler: { update in
                collector.append(update)
                if update.totalRowCount >= 512 {
                    expectation.fulfill()
                }
            }
        )

        var payloads: [ResultStreamBatchWorker.Payload] = []
        for i in 1...512 {
            let isPreview = i <= 50
            payloads.append(ResultStreamBatchWorker.Payload(
                previewValues: isPreview ? ["\(i)", "name\(i)", "val\(i)"] : nil,
                storage: .stringValues(["\(i)", "name\(i)", "val\(i)"]),
                totalRowCount: i,
                decodeDuration: 0
            ))
        }

        worker.enqueueBatch(payloads)
        worker.finish(totalRowCount: 512)

        await fulfillment(of: [expectation], timeout: 5.0)

        XCTAssertEqual(collector.maxRowCount, 512, "Should have received update with all 512 rows")
    }

    // MARK: - Single Payload

    func testSinglePayloadFlushesOnFinish() async {
        let expectation = XCTestExpectation(description: "Single payload flushed")
        let collector = UpdateCollector()

        let worker = ResultStreamBatchWorker(
            label: "test.single",
            columns: [ColumnInfo(name: "val", dataType: "int")],
            streamingPreviewLimit: 200,
            maxFlushLatency: 0.015,
            operationStart: CFAbsoluteTimeGetCurrent(),
            progressHandler: { update in
                collector.append(update)
                expectation.fulfill()
            }
        )

        worker.enqueue(ResultStreamBatchWorker.Payload(
            previewValues: ["42"],
            storage: .stringValues(["42"]),
            totalRowCount: 1,
            decodeDuration: 0
        ))
        worker.finish(totalRowCount: 1)

        await fulfillment(of: [expectation], timeout: 5.0)

        let last = collector.last
        XCTAssertNotNil(last)
        XCTAssertEqual(last?.totalRowCount, 1)
        XCTAssertEqual(last?.columns.first?.name, "val")
    }
}
