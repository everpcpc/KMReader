//
// ReaderViewItem.swift
//
//

import Foundation

enum ReaderViewItem: Hashable {
  case page(id: ReaderPageID)
  case split(id: ReaderPageID, part: ReaderSplitPart)
  case dual(first: ReaderPageID, second: ReaderPageID)
  case end(bookId: String)
}

extension ReaderViewItem {
  var isEnd: Bool {
    if case .end = self { return true }
    return false
  }

  var primaryPageID: ReaderPageID? {
    switch self {
    case .page(let id):
      return id
    case .split(let id, _):
      return id
    case .dual(let first, _):
      return first
    case .end:
      return nil
    }
  }
}
