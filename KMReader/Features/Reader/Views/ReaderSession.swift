//
// ReaderSession.swift
//
//

import Foundation

struct ReaderSession: Equatable, Identifiable {
  let id: UUID
  var book: Book
  var incognito: Bool
  var readListContext: ReaderReadListContext?
  var sourceBookId: String
  var visitedBookIds: Set<String> = []
  var visitedSeriesIds: Set<String> = []
  var handoffTitle: String = ""
  var handoffURL: URL?

  init(
    id: UUID = UUID(),
    book: Book,
    incognito: Bool,
    readListContext: ReaderReadListContext?,
    sourceBookId: String? = nil
  ) {
    self.id = id
    self.book = book
    self.incognito = incognito
    self.readListContext = readListContext
    self.sourceBookId = sourceBookId ?? book.id
  }
}
