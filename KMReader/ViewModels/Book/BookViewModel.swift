//
//  BookViewModel.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
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

  func loadBooks(
    seriesId: String, browseOpts: BookBrowseOptions, libraryIds: [String]? = nil,
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

    do {
      let page = try await SyncService.shared.syncBooks(
        seriesId: seriesId,
        page: currentPage,
        size: 50,
        browseOpts: browseOpts,
        libraryIds: libraryIds
      )

      let ids = page.content.map { $0.id }
      let books = KomgaBookStore.shared.fetchBooksByIds(
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
      hasMorePages = !page.last
      currentPage += 1
    } catch {
      ErrorManager.shared.alert(error: error)
    }

    withAnimation {
      isLoading = false
    }
  }

  func loadMoreBooks(seriesId: String, libraryIds: [String]? = nil) async {
    guard hasMorePages && !isLoading && seriesId == currentSeriesId,
      let browseOpts = currentSeriesBrowseOpts
    else { return }

    isLoading = true

    do {
      let page = try await SyncService.shared.syncBooks(
        seriesId: seriesId, page: currentPage, size: 50, browseOpts: browseOpts,
        libraryIds: libraryIds)

      let ids = page.content.map { $0.id }
      let books = KomgaBookStore.shared.fetchBooksByIds(
        ids: ids, instanceId: AppConfig.currentInstanceId)
      withAnimation {
        browseBookIds.append(contentsOf: ids)
        browseBooks.append(contentsOf: books)
      }
      hasMorePages = !page.last
      currentPage += 1
    } catch {
      ErrorManager.shared.alert(error: error)
    }

    withAnimation {
      isLoading = false
    }
  }

  func refreshCurrentBooks() async {
    guard let seriesId = currentSeriesId,
      let browseOpts = currentSeriesBrowseOpts
    else { return }
    await loadBooks(seriesId: seriesId, browseOpts: browseOpts, refresh: true)
  }

  func loadBook(id: String) async {
    isLoading = true

    // Local
    if let cached = KomgaBookStore.shared.fetchBook(id: id) {
      currentBook = cached
    }

    do {
      currentBook = try await SyncService.shared.syncBook(bookId: id)
    } catch {
      // Keep cached book if available
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
      if currentBook?.id == bookId {
        await loadBook(id: bookId)
      }
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

  func loadBooksOnDeck(libraryIds: [String]? = nil, refresh: Bool = false) async {
    if refresh {
      currentPage = 0
      hasMorePages = true
    }

    guard hasMorePages && !isLoading else { return }
    isLoading = true

    do {
      let page = try await SyncService.shared.syncBooksOnDeck(
        libraryIds: libraryIds,
        page: currentPage,
        size: 20
      )

      hasMorePages = !page.last
      currentPage += 1
    } catch {
      ErrorManager.shared.alert(error: error)
    }

    withAnimation {
      isLoading = false
    }
  }

  func loadRecentlyAddedBooks(libraryIds: [String]? = nil, refresh: Bool = false) async {
    if refresh {
      currentPage = 0
      hasMorePages = true
    }

    guard hasMorePages && !isLoading else { return }
    isLoading = true

    do {
      let page = try await SyncService.shared.syncRecentlyAddedBooks(
        libraryIds: libraryIds,
        page: currentPage,
        size: 20
      )

      hasMorePages = !page.last
      currentPage += 1
    } catch {
      ErrorManager.shared.alert(error: error)
    }

    withAnimation {
      isLoading = false
    }
  }

  func loadRecentlyReadBooks(libraryIds: [String]? = nil, refresh: Bool = false) async {
    if refresh {
      currentPage = 0
      hasMorePages = true
    }

    guard hasMorePages && !isLoading else { return }
    isLoading = true

    do {
      let page = try await SyncService.shared.syncRecentlyReadBooks(
        libraryIds: libraryIds,
        page: currentPage,
        size: 20
      )

      hasMorePages = !page.last
      currentPage += 1
    } catch {
      ErrorManager.shared.alert(error: error)
    }

    withAnimation {
      isLoading = false
    }
  }

  func loadBrowseBooks(
    browseOpts: BookBrowseOptions, searchText: String = "", libraryIds: [String]? = nil,
    refresh: Bool = false
  )
    async
  {
    if refresh {
      currentPage = 0
      hasMorePages = true
    }

    guard hasMorePages && !isLoading else { return }
    isLoading = true

    if AppConfig.isOffline {
      // Offline: query SwiftData directly
      let ids = KomgaBookStore.shared.fetchBookIds(
        libraryIds: libraryIds,
        searchText: searchText,
        browseOpts: browseOpts,
        offset: currentPage * pageSize,
        limit: pageSize
      )
      let books = KomgaBookStore.shared.fetchBooksByIds(
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
      hasMorePages = ids.count == pageSize
      currentPage += 1
    } else {
      // Online: fetch from API and sync
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
        let books = KomgaBookStore.shared.fetchBooksByIds(
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
        hasMorePages = !page.last
        currentPage += 1
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }

    withAnimation {
      isLoading = false
    }
  }

  func loadReadListBooks(
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

    do {
      let page = try await SyncService.shared.syncReadListBooks(
        readListId: readListId,
        page: currentPage,
        size: 50,
        browseOpts: browseOpts,
        libraryIds: libraryIds
      )

      let ids = page.content.map { $0.id }
      let books = KomgaBookStore.shared.fetchBooksByIds(
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
      hasMorePages = !page.last
      currentPage += 1
    } catch {
      ErrorManager.shared.alert(error: error)
    }

    withAnimation {
      isLoading = false
    }
  }
}
