//
// ClientSettingsService.swift
//
//

import Foundation

/// Komga's per-user client settings store (`/api/v1/client-settings/user`,
/// Komga 1.20.0+), shared by every client and device of the signed-in user.
///
/// Keys must match Komga's lowercase dotted-namespace pattern (e.g.
/// `application.domain.key`) or the request is rejected. Writes upsert each key
/// independently and deletes remove only the listed keys, so keys written by
/// different devices never overwrite each other.
nonisolated enum ClientSettingsService {
  private static let apiClient = APIClient.shared

  static func getUserSettings() async throws -> [String: String] {
    let settings: [String: ClientSettingDto] = try await apiClient.request(
      path: "/api/v1/client-settings/user/list"
    )
    return settings.mapValues(\.value)
  }

  static func saveUserSettings(_ settings: [String: String]) async throws {
    guard !settings.isEmpty else { return }
    let body = settings.mapValues { ["value": $0] }
    let jsonData = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/client-settings/user",
      method: "PATCH",
      body: jsonData
    )
  }

  static func deleteUserSettings(keys: [String]) async throws {
    guard !keys.isEmpty else { return }
    let jsonData = try JSONSerialization.data(withJSONObject: keys.sorted(), options: [])
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/client-settings/user",
      method: "DELETE",
      body: jsonData
    )
  }
}
