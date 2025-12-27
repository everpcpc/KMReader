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
    libraryIds: [String]? = nil,
    page: Int = 0,
    size: Int = 20,
    sort: String? = nil,
    search: String? = nil
  ) async throws -> Page<ReadList> {
    var queryItems = [
      URLQueryItem(name: "page", value: "\(page)"),
      URLQueryItem(name: "size", value: "\(size)"),
    ]

    // Support multiple libraryIds
    if let libraryIds = libraryIds, !libraryIds.isEmpty {
      for id in libraryIds where !id.isEmpty {
        queryItems.append(URLQueryItem(name: "library_id", value: id))
      }
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
    browseOpts: ReadListBookBrowseOptions,
    libraryIds: [String]? = nil
  ) async throws -> Page<Book> {
    var queryItems = [
      URLQueryItem(name: "page", value: "\(page)"),
      URLQueryItem(name: "size", value: "\(size)"),
    ]

    if let libraryIds = libraryIds, !libraryIds.isEmpty {
      for id in libraryIds where !id.isEmpty {
        queryItems.append(URLQueryItem(name: "library_id", value: id))
      }
    }

    for status in browseOpts.includeReadStatuses {
      queryItems.append(URLQueryItem(name: "read_status", value: status.rawValue))
    }

    if let deleted = browseOpts.deletedFilter.effectiveBool {
      queryItems.append(URLQueryItem(name: "deleted", value: String(deleted)))
    }

    return try await apiClient.request(
      path: "/api/v1/readlists/\(readListId)/books",
      queryItems: queryItems
    )
  }

  func createReadList(
    name: String,
    summary: String = "",
    ordered: Bool = false,
    bookIds: [String] = []
  ) async throws -> ReadList {
    // BookIds cannot be empty when creating a readlist
    guard !bookIds.isEmpty else {
      throw AppErrorType.validationFailed(message: "Cannot create read list without books")
    }

    let body =
      ["name": name, "summary": summary, "ordered": ordered, "bookIds": bookIds] as [String: Any]
    let jsonData = try JSONSerialization.data(withJSONObject: body)
    return try await apiClient.request(
      path: "/api/v1/readlists",
      method: "POST",
      body: jsonData
    )
  }

  func deleteReadList(readListId: String) async throws {
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/readlists/\(readListId)",
      method: "DELETE"
    )
  }

  func removeBooksFromReadList(readListId: String, bookIds: [String]) async throws {
    // Return early if no books to remove
    guard !bookIds.isEmpty else { return }

    // Get current readlist
    let readList = try await getReadList(id: readListId)
    // Remove the books from the list
    let updatedBookIds = readList.bookIds.filter { !bookIds.contains($0) }

    // Throw error if result would be empty
    guard !updatedBookIds.isEmpty else {
      throw AppErrorType.operationNotAllowed(message: "Cannot remove all books from read list")
    }

    // Update readlist with new book list
    try await updateReadListBookIds(readListId: readListId, bookIds: updatedBookIds)
  }

  func addBooksToReadList(readListId: String, bookIds: [String]) async throws {
    // Return early if no books to add
    guard !bookIds.isEmpty else { return }

    // Get current readlist
    let readList = try await getReadList(id: readListId)
    // Add the books to the list (avoid duplicates)
    var updatedBookIds = readList.bookIds
    for bookId in bookIds {
      if !updatedBookIds.contains(bookId) {
        updatedBookIds.append(bookId)
      }
    }

    // Update readlist with new book list
    try await updateReadListBookIds(readListId: readListId, bookIds: updatedBookIds)
  }

  private func updateReadListBookIds(readListId: String, bookIds: [String]) async throws {
    let body = ["bookIds": bookIds] as [String: Any]
    let jsonData = try JSONSerialization.data(withJSONObject: body)
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/readlists/\(readListId)",
      method: "PATCH",
      body: jsonData
    )
  }

  func updateReadList(
    readListId: String, name: String? = nil, summary: String? = nil, ordered: Bool? = nil
  ) async throws {
    var body: [String: Any] = [:]
    if let name = name {
      body["name"] = name
    }
    if let summary = summary {
      body["summary"] = summary
    }
    if let ordered = ordered {
      body["ordered"] = ordered
    }
    let jsonData = try JSONSerialization.data(withJSONObject: body)
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/readlists/\(readListId)",
      method: "PATCH",
      body: jsonData
    )
  }
}
