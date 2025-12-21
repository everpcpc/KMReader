//
//  ManagementService.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

class ManagementService {
  static let shared = ManagementService()
  private let apiClient = APIClient.shared

  private init() {}

  func getActuatorInfo() async throws -> ServerInfo {
    guard AppConfig.isAdmin else {
      throw AppErrorType.operationNotAllowed(message: "Admin access required")
    }
    return try await apiClient.request(path: "/actuator/info")
  }

  func getMetric(_ metricName: String, tags: [MetricTag]? = nil) async throws -> Metric {
    guard AppConfig.isAdmin else {
      throw AppErrorType.operationNotAllowed(message: "Admin access required")
    }
    let path = "/actuator/metrics/\(metricName)"
    var queryItems: [URLQueryItem]?

    if let tags = tags, !tags.isEmpty {
      queryItems = tags.map { URLQueryItem(name: "tag", value: "\($0.key):\($0.value)") }
    }

    return try await apiClient.request(path: path, queryItems: queryItems)
  }

  func cancelAllTasks() async throws {
    guard AppConfig.isAdmin else {
      throw AppErrorType.operationNotAllowed(message: "Admin access required")
    }
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/tasks",
      method: "DELETE"
    )
  }
}
