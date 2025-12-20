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
  @State private var currentPage = 0
  @State private var hasMore = true
  @State private var isLoading = false
  @State private var hasLoadedInitial = false

  private let pageSize = 20

  var body: some View {
    DashboardBooksListView(
      bookIds: bookIds,
      instanceId: AppConfig.currentInstanceId,
      section: section,
      bookViewModel: bookViewModel,
      onBookUpdated: onBookUpdated,
      loadMore: {
        Task {
          await loadMore()
        }
      }
    )
    .opacity(bookIds.isEmpty ? 0 : 1)
    .frame(height: bookIds.isEmpty ? 0 : nil)
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
    withAnimation {
      bookIds = []
    }

    await loadMore()
    hasLoadedInitial = true
  }

  private func loadMore() async {
    guard hasMore, !isLoading else { return }
    withAnimation {
      isLoading = true
    }

    let libraryIds = dashboard.libraryIds

    if AppConfig.isOffline {
      // Offline: query SwiftData directly
      let ids = fetchOfflineBookIds(libraryIds: libraryIds)
      withAnimation {
        bookIds.append(contentsOf: ids)
      }
      hasMore = ids.count == pageSize
      currentPage += 1
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

        withAnimation {
          bookIds.append(contentsOf: page.content.map { $0.id })
        }
        hasMore = !page.last
        currentPage += 1
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }

    withAnimation {
      isLoading = false
    }
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
    case .onDeck, .recentlyReadBooks, .recentlyAddedBooks, .recentlyReleasedBooks:
      // For these sections, we can only show cached data based on what's in SwiftData
      // The offline experience is limited since we don't have specific ordering
      return KomgaBookStore.shared.fetchRecentBookIds(
        libraryIds: libraryIds,
        offset: currentPage * pageSize,
        limit: pageSize
      )
    default:
      return []
    }
  }
}
