//
//  LibraryService.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

class LibraryService {
  static let shared = LibraryService()
  private let apiClient = APIClient.shared

  private init() {}

  func getLibraries() async throws -> [Library] {
    return try await apiClient.request(path: "/api/v1/libraries")
  }

  func getLibrary(id: String) async throws -> Library {
    return try await apiClient.request(path: "/api/v1/libraries/\(id)")
  }

  func createLibrary(_ creation: LibraryCreation) async throws -> Library {
    let bodyData = try JSONEncoder().encode(creation)
    return try await apiClient.request(
      path: "/api/v1/libraries",
      method: "POST",
      body: bodyData
    )
  }

  func updateLibrary(id: String, update: LibraryUpdate) async throws {
    let bodyData = try JSONEncoder().encode(update)
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/libraries/\(id)",
      method: "PATCH",
      body: bodyData
    )
  }
  func scanLibrary(id: String, deep: Bool = false) async throws {
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

  func analyzeLibrary(id: String) async throws {
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/libraries/\(id)/analyze",
      method: "POST"
    )
  }

  func refreshMetadata(id: String) async throws {
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/libraries/\(id)/metadata/refresh",
      method: "POST"
    )
  }

  func emptyTrash(id: String) async throws {
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/libraries/\(id)/empty-trash",
      method: "POST"
    )
  }

  func deleteLibrary(id: String) async throws {
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/libraries/\(id)",
      method: "DELETE"
    )
    // Delete from local SwiftData (also removes related books and series)
    let instanceId = AppConfig.currentInstanceId
    await DatabaseOperator.shared.deleteLibrary(libraryId: id, instanceId: instanceId)
    await DatabaseOperator.shared.commit()
  }
}
