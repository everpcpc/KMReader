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
  var books: [Book] = []
  var currentBook: Book?
  var isLoading = false

  private let bookService = BookService.shared
  private let sseService = SSEService.shared
  private var currentPage = 0
  private var hasMorePages = true
  private var currentSeriesId: String?
  private var currentSeriesBrowseOpts: BookBrowseOptions?
  private var currentBrowseState: BookBrowseOptions?
  private var currentBrowseSort: String?
  private var currentBrowseSearch: String = ""

  init() {
    setupSSEListeners()
  }

  private func setupSSEListeners() {
    // Book events
    sseService.onBookChanged = { [weak self] event in
      Task { @MainActor in
        // Refresh current book if it matches
        if self?.currentBook?.id == event.bookId {
          await self?.loadBook(id: event.bookId)
        }
        // Refresh books list if it contains this book
        if let index = self?.books.firstIndex(where: { $0.id == event.bookId }) {
          if let updatedBook = try? await self?.bookService.getBook(id: event.bookId) {
            self?.books[index] = updatedBook
          }
        }
      }
    }

    sseService.onBookDeleted = { [weak self] event in
      Task { @MainActor in
        // Remove book from list
        self?.books.removeAll { $0.id == event.bookId }
        // Clear current book if it matches
        if self?.currentBook?.id == event.bookId {
          self?.currentBook = nil
        }
      }
    }

    // Read progress events
    sseService.onReadProgressChanged = { [weak self] event in
      Task { @MainActor in
        // Refresh current book if it matches
        if self?.currentBook?.id == event.bookId {
          await self?.loadBook(id: event.bookId)
        }
        // Update book in list if it exists
        if let index = self?.books.firstIndex(where: { $0.id == event.bookId }) {
          if let updatedBook = try? await self?.bookService.getBook(id: event.bookId) {
            self?.books[index] = updatedBook
          }
        }
      }
    }
  }

  func loadBooks(
    seriesId: String, browseOpts: BookBrowseOptions, libraryIds: [String]? = nil,
    refresh: Bool = true
  ) async {
    // Check if we're loading the same series with same options
    let isSameSeries = currentSeriesId == seriesId && currentSeriesBrowseOpts == browseOpts

    // Only clear books if it's a different series or forced refresh
    let shouldClear = refresh || !isSameSeries

    currentSeriesId = seriesId
    currentSeriesBrowseOpts = browseOpts
    currentPage = 0
    hasMorePages = true

    // Preserve existing books if refreshing the same series to avoid UI flicker
    if shouldClear {
      books = []
    }
    isLoading = true

    // 1. Local Cache
    let localBooks = KomgaBookStore.shared.fetchBooks(
      seriesId: seriesId,
      page: currentPage,
      size: 50
    )
    if !localBooks.isEmpty {
      if shouldClear {
        books = localBooks
      } else {
        // Append only if we are paging? Local paging strategy:
        // If page=0, we replace.
        // But here we are fetching page 0 from DB.
        books.append(contentsOf: localBooks)
      }
    }

    // 2. Sync
    do {
      let page = try await SyncService.shared.syncBooks(
        seriesId: seriesId,
        page: currentPage,  // Note: We start at 0
        size: 50,
        browseOpts: browseOpts,
        libraryIds: libraryIds
      )

      withAnimation {
        if shouldClear {
          books = page.content
        } else {
          // Merge logic: replace existing from local if overlap, else append
          if !localBooks.isEmpty {
            let startIndex = books.count - localBooks.count
            if startIndex >= 0 {
              books.replaceSubrange(startIndex..<books.count, with: page.content)
            } else {
              books.append(contentsOf: page.content)
            }
          } else {
            books.append(contentsOf: page.content)
          }
        }
      }
      hasMorePages = !page.last
      currentPage = 1  // Next page
    } catch {
      if books.isEmpty {
        ErrorManager.shared.alert(error: error)
      }
    }

    isLoading = false
  }

  func loadMoreBooks(seriesId: String, libraryIds: [String]? = nil) async {
    guard hasMorePages && !isLoading && seriesId == currentSeriesId,
      let browseOpts = currentSeriesBrowseOpts
    else { return }

    isLoading = true

    // Local Load for next page?
    // Doing strict pagination with DB + Network is complex if they mismatch.
    // For "Load More", we usually trust the network or assume DB has it all.
    // Let's rely on network primarily for pagination consistency for now,
    // or try fetching from DB first.

    let localBooks = KomgaBookStore.shared.fetchBooks(
      seriesId: seriesId,
      page: currentPage,
      size: 50
    )
    if !localBooks.isEmpty {
      withAnimation {
        books.append(contentsOf: localBooks)
      }
    }

    do {
      let page = try await SyncService.shared.syncBooks(
        seriesId: seriesId, page: currentPage, size: 50, browseOpts: browseOpts,
        libraryIds: libraryIds)

      withAnimation {
        // If we added local books, replace them with fresh ones
        if !localBooks.isEmpty {
          let startIndex = books.count - localBooks.count
          books.replaceSubrange(startIndex..<books.count, with: page.content)
        } else {
          books.append(contentsOf: page.content)
        }
      }
      hasMorePages = !page.last
      currentPage += 1
    } catch {
      // If we failed but loaded local, silent.
      if localBooks.isEmpty {
        ErrorManager.shared.alert(error: error)
      }
    }

    isLoading = false
  }

  // Refresh current books list smoothly without clearing existing data
  func refreshCurrentBooks() async {
    guard let seriesId = currentSeriesId,
      let browseOpts = currentSeriesBrowseOpts
    else { return }
    // Force network refresh logic?
    // loadBooks handles logic.
    await loadBooks(seriesId: seriesId, browseOpts: browseOpts, refresh: false)
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
      if currentBook == nil {
        ErrorManager.shared.alert(error: error)
      }
    }

    isLoading = false
  }

  func loadBooksOnDeck(libraryIds: [String]? = nil) async {
    isLoading = true

    do {
      let page = try await SyncService.shared.syncBooksOnDeck(
        libraryIds: libraryIds, page: currentPage, size: 20)
      withAnimation {
        books = page.content
      }
    } catch {
      ErrorManager.shared.alert(error: error)
    }

    isLoading = false
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
      if let index = books.firstIndex(where: { $0.id == bookId }) {
        books[index] = updatedBook
      }
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
      if let index = books.firstIndex(where: { $0.id == bookId }) {
        books[index] = updatedBook
      }
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

  func loadRecentlyReadBooks(libraryIds: [String]? = nil, refresh: Bool = false) async {
    if refresh {
      currentPage = 0
      hasMorePages = true
    } else {
      guard hasMorePages else { return }
    }

    guard !isLoading else { return }

    isLoading = true

    do {
      let page = try await SyncService.shared.syncRecentlyReadBooks(
        libraryIds: libraryIds,
        page: currentPage,
        size: 20
      )

      withAnimation {
        if refresh {
          books = page.content
        } else {
          books.append(contentsOf: page.content)
        }
      }

      hasMorePages = !page.last
      currentPage += 1
    } catch {
      ErrorManager.shared.alert(error: error)
    }

    isLoading = false
  }

  func loadBrowseBooks(
    browseOpts: BookBrowseOptions, searchText: String = "", libraryIds: [String]? = nil,
    refresh: Bool = false
  )
    async
  {
    let sort = browseOpts.sortString
    let paramsChanged =
      currentBrowseState != browseOpts
      || currentBrowseSort != sort
      || currentBrowseSearch != searchText

    let shouldReset = refresh || paramsChanged

    if shouldReset {
      currentPage = 0
      hasMorePages = true
      currentBrowseState = browseOpts
      currentBrowseSort = sort
      currentBrowseSearch = searchText
    }

    guard hasMorePages && !isLoading else { return }

    isLoading = true

    // 1. Local Cache
    let localBooks = KomgaBookStore.shared.fetchBooksList(
      search: currentBrowseSearch,
      libraryIds: libraryIds,
      browseOpts: browseOpts,
      page: currentPage,
      size: 20,
      sort: sort
    )
    if !localBooks.isEmpty {
      if shouldReset {
        books = localBooks
      } else {
        books.append(contentsOf: localBooks)
      }
    }

    // 2. Sync
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
        fullTextSearch: currentBrowseSearch.isEmpty == false ? currentBrowseSearch : nil
      )

      let page = try await SyncService.shared.syncBooksList(
        search: bookSearch,
        page: currentPage,
        size: 20,
        sort: sort
      )

      withAnimation {
        if shouldReset {
          books = page.content
        } else {
          // Merge
          if !localBooks.isEmpty {
            let startIndex = books.count - localBooks.count
            if startIndex >= 0 {
              books.replaceSubrange(startIndex..<books.count, with: page.content)
            } else {
              books.append(contentsOf: page.content)
            }
          } else {
            books.append(contentsOf: page.content)
          }
        }
      }

      hasMorePages = !page.last
      currentPage += 1
    } catch {
      if books.isEmpty {
        ErrorManager.shared.alert(error: error)
      }
    }

    isLoading = false
  }

  func loadReadListBooks(
    readListId: String,
    browseOpts: ReadListBookBrowseOptions,
    libraryIds: [String]? = nil,
    refresh: Bool = false
  ) async {
    guard hasMorePages && !isLoading else { return }

    isLoading = true

    // 1. Local Cache
    let localBooks = KomgaBookStore.shared.fetchReadListBooks(
      readListId: readListId,
      page: currentPage,
      size: 50
    )
    if !localBooks.isEmpty {
      if refresh {
        books = localBooks
      } else {
        books.append(contentsOf: localBooks)
      }
    }

    // 2. Sync
    do {
      let page = try await SyncService.shared.syncReadListBooks(
        readListId: readListId,
        page: currentPage,
        size: 50,
        browseOpts: browseOpts,
        libraryIds: libraryIds
      )

      withAnimation {
        if refresh {
          books = page.content
        } else {
          // Merge
          if !localBooks.isEmpty {
            let startIndex = books.count - localBooks.count
            if startIndex >= 0 {
              books.replaceSubrange(startIndex..<books.count, with: page.content)
            } else {
              books.append(contentsOf: page.content)
            }
          } else {
            books.append(contentsOf: page.content)
          }
        }
      }

      hasMorePages = !page.last
      currentPage += 1
    } catch {
      if books.isEmpty {
        ErrorManager.shared.alert(error: error)
      }
    }

    isLoading = false
  }
}
