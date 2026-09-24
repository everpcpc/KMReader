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
  /// One entry per read list that currently surfaces on the dashboard, most
  /// recently read first.
  let continuations: [ReadListContinuation]
  /// Every book of a surfaced read list, mapped to that read list's id. A book
  /// in several surfaced read lists belongs to the most recently read one.
  let ownerReadListIdByBookId: [String: String]

  static let empty = ReadListReadingSnapshot(continuations: [], ownerReadListIdByBookId: [:])

  func continuation(forReadListId readListId: String) -> ReadListContinuation? {
    continuations.first { $0.readListId == readListId }
  }

  /// Folds the read lists being read into one page of On Deck, so a read list
  /// resumes across series the way a series resumes across its books.
  ///
  /// A read list whose next book is unread puts it first; a series suggestion
  /// for a book owned by a visible read list is dropped, because that read list
  /// surfaces its own next book (in On Deck, or in Keep Reading while it is in
  /// progress) — one reading thread shows up once. The library scope hides
  /// entries without changing which book a read list resolves to, and a read
  /// list it hides does not hide its series either. Later pages only filter,
  /// since pages are appended as they load.
  func mergingOnDeck(_ ids: [String], libraryIds: [String], isFirstPage: Bool) -> [String] {
    let librarySelection = Set(libraryIds)
    let visible = continuations.filter {
      librarySelection.isEmpty || librarySelection.contains($0.libraryId)
    }
    let visibleReadListIds = Set(visible.map(\.readListId))
    let readListBookIds = visible.filter { $0.placement == .onDeck }.map(\.bookId)
    let placed = Set(readListBookIds)

    let seriesIds = ids.filter { bookId in
      guard !placed.contains(bookId) else { return false }
      guard let owner = ownerReadListIdByBookId[bookId] else { return true }
      return !visibleReadListIds.contains(owner)
    }
    return isFirstPage ? readListBookIds + seriesIds : seriesIds
  }
}
