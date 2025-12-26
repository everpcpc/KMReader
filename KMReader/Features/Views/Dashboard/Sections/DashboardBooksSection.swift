//
//  DashboardBooksSection.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct DashboardBooksSection: View {
  let section: DashboardSection
  var bookViewModel: BookViewModel
  let refreshTrigger: UUID
  var onBookUpdated: (() -> Void)? = nil

  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()
  @AppStorage("dashboardCardWidth") private var dashboardCardWidth: Double = Double(
    PlatformHelper.defaultDashboardCardWidth)
  @Environment(\.modelContext) private var modelContext

  @State private var bookIds: [String] = []
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
          ForEach(Array(bookIds.enumerated()), id: \.element) { index, bookId in
            BookQueryItemView(
              bookId: bookId,
              viewModel: bookViewModel,
              cardWidth: CGFloat(dashboardCardWidth),
              layout: .grid,
              onBookUpdated: onBookUpdated,
              showSeriesTitle: true
            )
            .onAppear {
              if index >= bookIds.count - 3 {
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
    await loadMore()
    hasLoadedInitial = true
  }

  private func loadMore() async {
    guard hasMore, !isLoading else { return }
    isLoading = true

    let libraryIds = dashboard.libraryIds
    let isFirstPage = currentPage == 0

    if AppConfig.isOffline {
      let ids = fetchOfflineBookIds(libraryIds: libraryIds)
      updateState(ids: ids, moreAvailable: ids.count == pageSize, isFirstPage: isFirstPage)
    } else {
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
    withAnimation {
      if isFirstPage {
        bookIds = ids
      } else {
        bookIds.append(contentsOf: ids)
      }
    }
    hasMore = moreAvailable
    currentPage += 1
  }

  private func fetchOfflineBookIds(libraryIds: [String]) -> [String] {
    switch section {
    case .keepReading:
      return KomgaBookStore.fetchKeepReadingBookIds(
        context: modelContext,
        libraryIds: libraryIds,
        offset: currentPage * pageSize,
        limit: pageSize
      )
    case .onDeck:
      return []
    case .recentlyReadBooks:
      return KomgaBookStore.fetchRecentlyReadBookIds(
        context: modelContext,
        libraryIds: libraryIds,
        offset: currentPage * pageSize,
        limit: pageSize
      )
    case .recentlyReleasedBooks:
      return KomgaBookStore.fetchRecentlyReleasedBookIds(
        context: modelContext,
        libraryIds: libraryIds,
        offset: currentPage * pageSize,
        limit: pageSize
      )
    case .recentlyAddedBooks:
      return KomgaBookStore.fetchRecentlyAddedBookIds(
        context: modelContext,
        libraryIds: libraryIds,
        offset: currentPage * pageSize,
        limit: pageSize
      )
    default:
      return []
    }
  }
}
