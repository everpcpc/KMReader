//
// ReadListReadingState.swift
//
//

import Foundation
import GRDB

/// A read list the user is reading through, and the last book read in it.
///
/// This is user reading state, deliberately kept apart from `KomgaReadList` (a
/// mirror of the server's read list): it syncs across the user's devices through
/// Komga's per-user client settings, so a device can learn about a read list it
/// has not synced yet.
nonisolated struct ReadListReadingState: Codable, Equatable, FetchableRecord, PersistableRecord, Sendable {
  static let databaseTableName = "read_list_reading_states"

  let instanceId: String
  let readListId: String
  var lastReadBookId: String
  var lastReadAt: Date
  /// A local change the server's client settings have not confirmed yet.
  var needsUpload: Bool
  /// Set by "Stop reading". The row stays as a tombstone until the server key is
  /// deleted, so a stop made offline is not undone by the next pull.
  var isStopped: Bool

  enum CodingKeys: String, CodingKey {
    case instanceId = "instance_id"
    case readListId = "read_list_id"
    case lastReadBookId = "last_read_book_id"
    case lastReadAt = "last_read_at"
    case needsUpload = "needs_upload"
    case isStopped = "is_stopped"
  }
}
