//
// NativePageData.swift
//
//

import SwiftUI

/// Split mode for wide pages
enum PageSplitMode {
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

  init(
    pageID: ReaderPageID,
    isLoading: Bool,
    error: String?,
    alignment: HorizontalAlignment,
    splitMode: PageSplitMode = .none
  ) {
    self.pageID = pageID
    self.isLoading = isLoading
    self.error = error
    self.alignment = alignment
    self.splitMode = splitMode
  }
}
