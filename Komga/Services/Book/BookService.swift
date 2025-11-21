//
//  BookService.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

class BookService {
  static let shared = BookService()
  private let apiClient = APIClient.shared

  private init() {}

  func getBooks(
    seriesId: String,
    page: Int = 0,
    size: Int = 500,
    browseOpts: BookBrowseOptions
  ) async throws -> Page<Book> {
    let sort = browseOpts.sortString
    let readStatus = browseOpts.readStatusFilter.toReadStatus()

    let condition = BookSearch.buildCondition(
      libraryId: nil,
      readStatus: readStatus,
      seriesId: seriesId,
      readListId: nil
    )
    let search = BookSearch(condition: condition)

    return try await getBooksList(
      search: search,
      page: page,
      size: size,
      sort: sort
    )
  }

  func getBook(id: String) async throws -> Book {
    return try await apiClient.request(path: "/api/v1/books/\(id)")
  }

  func getBookPages(id: String) async throws -> [BookPage] {
    return try await apiClient.request(path: "/api/v1/books/\(id)/pages")
  }

  func getBooksList(
    search: BookSearch,
    page: Int = 0,
    size: Int = 20,
    sort: String? = nil
  ) async throws -> Page<Book> {
    var queryItems = [
      URLQueryItem(name: "page", value: "\(page)"),
      URLQueryItem(name: "size", value: "\(size)"),
    ]

    if let sort = sort {
      queryItems.append(URLQueryItem(name: "sort", value: sort))
    }

    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(search)

    return try await apiClient.request(
      path: "/api/v1/books/list",
      method: "POST",
      body: jsonData,
      queryItems: queryItems
    )
  }

  func getBooksOnDeck(
    libraryId: String = "",
    page: Int = 0,
    size: Int = 20
  ) async throws -> Page<Book> {
    var queryItems = [
      URLQueryItem(name: "page", value: "\(page)"),
      URLQueryItem(name: "size", value: "\(size)"),
    ]

    if !libraryId.isEmpty {
      queryItems.append(URLQueryItem(name: "library_id", value: libraryId))
    }

    return try await apiClient.request(path: "/api/v1/books/ondeck", queryItems: queryItems)
  }

  /// Get thumbnail URL for a book
  func getBookThumbnailURL(id: String) -> URL? {
    let baseURL = AppConfig.serverURL
    guard !baseURL.isEmpty else { return nil }
    return URL(string: baseURL + "/api/v1/books/\(id)/thumbnail")
  }

  func getBookPage(bookId: String, page: Int) async throws -> (data: Data, contentType: String?) {
    return try await apiClient.requestData(path: "/api/v1/books/\(bookId)/pages/\(page)")
  }

  func updateReadProgress(bookId: String, page: Int, completed: Bool = false) async throws {
    let body = ["page": page, "completed": completed] as [String: Any]
    let jsonData = try JSONSerialization.data(withJSONObject: body)

    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/books/\(bookId)/read-progress",
      method: "PATCH",
      body: jsonData
    )
  }

  func deleteReadProgress(bookId: String) async throws {
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/books/\(bookId)/read-progress",
      method: "DELETE"
    )
  }

  func getNextBook(bookId: String) async throws -> Book? {
    do {
      return try await apiClient.request(path: "/api/v1/books/\(bookId)/next")
    } catch {
      return nil
    }
  }

  func getPreviousBook(bookId: String) async throws -> Book? {
    do {
      return try await apiClient.request(path: "/api/v1/books/\(bookId)/previous")
    } catch {
      return nil
    }
  }

  func analyzeBook(bookId: String) async throws {
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/books/\(bookId)/analyze",
      method: "POST"
    )
  }

  func refreshMetadata(bookId: String) async throws {
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/books/\(bookId)/metadata/refresh",
      method: "POST"
    )
  }

  func deleteBook(bookId: String) async throws {
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/books/\(bookId)/file",
      method: "DELETE"
    )
  }

  func markAsRead(bookId: String) async throws {
    // Fetch the book to get the total page count
    let book = try await getBook(id: bookId)
    let lastPage = book.media.pagesCount

    // Use PATCH with completed: true and the last page number
    let body = ["page": lastPage, "completed": true] as [String: Any]
    let jsonData = try JSONSerialization.data(withJSONObject: body)

    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/books/\(bookId)/read-progress",
      method: "PATCH",
      body: jsonData
    )
  }

  func markAsUnread(bookId: String) async throws {
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/books/\(bookId)/read-progress",
      method: "DELETE"
    )
  }

  func getRecentlyReadBooks(
    libraryId: String = "",
    page: Int = 0,
    size: Int = 20
  ) async throws -> Page<Book> {
    // Get books with READ status, sorted by last read date
    let condition = BookSearch.buildCondition(
      libraryId: libraryId.isEmpty ? nil : libraryId,
      readStatus: .read
    )

    let search = BookSearch(condition: condition)

    return try await getBooksList(
      search: search,
      page: page,
      size: size,
      sort: "readProgress.readDate,desc"
    )
  }

  func getRecentlyAddedBooks(
    libraryId: String = "",
    page: Int = 0,
    size: Int = 20
  ) async throws -> Page<Book> {
    // Get books sorted by created date (most recent first)
    // Empty condition means match all books
    let condition = BookSearch.buildCondition(
      libraryId: libraryId.isEmpty ? nil : libraryId
    )

    let search = BookSearch(condition: condition)

    return try await getBooksList(
      search: search,
      page: page,
      size: size,
      sort: "createdDate,desc"
    )
  }
}
