//
// ReaderSegment.swift
//
//

import Foundation

struct ReaderSegment {
  let previousBook: Book?
  let currentBook: Book
  let nextBook: Book?
  let pages: [BookPage]
}
