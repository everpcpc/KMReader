//
// MediaManagementService.swift
//
//

import Foundation

class MediaManagementService {
  static let shared = MediaManagementService()
  private let apiClient = APIClient.shared

  private init() {}

  // MARK: - Media Analysis (books with error/unsupported status)

  func getMediaAnalysisBooks(
    statuses: [MediaStatus],
    libraryIds: [String]? = nil,
    page: Int = 0,
    size: Int = 20,
    sort: String? = nil
  ) async throws -> Page<Book> {
    let statusConditions: [[String: Any]] = statuses.map { status in
      ["mediaStatus": ["operator": "is", "value": status.rawValue]]
    }

    var conditions: [[String: Any]] = [
      ["anyOf": statusConditions]
    ]

    if let libraryIds, !libraryIds.isEmpty {
      let libraryConditions: [[String: Any]] = libraryIds.map { id in
        ["libraryId": ["operator": "is", "value": id]]
      }
      conditions.append(["anyOf": libraryConditions])
    }

    let condition: [String: Any] =
      conditions.count == 1
      ? conditions[0]
      : ["allOf": conditions]

    let search = BookSearch(condition: condition)
    return try await BookService.shared.getBooksList(
      search: search,
      page: page,
      size: size,
      sort: sort ?? "media.status,asc"
    )
  }

  // MARK: - Missing Posters

  func getMissingPosterBooks(
    page: Int = 0,
    size: Int = 20,
    sort: String? = nil
  ) async throws -> Page<Book> {
    let condition: [String: Any] = [
      "allOf": [
        ["mediaStatus": ["operator": "is", "value": MediaStatus.ready.rawValue]],
        ["poster": ["operator": "isnot", "value": ["selected": true]]],
      ]
    ]
    let search = BookSearch(condition: condition)
    return try await BookService.shared.getBooksList(
      search: search,
      page: page,
      size: size,
      sort: sort
    )
  }

  // MARK: - Duplicate Files

  func getDuplicateBooks(
    page: Int = 0,
    size: Int = 20,
    sort: String? = nil
  ) async throws -> Page<Book> {
    var queryItems = [
      URLQueryItem(name: "page", value: "\(page)"),
      URLQueryItem(name: "size", value: "\(size)"),
    ]
    if let sort {
      queryItems.append(URLQueryItem(name: "sort", value: sort))
    }
    return try await apiClient.request(
      path: "/api/v1/books/duplicates",
      queryItems: queryItems
    )
  }

  // MARK: - Duplicate Pages (Known)

  func getKnownPageHashes(
    actions: [PageHashAction]? = nil,
    page: Int = 0,
    size: Int = 10,
    sort: String? = nil
  ) async throws -> Page<PageHashKnown> {
    var queryItems = [
      URLQueryItem(name: "page", value: "\(page)"),
      URLQueryItem(name: "size", value: "\(size)"),
    ]
    if let actions {
      for action in actions {
        queryItems.append(URLQueryItem(name: "action", value: action.rawValue))
      }
    }
    if let sort {
      queryItems.append(URLQueryItem(name: "sort", value: sort))
    }
    return try await apiClient.request(
      path: "/api/v1/page-hashes",
      queryItems: queryItems
    )
  }

  // MARK: - Duplicate Pages (Unknown)

  func getUnknownPageHashes(
    page: Int = 0,
    size: Int = 10,
    sort: String? = nil
  ) async throws -> Page<PageHashUnknown> {
    var queryItems = [
      URLQueryItem(name: "page", value: "\(page)"),
      URLQueryItem(name: "size", value: "\(size)"),
    ]
    if let sort {
      queryItems.append(URLQueryItem(name: "sort", value: sort))
    }
    return try await apiClient.request(
      path: "/api/v1/page-hashes/unknown",
      queryItems: queryItems
    )
  }

  // MARK: - Page Hash Matches

  func getPageHashMatches(
    hash: String,
    page: Int = 0,
    size: Int = 20
  ) async throws -> Page<PageHashMatch> {
    let queryItems = [
      URLQueryItem(name: "page", value: "\(page)"),
      URLQueryItem(name: "size", value: "\(size)"),
    ]
    return try await apiClient.request(
      path: "/api/v1/page-hashes/\(hash)",
      queryItems: queryItems
    )
  }

  // MARK: - Page Hash Actions

  func createOrUpdatePageHash(_ creation: PageHashCreation) async throws {
    let data = try JSONEncoder().encode(creation)
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/page-hashes",
      method: "PUT",
      body: data
    )
  }

  func deleteAllMatchesByHash(_ hash: String) async throws {
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/page-hashes/\(hash)/delete-all",
      method: "POST"
    )
  }

  func deleteMatchByHash(_ hash: String, match: PageHashMatch) async throws {
    let body: [String: Any] = [
      "bookId": match.bookId,
      "pageNumber": match.pageNumber,
    ]
    let data = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/page-hashes/\(hash)/delete-match",
      method: "POST",
      body: data
    )
  }

  // MARK: - Thumbnails

  func getPageHashThumbnailURL(hash: String, known: Bool = true) -> URL? {
    let baseURL = AppConfig.current.serverURL
    guard !baseURL.isEmpty else { return nil }
    let path =
      known
      ? "/api/v1/page-hashes/\(hash)/thumbnail"
      : "/api/v1/page-hashes/unknown/\(hash)/thumbnail"
    return URL(string: baseURL + path)
  }
}
