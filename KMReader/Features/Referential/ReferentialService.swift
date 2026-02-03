//
//  ReferentialService.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation

class ReferentialService {
  static let shared = ReferentialService()
  private let apiClient = APIClient.shared

  private init() {}

  func getPublishers(libraryIds: [String]? = nil, collectionId: String? = nil) async throws
    -> [String]
  {
    var queryItems: [URLQueryItem] = []

    if let libraryIds = libraryIds, !libraryIds.isEmpty {
      for id in libraryIds where !id.isEmpty {
        queryItems.append(URLQueryItem(name: "library_id", value: id))
      }
    }

    if let collectionId = collectionId {
      queryItems.append(URLQueryItem(name: "collection_id", value: collectionId))
    }

    return try await apiClient.request(path: "/api/v1/publishers", queryItems: queryItems)
  }

  func getGenres(libraryIds: [String]? = nil, collectionId: String? = nil) async throws
    -> [String]
  {
    var queryItems: [URLQueryItem] = []

    if let libraryIds = libraryIds, !libraryIds.isEmpty {
      for id in libraryIds where !id.isEmpty {
        queryItems.append(URLQueryItem(name: "library_id", value: id))
      }
    }

    if let collectionId = collectionId {
      queryItems.append(URLQueryItem(name: "collection_id", value: collectionId))
    }

    return try await apiClient.request(path: "/api/v1/genres", queryItems: queryItems)
  }

  func getTags(libraryIds: [String]? = nil, collectionId: String? = nil) async throws -> [String] {
    var queryItems: [URLQueryItem] = []

    if let libraryIds = libraryIds, !libraryIds.isEmpty {
      for id in libraryIds where !id.isEmpty {
        queryItems.append(URLQueryItem(name: "library_id", value: id))
      }
    }

    if let collectionId = collectionId {
      queryItems.append(URLQueryItem(name: "collection_id", value: collectionId))
    }

    return try await apiClient.request(path: "/api/v1/tags", queryItems: queryItems)
  }

  func getBookTags(
    seriesId: String? = nil, readListId: String? = nil, libraryIds: [String]? = nil
  ) async throws -> [String] {
    var queryItems: [URLQueryItem] = []

    if let seriesId = seriesId {
      queryItems.append(URLQueryItem(name: "series_id", value: seriesId))
    }

    if let readListId = readListId {
      queryItems.append(URLQueryItem(name: "readlist_id", value: readListId))
    }

    if let libraryIds = libraryIds, !libraryIds.isEmpty {
      for id in libraryIds where !id.isEmpty {
        queryItems.append(URLQueryItem(name: "library_id", value: id))
      }
    }

    return try await apiClient.request(path: "/api/v1/tags/book", queryItems: queryItems)
  }

  func getLanguages(libraryIds: [String]? = nil, collectionId: String? = nil) async throws
    -> [String]
  {
    var queryItems: [URLQueryItem] = []

    if let libraryIds = libraryIds, !libraryIds.isEmpty {
      for id in libraryIds where !id.isEmpty {
        queryItems.append(URLQueryItem(name: "library_id", value: id))
      }
    }

    if let collectionId = collectionId {
      queryItems.append(URLQueryItem(name: "collection_id", value: collectionId))
    }

    return try await apiClient.request(path: "/api/v1/languages", queryItems: queryItems)
  }

  func getAuthorsNames(search: String? = nil) async throws -> [String] {
    var queryItems: [URLQueryItem] = []

    if let search = search, !search.isEmpty {
      queryItems.append(URLQueryItem(name: "search", value: search))
    }

    return try await apiClient.request(path: "/api/v1/authors/names", queryItems: queryItems)
  }
}
