//
// ReadListReadingSnapshot.swift
//
//

import Foundation

/// Everything derived from the read lists the user is currently reading.
///
/// Carries plain identifiers only, so it can be built on the database actor;
/// `ReaderReadListContext` values are created on the main actor from it.
nonisolated struct ReadListReadingSnapshot: Equatable, Sendable {
  /// One entry per read list with a book to continue with, most recently read
  /// first.
  let continuations: [ReadListContinuation]
  /// Every book of those read lists, mapped to its read list's id. A book in
  /// several of them belongs to the most recently read one.
  let ownerReadListIdByBookId: [String: String]

  static let empty = ReadListReadingSnapshot(continuations: [], ownerReadListIdByBookId: [:])

  func continuation(forReadListId readListId: String) -> ReadListContinuation? {
    continuations.first { $0.readListId == readListId }
  }
}
