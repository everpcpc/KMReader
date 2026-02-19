//
// PaginationState.swift
//
//

import Foundation

struct PaginationState<Item: Identifiable & Equatable> {
  let pageSize: Int
  var currentPage: Int = 0
  var hasMorePages: Bool = true
  var loadID: UUID = UUID()
  var items: [Item] = []

  init(pageSize: Int, items: [Item] = []) {
    self.pageSize = pageSize
    self.items = items
  }

  mutating func reset() {
    currentPage = 0
    hasMorePages = true
    loadID = UUID()
  }

  mutating func advance(moreAvailable: Bool) {
    hasMorePages = moreAvailable
    currentPage += 1
  }

  var isEmpty: Bool {
    items.isEmpty
  }

  func isLast(_ item: Item) -> Bool {
    items.last == item
  }

  func shouldLoadMore(after item: Item, threshold: Int = 3) -> Bool {
    guard threshold > 0 else { return isLast(item) }
    return items.suffix(threshold).contains(item)
  }

  mutating func applyPage(_ newItems: [Item]) -> Bool {
    if currentPage == 0 {
      guard newItems != items else { return false }
      items = newItems
    } else {
      guard newItems.isEmpty == false else { return false }
      items.append(contentsOf: newItems)
    }
    return true
  }
}
