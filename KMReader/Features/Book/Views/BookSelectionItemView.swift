//
// BookSelectionItemView.swift
//
//

import SQLiteData
import SwiftUI

/// View for book selection mode that accepts only bookId and reads the local record.
struct BookSelectionItemView: View {
  let bookId: String
  let layout: BrowseLayoutMode
  @Binding var selectedBookIds: Set<String>
  let refreshBooks: () -> Void
  var showSeriesTitle: Bool = true

  @FetchAll private var bookRecords: [KomgaBookRecord]
  @FetchAll private var bookLocalStateList: [KomgaBookLocalStateRecord]

  init(
    bookId: String,
    layout: BrowseLayoutMode,
    selectedBookIds: Binding<Set<String>>,
    refreshBooks: @escaping () -> Void,
    showSeriesTitle: Bool = true
  ) {
    self.bookId = bookId
    self.layout = layout
    self._selectedBookIds = selectedBookIds
    self.refreshBooks = refreshBooks
    self.showSeriesTitle = showSeriesTitle

    let instanceId = AppConfig.current.instanceId
    _bookRecords = FetchAll(
      KomgaBookRecord.where { $0.instanceId.eq(instanceId) && $0.bookId.eq(bookId) }
    )
    _bookLocalStateList = FetchAll(
      KomgaBookLocalStateRecord.where { $0.instanceId.eq(instanceId) && $0.bookId.eq(bookId) }
    )
  }

  private var book: Book? {
    bookRecords.first?.toBook()
  }

  private var downloadStatus: DownloadStatus {
    bookLocalStateList.first?.downloadStatus ?? .notDownloaded
  }

  private var isSelected: Bool {
    selectedBookIds.contains(bookId)
  }

  var body: some View {
    if let book = book {
      Group {
        switch layout {
        case .grid:
          BookCardView(
            book: book,
            downloadStatus: downloadStatus,
            onReadBook: { _ in },
            showSeriesTitle: showSeriesTitle
          )
        case .list:
          BookRowView(
            book: book,
            downloadStatus: downloadStatus,
            onReadBook: { _ in },
            showSeriesTitle: showSeriesTitle
          )
        }
      }
      .allowsHitTesting(false)
      .scaleEffect(isSelected ? 0.96 : 1.0)
      .overlay {
        if isSelected {
          RoundedRectangle(cornerRadius: 12)
            .stroke(Color.accentColor, lineWidth: 2)
        }
      }
      .contentShape(Rectangle())
      .highPriorityGesture(
        TapGesture().onEnded {
          withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if isSelected {
              selectedBookIds.remove(bookId)
            } else {
              selectedBookIds.insert(bookId)
            }
          }
        }
      )
    }
  }
}
