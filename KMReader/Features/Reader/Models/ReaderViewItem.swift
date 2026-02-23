//
// ReaderViewItem.swift
//
//

import Foundation

enum ReaderViewItem: Hashable {
  case page(id: ReaderPageID)
  case split(id: ReaderPageID, isFirstHalf: Bool)
  case dual(first: ReaderPageID, second: ReaderPageID)
  case end
}

extension ReaderViewItem {
  var isEnd: Bool {
    if case .end = self {
      return true
    }
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

  var secondaryPageID: ReaderPageID? {
    switch self {
    case .dual(_, let second):
      return second
    default:
      return nil
    }
  }

  var isFirstHalf: Bool? {
    if case .split(_, let isFirstHalf) = self {
      return isFirstHalf
    }
    return nil
  }
}
