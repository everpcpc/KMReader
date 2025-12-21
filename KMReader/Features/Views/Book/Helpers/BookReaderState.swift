//
//  BookReaderState.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

struct BookReaderState: Equatable {
  var book: Book?
  var incognito: Bool = false
  var readList: ReadList?
}
