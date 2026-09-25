//
// ReaderActions+ReadListContinuation.swift
//
//

import Foundation

extension ReaderActions {
  /// Opens the book a read list continues with, in the read list's order.
  func open(continuation: ReadListContinuation) {
    let readListContext = ReaderReadListContext(
      id: continuation.readListId,
      name: continuation.readListName
    )
    Task {
      guard let database = await DatabaseOperator.databaseIfConfigured(),
        let book = await database.fetchBook(id: continuation.bookId)
      else { return }
      open(book: book, incognito: false, readListContext: readListContext)
    }
  }
}
