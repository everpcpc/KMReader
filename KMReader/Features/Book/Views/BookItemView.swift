//
//  BookItemView.swift
//  KMReader
//
//

import SwiftUI

struct BookItemView: View {
  @Bindable var book: KomgaBook
  let layout: BrowseLayoutMode
  let onReadBook: (Bool) -> Void
  var showSeriesTitle: Bool = true
  var showSeriesNavigation: Bool = true

  var body: some View {
    switch layout {
    case .grid:
      BookCardView(
        komgaBook: book,
        onReadBook: onReadBook,
        showSeriesTitle: showSeriesTitle,
        showSeriesNavigation: showSeriesNavigation
      )
    case .list:
      BookRowView(
        komgaBook: book,
        onReadBook: onReadBook,
        showSeriesTitle: showSeriesTitle,
        showSeriesNavigation: showSeriesNavigation
      )
    }
  }
}
