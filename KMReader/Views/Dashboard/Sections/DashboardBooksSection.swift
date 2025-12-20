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

  @State private var books: [Book] = []
  @State private var currentPage = 0
  @State private var hasMore = true
  @State private var isLoading = false
  @State private var lastTriggeredIndex: Int = -1
  @State private var hasLoadedInitial = false

  // Load data when view appears (if not already loaded or if empty due to cancelled request)
  var shouldInitialLoad: Bool {
    return !hasLoadedInitial || (books.isEmpty && !isLoading)
  }

  // Loading indicator at the end - only show when loading more and has content
  var shouldShowLoadingIndicator: Bool {
    return isLoading && hasLoadedInitial && !books.isEmpty
  }

  func shouldLoadMore(index: Int) -> Bool {
    return index >= books.count - 3 && hasMore && !isLoading && lastTriggeredIndex != index
  }

  var body: some View {
    Group {
      if !books.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Text(section.displayName)
            .font(.title3)
            .fontWeight(.bold)
            .padding(.horizontal)

          ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 12) {
              ForEach(Array(books.enumerated()), id: \.element.id) { index, book in
                BookCardView(
                  book: book,
                  viewModel: bookViewModel,
                  cardWidth: PlatformHelper.dashboardCardWidth,
                  onReadBook: { incognito in
                    readerPresentation.present(book: book, incognito: incognito)
                  },
                  onBookUpdated: onBookUpdated,
                  showSeriesTitle: true
                )
                .focusPadding()
                .onAppear {
                  // Trigger load when we're near the last item (within last 3 items)
                  // Only trigger once per index to avoid repeated loads
                  if shouldLoadMore(index: index) {
                    lastTriggeredIndex = index
                    Task {
                      await loadMore()
                    }
                  }
                }
              }

              if shouldShowLoadingIndicator {
                ProgressView()
                  .frame(width: PlatformHelper.dashboardCardWidth, height: 200)
                  .padding(.trailing, 12)
              }
            }
            .padding()
          }
          .scrollClipDisabled()
        }
        .padding(.bottom, 16)
      } else {
        Color.clear
          .frame(height: 0)
      }
    }
    .onChange(of: refreshTrigger) {
      Task {
        await loadInitial()
      }
    }
    .onAppear {
      if shouldInitialLoad {
        Task {
          await loadInitial()
        }
      }
    }
  }

  private func loadInitial() async {
    currentPage = 0
    hasMore = true
    lastTriggeredIndex = -1
    hasLoadedInitial = false

    // Load first page first, then replace
    await loadMore(reset: true)
    hasLoadedInitial = true
  }

  private func loadMore(reset: Bool = false) async {
    guard hasMore, !isLoading else { return }
    isLoading = true

    do {
      let libraryIds = dashboard.libraryIds
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
          size: 20,
          sort: "readProgress.readDate,desc"
        )

      case .onDeck:
        page = try await SyncService.shared.syncBooksOnDeck(
          libraryIds: libraryIds,
          page: currentPage,
          size: 20
        )

      case .recentlyReadBooks:
        page = try await SyncService.shared.syncRecentlyReadBooks(
          libraryIds: libraryIds,
          page: currentPage,
          size: 20
        )

      case .recentlyReleasedBooks:
        page = try await SyncService.shared.syncRecentlyReleasedBooks(
          libraryIds: libraryIds,
          page: currentPage,
          size: 20
        )

      case .recentlyAddedBooks:
        page = try await SyncService.shared.syncRecentlyAddedBooks(
          libraryIds: libraryIds,
          page: currentPage,
          size: 20
        )

      default:
        isLoading = false
        return
      }

      var newBooks = page.content

      // Filter out books without release dates for recentlyReleasedBooks
      if section == .recentlyReleasedBooks {
        newBooks = newBooks.filter {
          $0.metadata.releaseDate != nil && !$0.metadata.releaseDate!.isEmpty
        }
      }

      withAnimation {
        if reset {
          books = newBooks
        } else {
          books.append(contentsOf: newBooks)
        }
      }

      hasMore = !page.last
      currentPage += 1

      // Reset trigger index after loading to allow next trigger
      lastTriggeredIndex = -1
    } catch {
      ErrorManager.shared.alert(error: error)
    }

    isLoading = false
  }
}
