//
// BookItemView.swift
//
//

import SwiftUI

struct BookItemView: View {
  let book: Book
  let downloadStatus: DownloadStatus
  let layout: BrowseLayoutMode
  let onReadBook: (Bool) -> Void
  var showSeriesTitle: Bool = true
  var showSeriesNavigation: Bool = true

  var body: some View {
    switch layout {
    case .grid:
      BookCardView(
        book: book,
        downloadStatus: downloadStatus,
        onReadBook: onReadBook,
        showSeriesTitle: showSeriesTitle,
        showSeriesNavigation: showSeriesNavigation
      )
    case .list:
      BookRowView(
        book: book,
        downloadStatus: downloadStatus,
        onReadBook: onReadBook,
        showSeriesTitle: showSeriesTitle,
        showSeriesNavigation: showSeriesNavigation
      )
    }
  }
}
