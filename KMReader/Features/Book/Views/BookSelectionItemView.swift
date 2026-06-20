//
// BookSelectionItemView.swift
//
//

import SwiftUI

/// View for book selection mode that accepts only bookId and fetches a book display projection.
struct BookSelectionItemView: View {
  let bookId: String
  let layout: BrowseLayoutMode
  @Binding var selectedBookIds: Set<String>
  let refreshBooks: () -> Void
  var showSeriesTitle: Bool = true

  @AppStorage("currentAccount") private var current: Current = .init()
  @State private var item: BookDisplayItem?

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

  }

  private var isSelected: Bool {
    selectedBookIds.contains(bookId)
  }

  var body: some View {
    Group {
      if let item {
        Group {
          switch layout {
          case .grid:
            BookCardView(
              item: item,
              onReadBook: { _ in },
              showSeriesTitle: showSeriesTitle
            )
          case .list:
            BookRowView(
              item: item,
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
        .animation(.default, value: isSelected)
        .contentShape(Rectangle())
        .highPriorityGesture(
          TapGesture().onEnded {
            if isSelected {
              selectedBookIds.remove(bookId)
            } else {
              selectedBookIds.insert(bookId)
            }
          }
        )
      }
    }
    .task(id: "\(current.instanceId)|\(bookId)") {
      await loadItem()
    }
  }

  private func loadItem() async {
    guard let database = try? await DatabaseOperator.database() else {
      item = nil
      return
    }
    item = try? await database.fetchBookDisplayItem(
      bookId: bookId,
      instanceId: current.instanceId
    )
  }
}
