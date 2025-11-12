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
    sort: String = "metadata.numberSort,asc"
  ) async throws -> Page<Book> {
    let queryItems = [
      URLQueryItem(name: "page", value: "\(page)"),
      URLQueryItem(name: "size", value: "\(size)"),
      URLQueryItem(name: "sort", value: sort),
    ]

    let search = BookSearch(condition: .seriesId(seriesId))
    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(search)

    return try await apiClient.request(
      path: "/api/v1/books/list",
      method: "POST",
      body: jsonData,
      queryItems: queryItems
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
    libraryId: String? = nil,
    page: Int = 0,
    size: Int = 20
  ) async throws -> Page<Book> {
    var queryItems = [
      URLQueryItem(name: "page", value: "\(page)"),
      URLQueryItem(name: "size", value: "\(size)"),
    ]

    if let libraryId = libraryId {
      queryItems.append(URLQueryItem(name: "library_id", value: libraryId))
    }

    return try await apiClient.request(path: "/api/v1/books/ondeck", queryItems: queryItems)
  }

  func getBookThumbnail(id: String) async throws -> Data {
    return try await apiClient.requestData(path: "/api/v1/books/\(id)/thumbnail")
  }

  func getBookPage(bookId: String, page: Int) async throws -> Data {
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

  func markAsRead(bookId: String) async throws {
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/books/\(bookId)/read-progress",
      method: "POST"
    )
  }

  func markAsUnread(bookId: String) async throws {
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/books/\(bookId)/read-progress",
      method: "DELETE"
    )
  }

  func getRecentlyReadBooks(
    libraryId: String? = nil,
    page: Int = 0,
    size: Int = 20
  ) async throws -> Page<Book> {
    // Get books with READ status, sorted by last read date
    let condition: BookSearch.Condition
    if let libraryId = libraryId {
      condition = .libraryIdAndReadStatus(libraryId: libraryId, readStatus: .read)
    } else {
      condition = .readStatus(.read)
    }

    let search = BookSearch(condition: condition)

    return try await getBooksList(
      search: search,
      page: page,
      size: size,
      sort: "readProgress.readDate,desc"
    )
  }
}
