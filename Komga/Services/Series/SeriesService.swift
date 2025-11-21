//
//  SeriesService.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

class SeriesService {
  static let shared = SeriesService()
  private let apiClient = APIClient.shared

  private init() {}

  func getSeries(
    libraryId: String = "",
    page: Int = 0,
    size: Int = 20,
    sort: String = "metadata.titleSort,asc",
    readStatus: ReadStatusFilter? = nil,
    seriesStatus: SeriesStatusFilter? = nil,
    searchTerm: String? = nil
  ) async throws -> Page<Series> {
    // Check if we have any filters - if so, use getSeriesList
    let hasLibraryFilter = !libraryId.isEmpty
    let hasReadStatusFilter = readStatus != nil && readStatus != .all
    let hasSeriesStatusFilter = seriesStatus != nil && seriesStatus != .all

    if hasLibraryFilter || hasReadStatusFilter || hasSeriesStatusFilter {
      let condition = SeriesSearch.buildCondition(
        libraryId: hasLibraryFilter ? libraryId : nil,
        readStatus: hasReadStatusFilter ? readStatus!.toReadStatus() : nil,
        seriesStatus: hasSeriesStatusFilter ? seriesStatus!.rawValue : nil
      )

      let search = SeriesSearch(
        condition: condition,
        fullTextSearch: searchTerm?.isEmpty == false ? searchTerm : nil
      )

      return try await getSeriesList(
        search: search,
        page: page,
        size: size,
        sort: sort
      )
    } else {
      // No filters - use the simple GET endpoint
      var queryItems = [
        URLQueryItem(name: "page", value: "\(page)"),
        URLQueryItem(name: "size", value: "\(size)"),
        URLQueryItem(name: "sort", value: sort),
      ]

      if let searchTerm, !searchTerm.isEmpty {
        queryItems.append(URLQueryItem(name: "search", value: searchTerm))
      }
      return try await apiClient.request(path: "/api/v1/series", queryItems: queryItems)
    }
  }

  func getSeriesList(
    search: SeriesSearch,
    page: Int = 0,
    size: Int = 20,
    sort: String? = nil
  ) async throws -> Page<Series> {
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
      path: "/api/v1/series/list",
      method: "POST",
      body: jsonData,
      queryItems: queryItems
    )
  }

  func getOneSeries(id: String) async throws -> Series {
    return try await apiClient.request(path: "/api/v1/series/\(id)")
  }

  func getNewSeries(
    libraryId: String = "",
    page: Int = 0,
    size: Int = 20
  ) async throws -> Page<Series> {
    var queryItems = [
      URLQueryItem(name: "page", value: "\(page)"),
      URLQueryItem(name: "size", value: "\(size)"),
    ]

    if !libraryId.isEmpty {
      queryItems.append(URLQueryItem(name: "library_id", value: libraryId))
    }

    return try await apiClient.request(path: "/api/v1/series/new", queryItems: queryItems)
  }

  func getUpdatedSeries(
    libraryId: String = "",
    page: Int = 0,
    size: Int = 20
  ) async throws -> Page<Series> {
    var queryItems = [
      URLQueryItem(name: "page", value: "\(page)"),
      URLQueryItem(name: "size", value: "\(size)"),
    ]

    if !libraryId.isEmpty {
      queryItems.append(URLQueryItem(name: "library_id", value: libraryId))
    }

    return try await apiClient.request(path: "/api/v1/series/updated", queryItems: queryItems)
  }

  /// Get thumbnail URL for a series
  func getSeriesThumbnailURL(id: String) -> URL? {
    let baseURL = AppConfig.serverURL
    guard !baseURL.isEmpty else { return nil }
    return URL(string: baseURL + "/api/v1/series/\(id)/thumbnail")
  }

  func markAsRead(seriesId: String) async throws {
    // Use PATCH to mark series as read
    // For series, we don't need page number, just mark as completed
    let body = ["completed": true] as [String: Any]
    let jsonData = try JSONSerialization.data(withJSONObject: body)

    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/series/\(seriesId)/read-progress",
      method: "PATCH",
      body: jsonData
    )
  }

  func markAsUnread(seriesId: String) async throws {
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/series/\(seriesId)/read-progress",
      method: "DELETE"
    )
  }

  func analyzeSeries(seriesId: String) async throws {
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/series/\(seriesId)/analyze",
      method: "POST"
    )
  }

  func refreshMetadata(seriesId: String) async throws {
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/series/\(seriesId)/metadata/refresh",
      method: "POST"
    )
  }

  func deleteSeries(seriesId: String) async throws {
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/series/\(seriesId)/file",
      method: "DELETE"
    )
  }
}
