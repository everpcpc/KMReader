//
//  DashboardBooksSection.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct DashboardBooksSection: View {
  let section: DashboardSection
  var bookViewModel: BookViewModel
  let refreshTrigger: UUID
  var onBookUpdated: (() -> Void)? = nil

  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()
  @Environment(ReaderPresentationManager.self) private var readerPresentation

  @State private var bookIds: [String] = []
  @State private var browseBooks: [KomgaBook] = []
  @State private var currentPage = 0
  @State private var hasMore = true
  @State private var isLoading = false
  @State private var hasLoadedInitial = false

  private let pageSize = 20

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(section.displayName)
        .font(.title3)
        .fontWeight(.bold)
        .padding(.horizontal)

      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(alignment: .top, spacing: 12) {
          ForEach(Array(browseBooks.enumerated()), id: \.element.id) { index, book in
            DashboardBookItemView(
              bookViewModel: bookViewModel,
              onBookUpdated: onBookUpdated,
              readerPresentation: readerPresentation
            )
            .environment(book)
            .onAppear {
              if index >= browseBooks.count - 3 {
                Task {
                  await loadMore()
                }
              }
            }
          }
        }
        .padding()
      }
      .scrollClipDisabled()
    }
    .opacity(browseBooks.isEmpty ? 0 : 1)
    .frame(height: browseBooks.isEmpty ? 0 : nil)
    .onChange(of: refreshTrigger) {
      Task {
        await refresh()
      }
    }
    .task {
      await loadInitial()
    }
  }

  private func loadInitial() async {
    guard !hasLoadedInitial else { return }
    await refresh()
  }

  private func refresh() async {
    currentPage = 0
    hasMore = true
    await loadMore()
    hasLoadedInitial = true
  }

  private func loadMore() async {
    guard hasMore, !isLoading else { return }
    isLoading = true

    let libraryIds = dashboard.libraryIds
    let isFirstPage = currentPage == 0

    if AppConfig.isOffline {
      // Offline: query SwiftData directly
      let ids = fetchOfflineBookIds(libraryIds: libraryIds)
      updateState(ids: ids, moreAvailable: ids.count == pageSize, isFirstPage: isFirstPage)
    } else {
      // Online: fetch from API and sync
      do {
        let page: Page<Book>

        switch section {
        case .keepReading:
          let condition = BookSearch.buildCondition(
            filters: BookSearchFilters(
              libraryIds: libraryIds,
              includeReadStatuses: [ReadStatus.inProgress]
            )
          )
          let search = BookSearch(condition: condition)
          page = try await SyncService.shared.syncBooksList(
            search: search,
            page: currentPage,
            size: pageSize,
            sort: "readProgress.readDate,desc"
          )

        case .onDeck:
          page = try await SyncService.shared.syncBooksOnDeck(
            libraryIds: libraryIds,
            page: currentPage,
            size: pageSize
          )

        case .recentlyReadBooks:
          page = try await SyncService.shared.syncRecentlyReadBooks(
            libraryIds: libraryIds,
            page: currentPage,
            size: pageSize
          )

        case .recentlyReleasedBooks:
          page = try await SyncService.shared.syncRecentlyReleasedBooks(
            libraryIds: libraryIds,
            page: currentPage,
            size: pageSize
          )

        case .recentlyAddedBooks:
          page = try await SyncService.shared.syncRecentlyAddedBooks(
            libraryIds: libraryIds,
            page: currentPage,
            size: pageSize
          )

        default:
          withAnimation {
            isLoading = false
          }
          return
        }

        let ids = page.content.map { $0.id }
        updateState(ids: ids, moreAvailable: !page.last, isFirstPage: isFirstPage)
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }

    withAnimation {
      isLoading = false
    }
  }

  private func updateState(ids: [String], moreAvailable: Bool, isFirstPage: Bool) {
    let books = KomgaBookStore.shared.fetchBooksByIds(
      ids: ids, instanceId: AppConfig.currentInstanceId)
    withAnimation {
      if isFirstPage {
        bookIds = ids
        browseBooks = books
      } else {
        bookIds.append(contentsOf: ids)
        browseBooks.append(contentsOf: books)
      }
    }
    hasMore = moreAvailable
    currentPage += 1
  }

  private func fetchOfflineBookIds(libraryIds: [String]) -> [String] {
    // Offline queries based on section type
    switch section {
    case .keepReading:
      return KomgaBookStore.shared.fetchKeepReadingBookIds(
        libraryIds: libraryIds,
        offset: currentPage * pageSize,
        limit: pageSize
      )
    case .onDeck:
      // TODO: implement
      return []
    case .recentlyReadBooks:
      return KomgaBookStore.shared.fetchRecentlyReadBookIds(
        libraryIds: libraryIds,
        offset: currentPage * pageSize,
        limit: pageSize
      )
    case .recentlyReleasedBooks:
      return KomgaBookStore.shared.fetchRecentlyReleasedBookIds(
        libraryIds: libraryIds,
        offset: currentPage * pageSize,
        limit: pageSize
      )
    case .recentlyAddedBooks:
      return KomgaBookStore.shared.fetchRecentlyAddedBookIds(
        libraryIds: libraryIds,
        offset: currentPage * pageSize,
        limit: pageSize
      )
    default:
      return []
    }
  }
}

private struct DashboardBookItemView: View {
  @Environment(KomgaBook.self) private var book
  let bookViewModel: BookViewModel
  let onBookUpdated: (() -> Void)?
  let readerPresentation: ReaderPresentationManager

  var body: some View {
    BookCardView(
      viewModel: bookViewModel,
      cardWidth: PlatformHelper.dashboardCardWidth,
      onReadBook: { incognito in
        readerPresentation.present(book: book.toBook(), incognito: incognito)
      },
      onBookUpdated: onBookUpdated,
      showSeriesTitle: true
    )
    .focusPadding()
  }
}
