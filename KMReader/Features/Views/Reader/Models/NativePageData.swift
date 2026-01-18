//
//  NativePageData.swift
//  KMReader
//

import SwiftUI

/// Data structure for a single page to be rendered natively
struct NativePageData {
  let bookId: String
  let pageNumber: Int
  let isLoading: Bool
  let error: String?
  let alignment: HorizontalAlignment
}
