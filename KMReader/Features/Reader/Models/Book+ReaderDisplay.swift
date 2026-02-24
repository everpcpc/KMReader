//
// Book+ReaderDisplay.swift
//

import Foundation

extension Book {
  var readerChapterTitle: String {
    if oneshot {
      return metadata.title
    }
    return "#\(metadata.number) - \(metadata.title)"
  }

  var readerChapterDetail: String {
    "\(media.pagesCount) pages • \(size)"
  }
}
