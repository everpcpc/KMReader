//
//  BookItemView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftUI

struct BookItemView: View {
  @Bindable var book: KomgaBook
  let cardWidth: CGFloat
  let layout: BrowseLayoutMode
  let onReadBook: (Bool) -> Void
  let onBookUpdated: (() -> Void)?
  var showSeriesTitle: Bool = true
  var showSeriesNavigation: Bool = true

  var body: some View {
    switch layout {
    case .grid:
      BookCardView(
        komgaBook: book,
        cardWidth: cardWidth,
        onReadBook: onReadBook,
        onBookUpdated: onBookUpdated,
        showSeriesTitle: showSeriesTitle,
        showSeriesNavigation: showSeriesNavigation
      )
      .focusPadding()
    case .list:
      BookRowView(
        komgaBook: book,
        onReadBook: onReadBook,
        onBookUpdated: onBookUpdated,
        showSeriesTitle: showSeriesTitle,
        showSeriesNavigation: showSeriesNavigation
      )
    }
  }
}
