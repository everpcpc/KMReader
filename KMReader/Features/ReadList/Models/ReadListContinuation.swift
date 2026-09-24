//
// ReadListContinuation.swift
//
//

import Foundation

/// A read list the user is reading, resolved to the one book that represents it
/// on the dashboard.
///
/// Placement mirrors Komga's split for series (`GET /api/v1/books/ondeck`:
/// "first unread book of series with at least one book read and no books in
/// progress"): a book in progress belongs in Keep Reading, otherwise the next
/// unread book is On Deck.
nonisolated struct ReadListContinuation: Equatable, Sendable {
  enum Placement: Equatable, Sendable {
    case keepReading
    case onDeck
  }

  let readListId: String
  let readListName: String
  let bookId: String
  /// Library of `bookId`, so the dashboard's library scope can hide the entry
  /// without changing which book the read list resolves to.
  let libraryId: String
  let placement: Placement
  let lastReadAt: Date
}
