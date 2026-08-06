//
// NativePageData.swift
//
//

import SwiftUI

/// Split mode for wide pages
enum PageSplitMode: Hashable {
  case none
  case leftHalf
  case rightHalf
}

/// Data structure for a single page to be rendered natively
struct NativePageData {
  let pageID: ReaderPageID
  let isLoading: Bool
  let error: String?
  let alignment: HorizontalAlignment
  let splitMode: PageSplitMode
  let rotation: ReaderRotation
  let animatedSourceFileURL: URL?

  init(
    pageID: ReaderPageID,
    isLoading: Bool,
    error: String?,
    alignment: HorizontalAlignment,
    splitMode: PageSplitMode = .none,
    rotation: ReaderRotation = .none,
    animatedSourceFileURL: URL? = nil
  ) {
    self.pageID = pageID
    self.isLoading = isLoading
    self.error = error
    self.alignment = alignment
    self.splitMode = splitMode
    self.rotation = rotation
    self.animatedSourceFileURL = animatedSourceFileURL
  }
}
