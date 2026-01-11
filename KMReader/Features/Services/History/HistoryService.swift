//
//  HistoryService.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation

class HistoryService {
  static let shared = HistoryService()
  private let apiClient = APIClient.shared

  private init() {}

  func getHistory(page: Int, size: Int, sort: String = "timestamp,desc") async throws
    -> HistoricalEventPage
  {
    guard AppConfig.current.isAdmin else {
      throw AppErrorType.operationNotAllowed(message: "Admin access required")
    }

    let queryItems = [
      URLQueryItem(name: "page", value: "\(page)"),
      URLQueryItem(name: "size", value: "\(size)"),
      URLQueryItem(name: "sort", value: sort),
    ]

    return try await apiClient.request(path: "/api/v1/history", queryItems: queryItems)
  }
}
