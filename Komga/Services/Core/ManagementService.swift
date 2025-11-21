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
    return try await apiClient.request(path: "/actuator/info")
  }
}
