//
// ReaderPage.swift
//
//

import Foundation

struct ReaderPage: Identifiable, Sendable {
  let id: ReaderPageID
  let page: BookPage

  init(bookId: String, page: BookPage) {
    self.id = ReaderPageID(bookId: bookId, pageNumber: page.number)
    self.page = page
  }

  var bookId: String { id.bookId }
  var pageNumber: Int { id.pageNumber }
}
