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
  var browseBookIds: [String] = []
  var browseBooks: [KomgaBook] = []

  private let bookService = BookService.shared
  private let sseService = SSEService.shared
  private(set) var currentPage = 0
  private var hasMorePages = true
  private var currentSeriesId: String?
  private var currentSeriesBrowseOpts: BookBrowseOptions?

  private let pageSize = 20

  func loadSeriesBooks(
    context: ModelContext,
    seriesId: String,
    browseOpts: BookBrowseOptions,
    libraryIds: [String]? = nil,
    refresh: Bool = true
  ) async {
    if refresh || currentSeriesId != seriesId {
      currentPage = 0
      hasMorePages = true
      currentSeriesId = seriesId
      currentSeriesBrowseOpts = browseOpts
    }

    guard hasMorePages && !isLoading else { return }
    isLoading = true

    if AppConfig.isOffline {
      let books = KomgaBookStore.fetchSeriesBooks(
        context: context,
        seriesId: seriesId,
        page: currentPage,
        size: 50,
        browseOpts: browseOpts
      )
      let ids = books.map { $0.id }
      updateState(context: context, ids: ids, moreAvailable: ids.count == 50)
    } else {
      do {
        let page = try await SyncService.shared.syncBooks(
          seriesId: seriesId,
          page: currentPage,
          size: 50,
          browseOpts: browseOpts,
          libraryIds: libraryIds
        )

        let ids = page.content.map { $0.id }
        updateState(context: context, ids: ids, moreAvailable: !page.last)
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }

    withAnimation {
      isLoading = false
    }
  }

  private func updateState(context: ModelContext, ids: [String], moreAvailable: Bool) {
    let books = KomgaBookStore.fetchBooksByIds(
      context: context,
      ids: ids, instanceId: AppConfig.currentInstanceId)
    withAnimation {
      if currentPage == 0 {
        browseBookIds = ids
        browseBooks = books
      } else {
        browseBookIds.append(contentsOf: ids)
        browseBooks.append(contentsOf: books)
      }
    }
    hasMorePages = moreAvailable
    currentPage += 1
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
    if refresh {
      currentPage = 0
      hasMorePages = true
    }

    guard hasMorePages && !isLoading else { return }
    isLoading = true

    if AppConfig.isOffline {
      let ids = KomgaBookStore.fetchBookIds(
        context: context,
        libraryIds: libraryIds,
        searchText: searchText,
        browseOpts: browseOpts,
        offset: currentPage * pageSize,
        limit: pageSize
      )
      updateState(context: context, ids: ids, moreAvailable: ids.count == pageSize)
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
          page: currentPage,
          size: pageSize,
          sort: browseOpts.sortString
        )

        let ids = page.content.map { $0.id }
        updateState(context: context, ids: ids, moreAvailable: !page.last)
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }

    withAnimation {
      isLoading = false
    }
  }

  func loadReadListBooks(
    context: ModelContext,
    readListId: String,
    browseOpts: ReadListBookBrowseOptions,
    libraryIds: [String]? = nil,
    refresh: Bool = false
  ) async {
    if refresh {
      currentPage = 0
      hasMorePages = true
    }

    guard hasMorePages && !isLoading else { return }
    isLoading = true

    if AppConfig.isOffline {
      let books = KomgaBookStore.fetchReadListBooks(
        context: context,
        readListId: readListId,
        page: currentPage,
        size: 50,
        browseOpts: browseOpts
      )
      let ids = books.map { $0.id }
      updateState(context: context, ids: ids, moreAvailable: ids.count == 50)
    } else {
      do {
        let page = try await SyncService.shared.syncReadListBooks(
          readListId: readListId,
          page: currentPage,
          size: 50,
          browseOpts: browseOpts,
          libraryIds: libraryIds
        )

        let ids = page.content.map { $0.id }
        updateState(context: context, ids: ids, moreAvailable: !page.last)
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }

    withAnimation {
      isLoading = false
    }
  }
}
