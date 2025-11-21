//
//  ReadListService.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

class ReadListService {
  static let shared = ReadListService()
  private let apiClient = APIClient.shared

  private init() {}

  func getReadLists(
    libraryId: String = "",
    page: Int = 0,
    size: Int = 20,
    sort: String? = nil,
    search: String? = nil
  ) async throws -> Page<ReadList> {
    var queryItems = [
      URLQueryItem(name: "page", value: "\(page)"),
      URLQueryItem(name: "size", value: "\(size)"),
    ]

    if !libraryId.isEmpty {
      queryItems.append(URLQueryItem(name: "library_id", value: libraryId))
    }

    if let sort {
      queryItems.append(URLQueryItem(name: "sort", value: sort))
    }

    if let search, !search.isEmpty {
      queryItems.append(URLQueryItem(name: "search", value: search))
    }

    return try await apiClient.request(path: "/api/v1/readlists", queryItems: queryItems)
  }

  func getReadList(id: String) async throws -> ReadList {
    return try await apiClient.request(path: "/api/v1/readlists/\(id)")
  }

  func getReadListThumbnailURL(id: String) -> URL? {
    let baseURL = AppConfig.serverURL
    guard !baseURL.isEmpty else { return nil }
    return URL(string: baseURL + "/api/v1/readlists/\(id)/thumbnail")
  }

  func getReadListBooks(
    readListId: String,
    page: Int = 0,
    size: Int = 20,
    browseOpts: BookBrowseOptions
  ) async throws -> Page<Book> {
    let sort = browseOpts.sortString
    let readStatus = browseOpts.readStatusFilter.toReadStatus()

    let condition = BookSearch.buildCondition(
      libraryId: nil,
      readStatus: readStatus,
      seriesId: nil,
      readListId: readListId
    )
    let search = BookSearch(condition: condition)

    return try await BookService.shared.getBooksList(
      search: search,
      page: page,
      size: size,
      sort: sort
    )
  }

  func deleteReadList(readListId: String) async throws {
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/readlists/\(readListId)",
      method: "DELETE"
    )
  }

  func removeBookFromReadList(readListId: String, bookId: String) async throws {
    // Get current readlist
    let readList = try await getReadList(id: readListId)
    // Remove the book from the list
    let updatedBookIds = readList.bookIds.filter { $0 != bookId }
    // Update readlist with new book list
    let body = ["bookIds": updatedBookIds] as [String: Any]
    let jsonData = try JSONSerialization.data(withJSONObject: body)
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/readlists/\(readListId)",
      method: "PATCH",
      body: jsonData
    )
  }
}
