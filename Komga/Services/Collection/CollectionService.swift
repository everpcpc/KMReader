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
    let baseURL = AppConfig.serverURL
    guard !baseURL.isEmpty else { return nil }
    return URL(string: baseURL + "/api/v1/collections/\(id)/thumbnail")
  }

  func getCollectionSeries(
    collectionId: String,
    page: Int = 0,
    size: Int = 20,
    browseOpts: SeriesBrowseOptions
  ) async throws -> Page<Series> {
    let sort = browseOpts.sortString
    let readStatus = browseOpts.readStatusFilter.toReadStatus()

    let condition = SeriesSearch.buildCondition(
      readStatus: readStatus,
      collectionId: collectionId
    )
    let search = SeriesSearch(condition: condition)

    return try await SeriesService.shared.getSeriesList(
      search: search,
      page: page,
      size: size,
      sort: sort
    )
  }

  func deleteCollection(collectionId: String) async throws {
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/collections/\(collectionId)",
      method: "DELETE"
    )
  }

  func removeSeriesFromCollection(collectionId: String, seriesId: String) async throws {
    // Get current collection
    let collection = try await getCollection(id: collectionId)
    // Remove the series from the list
    let updatedSeriesIds = collection.seriesIds.filter { $0 != seriesId }
    // Update collection with new series list
    let body = ["seriesIds": updatedSeriesIds] as [String: Any]
    let jsonData = try JSONSerialization.data(withJSONObject: body)
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/collections/\(collectionId)",
      method: "PATCH",
      body: jsonData
    )
  }
}
