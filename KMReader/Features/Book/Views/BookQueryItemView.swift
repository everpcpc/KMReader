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
  let prefetchedBook: KomgaBook?
  var showSeriesTitle: Bool = true
  var showSeriesNavigation: Bool = true

  @AppStorage("currentAccount") private var current: Current = .init()
  @Environment(ReaderPresentationManager.self) private var readerPresentation
  @Query private var komgaBooks: [KomgaBook]

  init(
    bookId: String,
    layout: BrowseLayoutMode,
    komgaBook: KomgaBook? = nil,
    showSeriesTitle: Bool = true,
    showSeriesNavigation: Bool = true
  ) {
    self.bookId = bookId
    self.layout = layout
    self.prefetchedBook = komgaBook
    self.showSeriesTitle = showSeriesTitle
    self.showSeriesNavigation = showSeriesNavigation

    if komgaBook == nil {
      let compositeId = CompositeID.generate(id: bookId)
      _komgaBooks = Query(filter: #Predicate<KomgaBook> { $0.id == compositeId })
    } else {
      _komgaBooks = Query(filter: #Predicate<KomgaBook> { _ in false })
    }
  }

  private var komgaBook: KomgaBook? {
    prefetchedBook ?? komgaBooks.first
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
      CardPlaceholder(layout: layout, kind: .book)
    }
  }
}
