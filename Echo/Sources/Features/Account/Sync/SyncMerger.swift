import Foundation

/// Performs field-level last-writer-wins merge between local and remote
/// sync documents using HLC timestamps.
///
/// Rules:
/// - For each field, the version with the higher HLC wins.
/// - If HLCs are equal, the remote version wins (server is tiebreaker).
/// - New fields from either side are always included.
/// - Deletion is a field-level operation: if a delete has a higher HLC
///   than an edit, the document stays deleted. If an edit has a higher
///   HLC than the delete, the document is resurrected (data preservation).
struct SyncMerger: Sendable {

    /// Merge a remote document into a local document.
    ///
    /// Returns the merged document that should replace the local copy,
    /// and a flag indicating whether the local document was changed.
    func merge(local: SyncDocument, remote: SyncDocument) -> (merged: SyncDocument, changed: Bool) {
        precondition(local.id == remote.id, "Cannot merge documents with different IDs")
        precondition(local.collection == remote.collection, "Cannot merge documents from different collections")

        var merged = local
        var changed = false

        // Merge fields
        for (key, remoteField) in remote.fields {
            if let localField = local.fields[key] {
                if remoteField.hlc > localField.hlc {
                    merged.fields[key] = remoteField
                    changed = true
                } else if remoteField.hlc == localField.hlc && remoteField.value != localField.value {
                    // Equal HLC — remote wins as tiebreaker
                    merged.fields[key] = remoteField
                    changed = true
                }
                // else: local wins (keep as-is)
            } else {
                // New field from remote
                merged.fields[key] = remoteField
                changed = true
            }
        }

        // Handle deletion state
        if remote.isDeleted && !local.isDeleted {
            merged.isDeleted = true
            merged.deletedAt = remote.deletedAt
            changed = true
        } else if !remote.isDeleted && local.isDeleted {
            // Remote has edits after local deleted — resurrect
            let remoteMaxHLC = remote.fields.values.map(\.hlc).max() ?? 0
            let localDeleteHLC = local.fields.values.map(\.hlc).max() ?? 0
            if remoteMaxHLC > localDeleteHLC {
                merged.isDeleted = false
                merged.deletedAt = nil
                changed = true
            }
        }

        return (merged, changed)
    }

    /// Merge an array of remote documents into local state.
    ///
    /// Returns documents that were changed locally (need to be persisted),
    /// and documents that are new (not present locally).
    func mergeAll(
        local: [UUID: SyncDocument],
        remote: [SyncDocument]
    ) -> (changed: [SyncDocument], new: [SyncDocument]) {
        var changedDocs: [SyncDocument] = []
        var newDocs: [SyncDocument] = []

        for remoteDoc in remote {
            if let localDoc = local[remoteDoc.id] {
                let (merged, changed) = merge(local: localDoc, remote: remoteDoc)
                if changed {
                    changedDocs.append(merged)
                }
            } else {
                newDocs.append(remoteDoc)
            }
        }

        return (changedDocs, newDocs)
    }
}
