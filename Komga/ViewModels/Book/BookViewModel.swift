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
  var errorMessage: String?

  private let bookService = BookService.shared
  private var currentPage = 0
  private var hasMorePages = true
  private var currentSeriesId: String?
  private var currentSeriesBrowseOpts: BookBrowseOptions?
  private var currentBrowseState: BookBrowseOptions?
  private var currentBrowseSort: String?
  private var currentBrowseSearch: String = ""

  func loadBooks(seriesId: String, browseOpts: BookBrowseOptions) async {
    currentSeriesId = seriesId
    currentSeriesBrowseOpts = browseOpts
    currentPage = 0
    books = []
    hasMorePages = true
    isLoading = true
    errorMessage = nil

    do {
      let page = try await bookService.getBooks(
        seriesId: seriesId, page: 0, size: 50, browseOpts: browseOpts)
      withAnimation {
        books = page.content
      }
      hasMorePages = !page.last
      currentPage = 1
    } catch {
      errorMessage = error.localizedDescription
    }

    isLoading = false
  }

  func loadMoreBooks(seriesId: String) async {
    guard hasMorePages && !isLoading && seriesId == currentSeriesId,
      let browseOpts = currentSeriesBrowseOpts
    else { return }

    isLoading = true
    errorMessage = nil

    do {
      let page = try await bookService.getBooks(
        seriesId: seriesId, page: currentPage, size: 50, browseOpts: browseOpts)
      withAnimation {
        books.append(contentsOf: page.content)
      }
      hasMorePages = !page.last
      currentPage += 1
    } catch {
      errorMessage = error.localizedDescription
    }

    isLoading = false
  }

  func loadBook(id: String) async {
    isLoading = true
    errorMessage = nil

    do {
      currentBook = try await bookService.getBook(id: id)
    } catch {
      errorMessage = error.localizedDescription
    }

    isLoading = false
  }

  func loadBooksOnDeck(libraryId: String = "") async {
    isLoading = true
    errorMessage = nil

    do {
      let page = try await bookService.getBooksOnDeck(libraryId: libraryId, size: 20)
      withAnimation {
        books = page.content
      }
    } catch {
      errorMessage = error.localizedDescription
    }

    isLoading = false
  }

  func updateReadProgress(bookId: String, page: Int, completed: Bool = false) async {
    do {
      try await bookService.updateReadProgress(bookId: bookId, page: page, completed: completed)
      if currentBook?.id == bookId {
        await loadBook(id: bookId)
      }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func markAsRead(bookId: String) async {
    do {
      try await bookService.markAsRead(bookId: bookId)
      let updatedBook = try await bookService.getBook(id: bookId)
      if let index = books.firstIndex(where: { $0.id == bookId }) {
        books[index] = updatedBook
      }
      if currentBook?.id == bookId {
        currentBook = updatedBook
      }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func markAsUnread(bookId: String) async {
    do {
      try await bookService.markAsUnread(bookId: bookId)
      let updatedBook = try await bookService.getBook(id: bookId)
      if let index = books.firstIndex(where: { $0.id == bookId }) {
        books[index] = updatedBook
      }
      if currentBook?.id == bookId {
        currentBook = updatedBook
      }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func loadRecentlyReadBooks(libraryId: String = "", refresh: Bool = false) async {
    if refresh {
      currentPage = 0
      hasMorePages = true
    } else {
      guard hasMorePages else { return }
    }

    guard !isLoading else { return }

    isLoading = true
    errorMessage = nil

    do {
      let page = try await bookService.getRecentlyReadBooks(
        libraryId: libraryId,
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
      errorMessage = error.localizedDescription
    }

    isLoading = false
  }

  func loadBrowseBooks(
    browseOpts: BookBrowseOptions, searchText: String = "", refresh: Bool = false
  )
    async
  {
    let sort = browseOpts.sortString
    let paramsChanged =
      currentBrowseState?.libraryId != browseOpts.libraryId
      || currentBrowseState?.readStatusFilter != browseOpts.readStatusFilter
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
    errorMessage = nil

    do {
      let condition = BookSearch.buildCondition(
        libraryId: browseOpts.libraryId.isEmpty ? nil : browseOpts.libraryId,
        readStatus: browseOpts.readStatusFilter.toReadStatus()
      )

      let search = BookSearch(
        condition: condition,
        fullTextSearch: searchText.isEmpty ? nil : searchText
      )
      let page = try await bookService.getBooksList(
        search: search,
        page: currentPage,
        size: 20,
        sort: sort
      )

      withAnimation {
        if shouldReset {
          books = page.content
        } else {
          books.append(contentsOf: page.content)
        }
      }

      hasMorePages = !page.last
      currentPage += 1
    } catch {
      errorMessage = error.localizedDescription
    }

    isLoading = false
  }

  func loadReadListBooks(
    readListId: String,
    browseOpts: BookBrowseOptions,
    refresh: Bool = false
  ) async {
    if refresh {
      currentPage = 0
      hasMorePages = true
    } else {
      guard hasMorePages && !isLoading else { return }
    }

    isLoading = true
    errorMessage = nil

    do {
      let page = try await ReadListService.shared.getReadListBooks(
        readListId: readListId,
        page: currentPage,
        size: 50,
        browseOpts: browseOpts
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
      errorMessage = error.localizedDescription
    }

    isLoading = false
  }
}
