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

  @Environment(ReaderPresentationManager.self) private var readerPresentation
  @FetchAll private var bookRecords: [KomgaBookRecord]
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
    _bookRecords = FetchAll(
      KomgaBookRecord.where { $0.instanceId.eq(instanceId) && $0.bookId.eq(bookId) }.limit(1)
    )
    _bookLocalStateList = FetchAll(
      KomgaBookLocalStateRecord.where { $0.instanceId.eq(instanceId) && $0.bookId.eq(bookId) }.limit(1)
    )
  }

  private var book: Book? {
    bookRecords.first?.toBook()
  }

  private var downloadStatus: DownloadStatus {
    bookLocalStateList.first?.downloadStatus ?? .notDownloaded
  }

  var body: some View {
    if let book = book {
      switch layout {
      case .grid:
        BookCardView(
          book: book,
          downloadStatus: downloadStatus,
          onReadBook: { incognito in
            readerPresentation.present(
              book: book,
              incognito: incognito,
              readListContext: readListContext
            )
          },
          showSeriesTitle: showSeriesTitle,
          showSeriesNavigation: showSeriesNavigation
        )
      case .list:
        BookRowView(
          book: book,
          downloadStatus: downloadStatus,
          onReadBook: { incognito in
            readerPresentation.present(
              book: book,
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
