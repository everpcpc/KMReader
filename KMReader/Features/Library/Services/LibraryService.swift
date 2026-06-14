//
// LibraryService.swift
//
//

import Foundation

nonisolated enum LibraryService {
  private static let apiClient = APIClient.shared

  static func getLibraries() async throws -> [Library] {
    return try await apiClient.request(path: "/api/v1/libraries")
  }

  static func getLibrary(id: String) async throws -> Library {
    return try await apiClient.request(path: "/api/v1/libraries/\(id)")
  }

  static func createLibrary(_ creation: LibraryCreation) async throws -> Library {
    let bodyData = try JSONEncoder().encode(creation)
    return try await apiClient.request(
      path: "/api/v1/libraries",
      method: "POST",
      body: bodyData
    )
  }

  static func updateLibrary(id: String, update: LibraryUpdate) async throws {
    let bodyData = try JSONEncoder().encode(update)
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/libraries/\(id)",
      method: "PATCH",
      body: bodyData
    )
  }
  static func scanLibrary(id: String, deep: Bool = false) async throws {
    var queryItems: [URLQueryItem]? = nil
    if deep {
      queryItems = [URLQueryItem(name: "deep", value: "true")]
    }

    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/libraries/\(id)/scan",
      method: "POST",
      queryItems: queryItems
    )
  }

  static func analyzeLibrary(id: String) async throws {
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/libraries/\(id)/analyze",
      method: "POST"
    )
  }

  static func refreshMetadata(id: String) async throws {
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/libraries/\(id)/metadata/refresh",
      method: "POST"
    )
  }

  static func emptyTrash(id: String) async throws {
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/libraries/\(id)/empty-trash",
      method: "POST"
    )
  }

  static func deleteLibrary(id: String) async throws {
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/libraries/\(id)",
      method: "DELETE"
    )
    // Delete from local database (also removes related books and series)
    let instanceId = AppConfig.current.instanceId
    try await DatabaseOperator.database().deleteLibrary(libraryId: id, instanceId: instanceId)
  }
}
