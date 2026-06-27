//
// BookViewModel.swift
//
//

import Foundation
import SwiftUI

@MainActor
@Observable
class BookViewModel {
  var currentBook: Book?
  var isLoading = false

  private(set) var pagination = PaginationState<IdentifiedString>(pageSize: 50)

  func loadSeriesBooks(
    seriesId: String,
    browseOpts: BookBrowseOptions,
    refresh: Bool = true
  ) async {
    guard let loadID = beginLoad(refresh: refresh) else { return }

    defer {
      if loadID == pagination.loadID {
        withAnimation {
          isLoading = false
        }
      }
    }

    if AppConfig.isOffline {
      guard let database = try? await DatabaseOperator.database() else {
        guard loadID == pagination.loadID else { return }
        applyPage(ids: [], moreAvailable: false)
        return
      }
      let ids = await database.fetchSeriesBookIds(
        seriesId: seriesId,
        browseOpts: browseOpts,
        page: pagination.currentPage,
        size: pagination.pageSize
      )
      guard loadID == pagination.loadID else { return }
      applyPage(ids: ids, moreAvailable: ids.count == pagination.pageSize)
    } else {
      do {
        let page = try await SyncService.syncBooks(
          seriesId: seriesId,
          page: pagination.currentPage,
          size: pagination.pageSize,
          browseOpts: normalizedRemoteBrowseOptions(browseOpts)
        )

        guard loadID == pagination.loadID else { return }
        let ids = page.content.map { $0.id }
        applyPage(ids: ids, moreAvailable: !page.last)
      } catch {
        guard loadID == pagination.loadID else { return }
        ErrorManager.shared.alert(error: error)
      }
    }
  }

  private func applyPage(ids: [String], moreAvailable: Bool) {
    let wrappedIds = ids.map(IdentifiedString.init)
    withAnimation {
      _ = pagination.applyPage(wrappedIds)
    }
    pagination.advance(moreAvailable: moreAvailable)
  }

  private func beginLoad(refresh: Bool) -> UUID? {
    if refresh {
      withAnimation {
        pagination.reset()
        isLoading = true
      }
      return pagination.loadID
    }

    guard pagination.hasMorePages && !isLoading else { return nil }
    withAnimation {
      isLoading = true
    }
    return pagination.loadID
  }

  func updatePageReadProgress(bookId: String, page: Int, completed: Bool = false) async {
    do {
      try await BookService.updatePageReadProgress(
        bookId: bookId,
        page: page,
        completed: completed
      )
    } catch {
      ErrorManager.shared.alert(error: error)
    }
  }

  func markAsRead(bookId: String) async {
    do {
      try await BookService.markAsRead(bookId: bookId)
      let updatedBook = try await SyncService.syncBook(bookId: bookId)
      _ = try? await SyncService.syncSeriesDetail(seriesId: updatedBook.seriesId)
      if currentBook?.id == bookId {
        currentBook = updatedBook
      }
      await ContentProjectionNotifier.postBookAndSeriesDidChange(
        bookId: bookId,
        seriesId: updatedBook.seriesId,
        reason: .readingProgress
      )
      await postReadStatusDashboardRefresh()
      ErrorManager.shared.notify(message: String(localized: "notification.book.markedRead"))
    } catch {
      ErrorManager.shared.alert(error: error)
    }
  }

  func markAsUnread(bookId: String) async {
    do {
      try await BookService.markAsUnread(bookId: bookId)
      let updatedBook = try await SyncService.syncBook(bookId: bookId)
      _ = try? await SyncService.syncSeriesDetail(seriesId: updatedBook.seriesId)
      if currentBook?.id == bookId {
        currentBook = updatedBook
      }
      await ContentProjectionNotifier.postBookAndSeriesDidChange(
        bookId: bookId,
        seriesId: updatedBook.seriesId,
        reason: .readingProgress
      )
      await postReadStatusDashboardRefresh()
      ErrorManager.shared.notify(message: String(localized: "notification.book.markedUnread"))
    } catch {
      ErrorManager.shared.alert(error: error)
    }
  }

