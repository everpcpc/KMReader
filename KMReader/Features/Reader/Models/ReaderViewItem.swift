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

  var pageIDs: [ReaderPageID] {
    switch self {
    case .page(let id):
      return [id]
    case .split(let id, _):
      return [id]
    case .dual(let firstID, let secondID):
      return [firstID, secondID]
    case .end:
      return []
    }
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

  /// Split side to prefer when this item is re-resolved after a rebuild, given
  /// the previously committed position. A non-merged split item speaks for
  /// itself; otherwise the anchor's preference is kept only while it still
  /// points at a page contained in this item.
  func preferredSplitPart(preserving anchor: ReaderPositionAnchor?) -> ReaderSplitPart? {
    if case .split(_, let part) = self, part != .both { return part }
    guard let anchor, let part = anchor.preferredSplitPart else { return nil }
    let pageID = anchor.focusedPageID ?? anchor.item?.pageID
    guard let pageID, pageIDs.contains(pageID) else { return nil }
    return part
  }
}
