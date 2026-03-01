//
// ReaderViewItem.swift
//
//

import Foundation

enum ReaderViewItem: Hashable {
  case page(id: ReaderPageID)
  case split(id: ReaderPageID, part: ReaderSplitPart)
  case dual(first: ReaderPageID, second: ReaderPageID)
  case end(id: ReaderPageID)
}

extension ReaderViewItem {
  var isEnd: Bool {
    if case .end = self { return true }
    return false
  }

  var pageID: ReaderPageID {
    switch self {
    case .page(let id):
      return id
    case .split(let id, _):
      return id
    case .dual(let first, _):
      return first
    case .end(let id):
      return id
    }
  }

  var pagePairIDs: (first: ReaderPageID, second: ReaderPageID?)? {
    switch self {
    case .page(let id):
      return (first: id, second: nil)
    case .split(let id, _):
      return (first: id, second: nil)
    case .dual(let firstID, let secondID):
      return (first: firstID, second: secondID)
    case .end:
      return nil
    }
  }
}
