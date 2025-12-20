//
//  DashboardBooksListView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct DashboardBooksListView: View {
  let bookIds: [String]
  let instanceId: String
  let section: DashboardSection
  let bookViewModel: BookViewModel
  var onBookUpdated: (() -> Void)?
  var loadMore: (() -> Void)?

  @Environment(ReaderPresentationManager.self) private var readerPresentation

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      header
      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(alignment: .top, spacing: 12) {
          ForEach(Array(bookIds.enumerated()), id: \.element) { index, bookId in
            DashboardBookItemView(
              bookId: bookId,
              instanceId: instanceId,
              bookViewModel: bookViewModel,
              onBookUpdated: onBookUpdated,
              readerPresentation: readerPresentation
            )
            .onAppear {
              if index >= bookIds.count - 3 {
                loadMore?()
              }
            }
          }
        }
        .padding()
      }
      .scrollClipDisabled()
    }
    .padding(.bottom, 16)
  }

  private var header: some View {
    Text(section.displayName)
      .font(.title3)
      .fontWeight(.bold)
      .padding(.horizontal)
  }
}

private struct DashboardBookItemView: View {
  let bookId: String
  let instanceId: String
  let bookViewModel: BookViewModel
  let onBookUpdated: (() -> Void)?
  let readerPresentation: ReaderPresentationManager

  @Query private var books: [KomgaBook]

  init(
    bookId: String,
    instanceId: String,
    bookViewModel: BookViewModel,
    onBookUpdated: (() -> Void)?,
    readerPresentation: ReaderPresentationManager
  ) {
    self.bookId = bookId
    self.instanceId = instanceId
    self.bookViewModel = bookViewModel
    self.onBookUpdated = onBookUpdated
    self.readerPresentation = readerPresentation

    let compositeId = "\(instanceId)_\(bookId)"
    _books = Query(filter: #Predicate<KomgaBook> { $0.id == compositeId })
  }

  var body: some View {
    if let komgaBook = books.first {
      BookCardView(
        viewModel: bookViewModel,
        cardWidth: PlatformHelper.dashboardCardWidth,
        onReadBook: { incognito in
          readerPresentation.present(book: komgaBook.toBook(), incognito: incognito)
        },
        onBookUpdated: onBookUpdated,
        showSeriesTitle: true
      )
      .environment(komgaBook)
      .focusPadding()
    }
  }
}
