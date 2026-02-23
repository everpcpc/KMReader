//
// ReaderPageID.swift
//
//

import Foundation

struct ReaderPageID: Hashable, Codable, Sendable, CustomStringConvertible {
  let bookId: String
  let pageNumber: Int

  var description: String {
    "\(bookId)#\(pageNumber)"
  }
}
