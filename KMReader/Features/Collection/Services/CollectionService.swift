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
    libraryIds: [String]? = nil,
    page: Int = 0,
    size: Int = 20,
    sort: String? = nil,
    search: String? = nil
  ) async throws -> Page<SeriesCollection> {
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

    return try await apiClient.request(path: "/api/v1/collections", queryItems: queryItems)
  }

  func getCollection(id: String) async throws -> SeriesCollection {
    return try await apiClient.request(path: "/api/v1/collections/\(id)")
  }

  func getCollectionThumbnailURL(id: String) -> URL? {
    let baseURL = AppConfig.current.serverURL
    guard !baseURL.isEmpty else { return nil }
    return URL(string: baseURL + "/api/v1/collections/\(id)/thumbnail")
  }

  func getCollectionSeries(
    collectionId: String,
    page: Int = 0,
    size: Int = 20,
    browseOpts: CollectionSeriesBrowseOptions,
    libraryIds: [String]? = nil
  ) async throws -> Page<Series> {
    var queryItems = [
      URLQueryItem(name: "page", value: "\(page)"),
      URLQueryItem(name: "size", value: "\(size)"),
    ]

    if let libraryIds = libraryIds, !libraryIds.isEmpty {
      for id in libraryIds where !id.isEmpty {
        queryItems.append(URLQueryItem(name: "library_id", value: id))
      }
    }

    for status in browseOpts.includeSeriesStatuses {
      queryItems.append(URLQueryItem(name: "status", value: status.apiValue))
    }

    for status in browseOpts.includeReadStatuses {
      queryItems.append(URLQueryItem(name: "read_status", value: status.rawValue))
    }

    if let deleted = browseOpts.deletedFilter.effectiveBool {
      queryItems.append(URLQueryItem(name: "deleted", value: String(deleted)))
    }

    if let complete = browseOpts.completeFilter.effectiveBool {
      queryItems.append(URLQueryItem(name: "complete", value: String(complete)))
    }

    // Metadata filters
    if let publishers = browseOpts.metadataFilter.publishers, !publishers.isEmpty {
      for publisher in publishers {
        queryItems.append(URLQueryItem(name: "publisher", value: publisher))
      }
    }

    if let authors = browseOpts.metadataFilter.authors, !authors.isEmpty {
      for author in authors {
        queryItems.append(URLQueryItem(name: "author", value: "\(author),"))
      }
    }

    if let genres = browseOpts.metadataFilter.genres, !genres.isEmpty {
      for genre in genres {
        queryItems.append(URLQueryItem(name: "genre", value: genre))
      }
    }

    if let tags = browseOpts.metadataFilter.tags, !tags.isEmpty {
      for tag in tags {
        queryItems.append(URLQueryItem(name: "tag", value: tag))
      }
    }

    if let languages = browseOpts.metadataFilter.languages, !languages.isEmpty {
      for language in languages {
        queryItems.append(URLQueryItem(name: "language", value: language))
      }
    }

    return try await apiClient.request(
      path: "/api/v1/collections/\(collectionId)/series",
      queryItems: queryItems
    )
  }

  func createCollection(
    name: String,
    ordered: Bool = false,
    seriesIds: [String] = []
  ) async throws -> SeriesCollection {
    // SeriesIds cannot be empty when creating a collection
    guard !seriesIds.isEmpty else {
      throw AppErrorType.validationFailed(message: "Cannot create collection without series")
    }

    let body = ["name": name, "ordered": ordered, "seriesIds": seriesIds] as [String: Any]
    let jsonData = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    return try await apiClient.request(
      path: "/api/v1/collections",
      method: "POST",
      body: jsonData
    )
  }

  func deleteCollection(collectionId: String) async throws {
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/collections/\(collectionId)",
      method: "DELETE"
    )
    // Delete from local SwiftData
    let instanceId = AppConfig.current.instanceId
    await DatabaseOperator.shared.deleteCollection(id: collectionId, instanceId: instanceId)
    await DatabaseOperator.shared.commit()
  }

  func removeSeriesFromCollection(collectionId: String, seriesIds: [String]) async throws {
    // Return early if no series to remove
    guard !seriesIds.isEmpty else { return }

    // Get current collection
    let collection = try await getCollection(id: collectionId)
    // Remove the series from the list
    let updatedSeriesIds = collection.seriesIds.filter { !seriesIds.contains($0) }

    // Throw error if result would be empty
    guard !updatedSeriesIds.isEmpty else {
      throw AppErrorType.operationNotAllowed(message: "Cannot remove all series from collection")
    }

    // Update collection with new series list
    try await updateCollectionSeriesIds(collectionId: collectionId, seriesIds: updatedSeriesIds)
  }

  func addSeriesToCollection(collectionId: String, seriesIds: [String]) async throws {
    // Return early if no series to add
    guard !seriesIds.isEmpty else { return }

    // Get current collection
    let collection = try await getCollection(id: collectionId)
    // Add the series to the list (avoid duplicates)
    var updatedSeriesIds = collection.seriesIds
    for seriesId in seriesIds {
      if !updatedSeriesIds.contains(seriesId) {
        updatedSeriesIds.append(seriesId)
      }
    }

    // Update collection with new series list
    try await updateCollectionSeriesIds(collectionId: collectionId, seriesIds: updatedSeriesIds)
  }

  private func updateCollectionSeriesIds(collectionId: String, seriesIds: [String]) async throws {
    let body = ["seriesIds": seriesIds] as [String: Any]
    let jsonData = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/collections/\(collectionId)",
      method: "PATCH",
      body: jsonData
    )
  }

  func updateCollection(collectionId: String, name: String? = nil, ordered: Bool? = nil)
    async throws
  {
    var body: [String: Any] = [:]
    if let name = name {
      body["name"] = name
    }
    if let ordered = ordered {
      body["ordered"] = ordered
    }
    let jsonData = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/collections/\(collectionId)",
      method: "PATCH",
      body: jsonData
    )
  }
}
