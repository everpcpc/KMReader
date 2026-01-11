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
    libraryIds: [String]? = nil,
    page: Int = 0,
    size: Int = 20,
    sort: String = "metadata.titleSort,asc",
    includeReadStatuses: Set<ReadStatus>,
    excludeReadStatuses: Set<ReadStatus>,
    includeSeriesStatuses: Set<SeriesStatus>,
    excludeSeriesStatuses: Set<SeriesStatus>,
    seriesStatusLogic: StatusFilterLogic,
    completeFilter: TriStateFilter<BoolTriStateFlag>,
    oneshotFilter: TriStateFilter<BoolTriStateFlag>,
    deletedFilter: TriStateFilter<BoolTriStateFlag>,
    searchTerm: String? = nil
  ) async throws -> Page<Series> {
    // Check if we have any filters - if so, use getSeriesList
    let hasLibraryFilter = libraryIds != nil && !libraryIds!.isEmpty
    let hasReadStatusFilter =
      !includeReadStatuses.isEmpty || !excludeReadStatuses.isEmpty
    let hasSeriesStatusFilter =
      !includeSeriesStatuses.isEmpty || !excludeSeriesStatuses.isEmpty || oneshotFilter.isActive
      || deletedFilter.isActive || completeFilter.isActive

    if hasLibraryFilter || hasReadStatusFilter || hasSeriesStatusFilter {
      let condition = SeriesSearch.buildCondition(
        filters: SeriesSearchFilters(
          libraryIds: libraryIds,
          includeReadStatuses: Array(includeReadStatuses),
          excludeReadStatuses: Array(excludeReadStatuses),
          includeSeriesStatuses: includeSeriesStatuses.map { $0.apiValue }.filter { !$0.isEmpty },
          excludeSeriesStatuses: excludeSeriesStatuses.map { $0.apiValue }.filter { !$0.isEmpty },
          seriesStatusLogic: seriesStatusLogic,
          oneshot: oneshotFilter.effectiveBool,
          deleted: deletedFilter.effectiveBool,
          complete: completeFilter.effectiveBool,
        ))

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

      // Support multiple libraryIds
      if let libraryIds = libraryIds, !libraryIds.isEmpty {
        for id in libraryIds where !id.isEmpty {
          queryItems.append(URLQueryItem(name: "library_id", value: id))
        }
      }

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

  func getSeriesCollections(seriesId: String) async throws -> [SeriesCollection] {
    return try await apiClient.request(path: "/api/v1/series/\(seriesId)/collections")
  }

  func getNewSeries(
    libraryIds: [String]? = nil,
    page: Int = 0,
    size: Int = 20
  ) async throws -> Page<Series> {
    var queryItems = [
      URLQueryItem(name: "page", value: "\(page)"),
      URLQueryItem(name: "size", value: "\(size)"),
      URLQueryItem(name: "oneshot", value: "false"),
    ]

    // Support multiple libraryIds
    if let libraryIds = libraryIds, !libraryIds.isEmpty {
      for id in libraryIds where !id.isEmpty {
        queryItems.append(URLQueryItem(name: "library_id", value: id))
      }
    }

    return try await apiClient.request(path: "/api/v1/series/new", queryItems: queryItems)
  }

  func getUpdatedSeries(
    libraryIds: [String]? = nil,
    page: Int = 0,
    size: Int = 20
  ) async throws -> Page<Series> {
    var queryItems = [
      URLQueryItem(name: "page", value: "\(page)"),
      URLQueryItem(name: "size", value: "\(size)"),
      URLQueryItem(name: "oneshot", value: "false"),
    ]

    // Support multiple libraryIds
    if let libraryIds = libraryIds, !libraryIds.isEmpty {
      for id in libraryIds where !id.isEmpty {
        queryItems.append(URLQueryItem(name: "library_id", value: id))
      }
    }

    return try await apiClient.request(path: "/api/v1/series/updated", queryItems: queryItems)
  }

  /// Get thumbnail URL for a series
  func getSeriesThumbnailURL(id: String) -> URL? {
    let baseURL = AppConfig.current.serverURL
    guard !baseURL.isEmpty else { return nil }
    return URL(string: baseURL + "/api/v1/series/\(id)/thumbnail")
  }

  func markAsRead(seriesId: String) async throws {
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/series/\(seriesId)/read-progress",
      method: "POST"
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

  func updateSeriesMetadata(seriesId: String, metadata: [String: Any]) async throws {
    let jsonData = try JSONSerialization.data(withJSONObject: metadata, options: [.sortedKeys])
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/series/\(seriesId)/metadata",
      method: "PATCH",
      body: jsonData
    )
  }
}
