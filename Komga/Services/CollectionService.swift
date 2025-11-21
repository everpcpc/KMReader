//
//  CollectionService.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

class CollectionService {
  static let shared = CollectionService()
  private let apiClient = APIClient.shared

  private init() {}

  func getCollections(
    libraryId: String = "",
    page: Int = 0,
    size: Int = 20,
    sort: String? = nil,
    search: String? = nil
  ) async throws -> Page<Collection> {
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

    return try await apiClient.request(path: "/api/v1/collections", queryItems: queryItems)
  }

  func getCollection(id: String) async throws -> Collection {
    return try await apiClient.request(path: "/api/v1/collections/\(id)")
  }

  func getCollectionThumbnailURL(id: String) -> URL? {
    let baseURL = UserDefaults.standard.string(forKey: "serverURL") ?? ""
    guard !baseURL.isEmpty else { return nil }
    return URL(string: baseURL + "/api/v1/collections/\(id)/thumbnail")
  }

  func getCollectionSeries(
    collectionId: String,
    page: Int = 0,
    size: Int = 20,
    sort: String = "metadata.titleSort,asc"
  ) async throws -> Page<Series> {
    let queryItems = [
      URLQueryItem(name: "page", value: "\(page)"),
      URLQueryItem(name: "size", value: "\(size)"),
      URLQueryItem(name: "sort", value: sort),
    ]

    let search = SeriesSearch(condition: SeriesSearch.buildCondition(collectionId: collectionId))
    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(search)

    return try await apiClient.request(
      path: "/api/v1/series/list",
      method: "POST",
      body: jsonData,
      queryItems: queryItems
    )
  }
}
