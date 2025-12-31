//
//  BookViewModel.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
class BookViewModel {
  var currentBook: Book?
  var isLoading = false

  private let bookService = BookService.shared
  private let sseService = SSEService.shared
  private(set) var pagination = PaginationState<IdentifiedString>(pageSize: 50)
  private var currentSeriesId: String?
  private var currentSeriesBrowseOpts: BookBrowseOptions?

  func loadSeriesBooks(
    context: ModelContext,
    seriesId: String,
    browseOpts: BookBrowseOptions,
    refresh: Bool = true
  ) async {
    let shouldReset = refresh || currentSeriesId != seriesId

    if !shouldReset {
      guard pagination.hasMorePages && !isLoading else { return }
    }

    if shouldReset {
      pagination.reset()
      currentSeriesId = seriesId
      currentSeriesBrowseOpts = browseOpts
    }

    let loadID = pagination.loadID
    isLoading = true

    defer {
      if loadID == pagination.loadID {
        withAnimation {
          isLoading = false
        }
      }
    }

    if AppConfig.isOffline {
      let books = KomgaBookStore.fetchSeriesBooks(
        context: context,
        seriesId: seriesId,
        page: pagination.currentPage,
        size: pagination.pageSize,
        browseOpts: browseOpts
      )
      guard loadID == pagination.loadID else { return }
      let ids = books.map { $0.id }
      applyPage(ids: ids, moreAvailable: ids.count == pagination.pageSize)
    } else {
      do {
        let page = try await SyncService.shared.syncBooks(
          seriesId: seriesId,
          page: pagination.currentPage,
          size: pagination.pageSize,
          browseOpts: browseOpts
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

  func loadBook(context: ModelContext, id: String) async {
    isLoading = true

    if let cached = KomgaBookStore.fetchBook(context: context, id: id) {
      currentBook = cached
    }

    do {
      currentBook = try await SyncService.shared.syncBook(bookId: id)
    } catch {
      if currentBook == nil {
        ErrorManager.shared.alert(error: error)
      }
    }

    withAnimation {
      isLoading = false
    }
  }

  func updatePageReadProgress(bookId: String, page: Int, completed: Bool = false) async {
    do {
      try await bookService.updatePageReadProgress(bookId: bookId, page: page, completed: completed)
    } catch {
      ErrorManager.shared.alert(error: error)
    }
  }

  func markAsRead(bookId: String) async {
    do {
      try await bookService.markAsRead(bookId: bookId)
      let updatedBook = try await SyncService.shared.syncBook(bookId: bookId)
      if currentBook?.id == bookId {
        currentBook = updatedBook
      }
      await MainActor.run {
        ErrorManager.shared.notify(message: String(localized: "notification.book.markedRead"))
      }
    } catch {
      ErrorManager.shared.alert(error: error)
    }
  }

  func markAsUnread(bookId: String) async {
    do {
      try await bookService.markAsUnread(bookId: bookId)
      let updatedBook = try await SyncService.shared.syncBook(bookId: bookId)
      if currentBook?.id == bookId {
        currentBook = updatedBook
      }
      await MainActor.run {
        ErrorManager.shared.notify(message: String(localized: "notification.book.markedUnread"))
      }
    } catch {
      ErrorManager.shared.alert(error: error)
    }
  }

  func loadBrowseBooks(
    context: ModelContext,
    browseOpts: BookBrowseOptions,
    searchText: String = "",
    libraryIds: [String]? = nil,
    refresh: Bool = false
  ) async {
    if !refresh {
      guard pagination.hasMorePages && !isLoading else { return }
    }

    if refresh {
      pagination.reset()
    }

    let loadID = pagination.loadID
    isLoading = true

    defer {
      if loadID == pagination.loadID {
        withAnimation {
          isLoading = false
        }
      }
    }

    if AppConfig.isOffline {
      let ids = KomgaBookStore.fetchBookIds(
        context: context,
        libraryIds: libraryIds,
        searchText: searchText,
        browseOpts: browseOpts,
        offset: pagination.currentPage * pagination.pageSize,
        limit: pagination.pageSize
      )
      guard loadID == pagination.loadID else { return }
      applyPage(ids: ids, moreAvailable: ids.count == pagination.pageSize)
    } else {
      do {
        let filters = BookSearchFilters(
          libraryIds: libraryIds,
          includeReadStatuses: Array(browseOpts.includeReadStatuses),
          excludeReadStatuses: Array(browseOpts.excludeReadStatuses),
          oneshot: browseOpts.oneshotFilter.effectiveBool,
          deleted: browseOpts.deletedFilter.effectiveBool
        )
        let condition = BookSearch.buildCondition(filters: filters)
        let bookSearch = BookSearch(
          condition: condition,
          fullTextSearch: searchText.isEmpty == false ? searchText : nil
        )

        let page = try await SyncService.shared.syncBooksList(
          search: bookSearch,
          page: pagination.currentPage,
          size: pagination.pageSize,
          sort: browseOpts.sortString
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

  func loadReadListBooks(
    context: ModelContext,
    readListId: String,
    browseOpts: ReadListBookBrowseOptions,
    libraryIds: [String]? = nil,
    refresh: Bool = false
  ) async {
    if !refresh {
      guard pagination.hasMorePages && !isLoading else { return }
    }

    if refresh {
      pagination.reset()
    }

    let loadID = pagination.loadID
    isLoading = true

    defer {
      if loadID == pagination.loadID {
        withAnimation {
          isLoading = false
        }
      }
    }

    if AppConfig.isOffline {
      let books = KomgaBookStore.fetchReadListBooks(
        context: context,
        readListId: readListId,
        page: pagination.currentPage,
        size: pagination.pageSize,
        browseOpts: browseOpts
      )
      guard loadID == pagination.loadID else { return }
      let ids = books.map { $0.id }
      applyPage(ids: ids, moreAvailable: ids.count == pagination.pageSize)
    } else {
      do {
        let page = try await SyncService.shared.syncReadListBooks(
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
