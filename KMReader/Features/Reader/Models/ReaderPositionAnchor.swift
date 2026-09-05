//
// ReaderPositionAnchor.swift
//

import Foundation

struct ReaderPositionAnchor: Equatable {
  let item: ReaderViewItem?
  let focusedPageID: ReaderPageID?
  /// Split side to prefer when `item` no longer resolves exactly after a
  /// rebuild, e.g. a wide page merged into `.both` across a rotation. Carried
  /// with the anchor so adapters resolve against the same committed side;
  /// never `.both`.
  let preferredSplitPart: ReaderSplitPart?

  init(
    item: ReaderViewItem?,
    focusedPageID: ReaderPageID?,
    preferredSplitPart: ReaderSplitPart? = nil
  ) {
    self.item = item
    self.focusedPageID = focusedPageID
    self.preferredSplitPart = preferredSplitPart
  }
}
