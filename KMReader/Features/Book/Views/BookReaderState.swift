//
// BookReaderState.swift
//
//

import Foundation

struct BookReaderState: Equatable {
  var book: Book?
  var incognito: Bool = false
  var readList: ReadList?
}
