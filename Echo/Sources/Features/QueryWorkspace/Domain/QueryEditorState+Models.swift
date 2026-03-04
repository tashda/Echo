import Foundation
import SwiftUI

extension QueryEditorState {
    enum StreamingMode: Equatable {
        case idle
        case preview
        case background
        case completed
    }

    struct BroadcastSnapshot: Equatable {
        var rowCount: Int
        var streamingRowsCount: Int
        var visibleLimit: Int?
        var streamingMode: StreamingMode
        var columnCount: Int
    }

    struct BufferedSpoolUpdate {
        let update: QueryStreamUpdate
        let treatAsPreview: Bool
    }

    struct DataPreviewState {
        let batchSize: Int
        let fetcher: DataPreviewFetcher
        var nextOffset: Int
        var hasMoreData: Bool
        var isFetching: Bool
    }

    struct ForeignKeyResolutionContext {
        let schema: String
        let table: String
    }

    func updateClipboardContext(serverName: String?,
                                databaseName: String?,
                                connectionColorHex: String?) {
        clipboardMetadata = ClipboardHistoryStore.Entry.Metadata(
            serverName: serverName ?? "Unknown Server",
            databaseName: databaseName,
            objectName: clipboardMetadata.objectName,
            connectionColorHex: connectionColorHex
        )
    }

    func updateClipboardObjectName(_ objectName: String?) {
        clipboardMetadata = ClipboardHistoryStore.Entry.Metadata(
            serverName: clipboardMetadata.serverName,
            databaseName: clipboardMetadata.databaseName,
            objectName: objectName,
            connectionColorHex: clipboardMetadata.connectionColorHex
        )
    }
}