  func loadBrowseBooks(
    browseOpts: BookBrowseOptions,
    searchText: String = "",
    libraryIds: [String]? = nil,
    refresh: Bool = false,
    useLocalOnly: Bool = false,
    offlineOnly: Bool = false
  ) async {
    guard let loadID = beginLoad(refresh: refresh) else { return }

    defer {
      if loadID == pagination.loadID {
        withAnimation {
          isLoading = false
        }
      }
    }

    if AppConfig.isOffline || useLocalOnly {
      guard let database = try? await DatabaseOperator.database() else {
        guard loadID == pagination.loadID else { return }
        applyPage(ids: [], moreAvailable: false)
        return
      }
      let ids = await database.fetchBrowseBookIds(
        instanceId: AppConfig.current.instanceId,
        libraryIds: libraryIds,
        searchText: searchText,
        browseOpts: browseOpts,
        offset: pagination.currentPage * pagination.pageSize,
        limit: pagination.pageSize,
        offlineOnly: offlineOnly
      )
      guard loadID == pagination.loadID else { return }
      applyPage(ids: ids, moreAvailable: ids.count == pagination.pageSize)
    } else {
      do {
        let page = try await SyncService.syncBrowseBooks(
          libraryIds: libraryIds,
          page: pagination.currentPage,
          size: pagination.pageSize,
          searchTerm: searchText.isEmpty ? nil : searchText,
          browseOpts: normalizedRemoteBrowseOptions(browseOpts)
        )

        guard loadID == pagination.loadID else { return }
        let ids = page.content.map { $0.id }
        applyPage(ids: ids, moreAvailable: !page.last)
      } catch {
        guard loadID == pagination.loadID else { return }
        ErrorManager.shared.alert(error: error)
      }
    }
  }

  func removeBooksNotMatchingReadStatusFilter(
    bookIds: Set<String>,
    browseOpts: BookBrowseOptions
  ) async {
    guard hasReadStatusFilter(browseOpts) else { return }

    let visibleIds = Set(pagination.items.map(\.id))
    let targetIds = visibleIds.intersection(bookIds)
    guard !targetIds.isEmpty else { return }
    guard let database = try? await DatabaseOperator.database() else { return }

    var removedIds = Set<String>()
    for bookId in targetIds {
      guard
        let item = try? await database.fetchBookDisplayItem(
          bookId: bookId,
          instanceId: AppConfig.current.instanceId
        )
      else {
        removedIds.insert(bookId)
        continue
      }

      if !matchesReadStatusFilter(
        readStatus(for: item),
        include: browseOpts.includeReadStatuses,
        exclude: browseOpts.excludeReadStatuses
      ) {
        removedIds.insert(bookId)
      }
    }

    guard !removedIds.isEmpty else { return }
    withAnimation {
      _ = pagination.removeAll { removedIds.contains($0.id) }
    }
  }

  private func normalizedRemoteBrowseOptions(_ browseOpts: BookBrowseOptions)
    -> BookBrowseOptions
  {
    guard browseOpts.sortField == .downloadDate else {
      return browseOpts
    }

    var fallback = browseOpts
    fallback.sortField = .dateAdded
    return fallback
  }

  private func hasReadStatusFilter(_ browseOpts: BookBrowseOptions) -> Bool {
    !browseOpts.includeReadStatuses.isEmpty || !browseOpts.excludeReadStatuses.isEmpty
  }

  private func readStatus(for item: BookDisplayItem) -> ReadStatus {
    if item.isCompleted {
      return .read
    }
    if item.isInProgress {
      return .inProgress
    }
    return .unread
  }

  private func postReadStatusDashboardRefresh() async {
    await DashboardSectionRefreshNotifier.postReadStatusChanged(
      source: .manual,
      reason: "Book read status changed"
    )
  }

  func loadReadListBooks(
    readListId: String,
    browseOpts: ReadListBookBrowseOptions,
    libraryIds: [String]? = nil,
    refresh: Bool = false
  ) async {
    guard let loadID = beginLoad(refresh: refresh) else { return }

    defer {
      if loadID == pagination.loadID {
        withAnimation {
          isLoading = false
        }
      }
    }

    if AppConfig.isOffline {
      guard let database = try? await DatabaseOperator.database() else {
        guard loadID == pagination.loadID else { return }
        applyPage(ids: [], moreAvailable: false)
        return
      }
      let ids = await database.fetchReadListBookIds(
        readListId: readListId,
        browseOpts: browseOpts,
        page: pagination.currentPage,
        size: pagination.pageSize
      )
      guard loadID == pagination.loadID else { return }
      applyPage(ids: ids, moreAvailable: ids.count == pagination.pageSize)
    } else {
      do {
        let page = try await SyncService.syncReadListBooks(
          readListId: readListId,
          page: pagination.currentPage,
          size: pagination.pageSize,
          browseOpts: browseOpts,
          libraryIds: libraryIds
        )

        guard loadID == pagination.loadID else { return }
        let ids = page.content.map { $0.id }
        applyPage(ids: ids, moreAvailable: !page.last)
      } catch {
        guard loadID == pagination.loadID else { return }
        ErrorManager.shared.alert(error: error)
      }
    }
  }
}
