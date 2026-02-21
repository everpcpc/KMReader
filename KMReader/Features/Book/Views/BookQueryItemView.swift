//
// BookQueryItemView.swift
//
//

import SQLiteData
import SwiftUI

/// Wrapper view that accepts only bookId and fetches the local record reactively.
struct BookQueryItemView: View {
  let bookId: String
  let layout: BrowseLayoutMode
  var showSeriesTitle: Bool = true
  var showSeriesNavigation: Bool = true
  var readListContext: ReaderReadListContext? = nil

  @AppStorage("currentAccount") private var current: Current = .init()
  @Environment(ReaderPresentationManager.self) private var readerPresentation
  @FetchAll private var komgaBooks: [KomgaBookRecord]
  @FetchAll private var bookLocalStateList: [KomgaBookLocalStateRecord]

  init(
    bookId: String,
    layout: BrowseLayoutMode,
    showSeriesTitle: Bool = true,
    showSeriesNavigation: Bool = true,
    readListContext: ReaderReadListContext? = nil
  ) {
    self.bookId = bookId
    self.layout = layout
    self.showSeriesTitle = showSeriesTitle
    self.showSeriesNavigation = showSeriesNavigation
    self.readListContext = readListContext

    let instanceId = AppConfig.current.instanceId
    _komgaBooks = FetchAll(
      KomgaBookRecord.where { $0.instanceId.eq(instanceId) && $0.bookId.eq(bookId) }
    )
    _bookLocalStateList = FetchAll(
      KomgaBookLocalStateRecord.where { $0.instanceId.eq(instanceId) && $0.bookId.eq(bookId) }
    )
  }

  private var komgaBook: KomgaBook? {
    komgaBooks.first?.toKomgaBook(localState: bookLocalStateList.first)
  }

  var body: some View {
    if let book = komgaBook {
      switch layout {
      case .grid:
        BookCardView(
          komgaBook: book,
          onReadBook: { incognito in
            readerPresentation.present(
              book: book.toBook(),
              incognito: incognito,
              readListContext: readListContext
            )
          },
          showSeriesTitle: showSeriesTitle,
          showSeriesNavigation: showSeriesNavigation
        )
      case .list:
        BookRowView(
          komgaBook: book,
          onReadBook: { incognito in
            readerPresentation.present(
              book: book.toBook(),
              incognito: incognito,
              readListContext: readListContext
            )
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
