//
//  NativePageData.swift
//  KMReader
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
  let bookId: String
  let pageNumber: Int
  let isLoading: Bool
  let error: String?
  let alignment: HorizontalAlignment
  let splitMode: PageSplitMode

  init(
    bookId: String,
    pageNumber: Int,
    isLoading: Bool,
    error: String?,
    alignment: HorizontalAlignment,
    splitMode: PageSplitMode = .none
  ) {
    self.bookId = bookId
    self.pageNumber = pageNumber
    self.isLoading = isLoading
    self.error = error
    self.alignment = alignment
    self.splitMode = splitMode
  }
}
