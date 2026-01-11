//
//  BookSelectionItemView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

/// View for book selection mode that accepts only bookId and uses @Query to fetch the book.
struct BookSelectionItemView: View {
  let bookId: String
  let layout: BrowseLayoutMode
  @Binding var selectedBookIds: Set<String>
  let refreshBooks: () -> Void
  var showSeriesTitle: Bool = true

  @Query private var komgaBooks: [KomgaBook]

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
    let compositeId = CompositeID.generate(instanceId: instanceId, id: bookId)
    _komgaBooks = Query(filter: #Predicate<KomgaBook> { $0.id == compositeId })
  }

  private var komgaBook: KomgaBook? {
    komgaBooks.first
  }

  private var isSelected: Bool {
    selectedBookIds.contains(bookId)
  }

  var body: some View {
    if let book = komgaBook {
      Group {
        switch layout {
        case .grid:
          BookCardView(
            komgaBook: book,
            onReadBook: { _ in },
            showSeriesTitle: showSeriesTitle
          )
          .focusPadding()
        case .list:
          BookRowView(
            komgaBook: book,
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
