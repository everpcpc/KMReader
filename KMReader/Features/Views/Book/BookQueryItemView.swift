//
//  BookQueryItemView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

/// Wrapper view that accepts only bookId and uses @Query to fetch the book reactively.
struct BookQueryItemView: View {
  let bookId: String
  let layout: BrowseLayoutMode
  var showSeriesTitle: Bool = true
  var showSeriesNavigation: Bool = true

  @AppStorage("currentInstanceId") private var currentInstanceId: String = ""
  @Environment(ReaderPresentationManager.self) private var readerPresentation
  @Query private var komgaBooks: [KomgaBook]

  init(
    bookId: String,
    layout: BrowseLayoutMode,
    showSeriesTitle: Bool = true,
    showSeriesNavigation: Bool = true
  ) {
    self.bookId = bookId
    self.layout = layout
    self.showSeriesTitle = showSeriesTitle
    self.showSeriesNavigation = showSeriesNavigation

    let instanceId = AppConfig.currentInstanceId
    let compositeId = "\(instanceId)_\(bookId)"
    _komgaBooks = Query(filter: #Predicate<KomgaBook> { $0.id == compositeId })
  }

  private var komgaBook: KomgaBook? {
    komgaBooks.first
  }

  var body: some View {
    if let book = komgaBook {
      switch layout {
      case .grid:
        BookCardView(
          komgaBook: book,
          onReadBook: { incognito in
            readerPresentation.present(book: book.toBook(), incognito: incognito)
          },
          showSeriesTitle: showSeriesTitle,
          showSeriesNavigation: showSeriesNavigation
        )
        .focusPadding()
      case .list:
        BookRowView(
          komgaBook: book,
          onReadBook: { incognito in
            readerPresentation.present(book: book.toBook(), incognito: incognito)
          },
          showSeriesTitle: showSeriesTitle,
          showSeriesNavigation: showSeriesNavigation
        )
      }
    } else {
      CardPlaceholder(layout: layout)
        .focusPadding()
    }
  }
}
