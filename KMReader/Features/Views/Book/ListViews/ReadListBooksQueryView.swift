//
//  ReadListBooksQueryView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct ReadListBooksQueryView: View {
  let readListId: String
  let bookIds: [String]
  let bookViewModel: BookViewModel
  let onReadBook: (Book, Bool) -> Void
  let layoutHelper: BrowseLayoutHelper
  let browseLayout: BrowseLayoutMode
  let isSelectionMode: Bool
  @Binding var selectedBookIds: Set<String>
  let isAdmin: Bool
  let refreshBooks: () -> Void
  let loadMore: (Bool) async -> Void

  var body: some View {
    Group {
      if bookViewModel.isLoading && bookViewModel.browseBooks.isEmpty {
        ProgressView()
          .frame(maxWidth: .infinity)
          .padding()
      } else {
        switch browseLayout {
        case .grid:
          LazyVGrid(columns: layoutHelper.columns, spacing: layoutHelper.spacing) {
            ForEach(Array(bookViewModel.browseBooks.enumerated()), id: \.element.id) { index, b in
              Group {
                if isSelectionMode && isAdmin {
                  BookCardView(
                    viewModel: bookViewModel,
                    cardWidth: layoutHelper.cardWidth,
                    onReadBook: { _ in },
                    onBookUpdated: refreshBooks,
                    showSeriesTitle: true
                  )
                  .environment(b)
                  .focusPadding()
                  .allowsHitTesting(false)
                  .overlay(alignment: .topTrailing) {
                    Image(
                      systemName: selectedBookIds.contains(b.bookId) ? "checkmark.circle.fill" : "circle"
                    )
                    .foregroundColor(selectedBookIds.contains(b.bookId) ? .accentColor : .secondary)
                    .font(.title3)
                    .padding(8)
                    .background(Circle().fill(.ultraThinMaterial))
                  }
                  .contentShape(Rectangle())
                  .highPriorityGesture(
                    TapGesture().onEnded {
                      withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        if selectedBookIds.contains(b.bookId) {
                          selectedBookIds.remove(b.bookId)
                        } else {
                          selectedBookIds.insert(b.bookId)
                        }
                      }
                    }
                  )
                } else {
                  BookCardView(
                    viewModel: bookViewModel,
                    cardWidth: layoutHelper.cardWidth,
                    onReadBook: { incognito in
                      onReadBook(b.toBook(), incognito)
                    },
                    onBookUpdated: refreshBooks,
                    showSeriesTitle: true
                  )
                  .environment(b)
                  .focusPadding()
                }
              }
              .onAppear {
                if index >= bookViewModel.browseBooks.count - 3 {
                  Task { await loadMore(false) }
                }
              }
            }
          }
          .padding(layoutHelper.spacing)
        case .list:
          LazyVStack(spacing: layoutHelper.spacing) {
            ForEach(Array(bookViewModel.browseBooks.enumerated()), id: \.element.id) { index, b in
              Group {
                if isSelectionMode && isAdmin {
                  BookRowView(
                    viewModel: bookViewModel,
                    onReadBook: { _ in },
                    onBookUpdated: refreshBooks,
                    showSeriesTitle: true
                  )
                  .environment(b)
                  .allowsHitTesting(false)
                  .overlay(alignment: .trailing) {
                    Image(
                      systemName: selectedBookIds.contains(b.bookId) ? "checkmark.circle.fill" : "circle"
                    )
                    .foregroundColor(selectedBookIds.contains(b.bookId) ? .accentColor : .secondary)
                    .font(.title3)
                    .padding(.trailing, 16)
                  }
                  .contentShape(Rectangle())
                  .highPriorityGesture(
                    TapGesture().onEnded {
                      withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        if selectedBookIds.contains(b.bookId) {
                          selectedBookIds.remove(b.bookId)
                        } else {
                          selectedBookIds.insert(b.bookId)
                        }
                      }
                    }
                  )
                } else {
                  BookRowView(
                    viewModel: bookViewModel,
                    onReadBook: { incognito in
                      onReadBook(b.toBook(), incognito)
                    },
                    onBookUpdated: refreshBooks,
                    showSeriesTitle: true
                  )
                  .environment(b)
                }
              }
              .onAppear {
                if index >= bookViewModel.browseBooks.count - 3 {
                  Task { await loadMore(false) }
                }
              }
            }
          }
        }
      }
    }
  }
}
