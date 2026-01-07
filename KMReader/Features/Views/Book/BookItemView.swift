//
//  BookItemView.swift
//  KMReader
//
//  Created by Komga iOS Client
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
      .focusPadding()
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
