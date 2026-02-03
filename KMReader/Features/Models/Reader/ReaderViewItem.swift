//
//  ReaderViewItem.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation

enum ReaderViewItem: Hashable {
  case page(index: Int)
  case split(index: Int, isFirstHalf: Bool)
  case dual(first: Int, second: Int)
  case end
}

extension ReaderViewItem {
  var isEnd: Bool {
    if case .end = self {
      return true
    }
    return false
  }

  var primaryPageIndex: Int? {
    switch self {
    case .page(let index):
      return index
    case .split(let index, _):
      return index
    case .dual(let first, _):
      return first
    case .end:
      return nil
    }
  }

  var secondaryPageIndex: Int? {
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
